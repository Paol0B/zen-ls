const std = @import("std");
const Config = @import("../args.zig").Config;
const core = @import("../core/core.zig");
const Screen = @import("screen.zig").Screen;
const InputHandler = @import("input.zig").InputHandler;
const InputEvent = @import("input.zig").InputEvent;
const Key = @import("input.zig").Key;
const FilePreview = @import("preview.zig").FilePreview;
const icons = @import("icons.zig");
const themes = @import("themes.zig");

pub const InteractiveUI = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    fs_engine: *const core.FilesystemEngine,
    screen: ?Screen = null,
    input: ?InputHandler = null,
    preview: ?FilePreview = null,
    selected_index: usize = 0,
    scroll_offset: usize = 0,
    show_preview: bool = true,
    
    pub fn init(
        allocator: std.mem.Allocator,
        config: *const Config,
        fs_engine: *const core.FilesystemEngine
    ) !InteractiveUI {
        return InteractiveUI{
            .allocator = allocator,
            .config = config,
            .fs_engine = fs_engine,
            .show_preview = config.show_preview,
        };
    }
    
    pub fn deinit(self: *InteractiveUI) void {
        if (self.input) |*input| {
            input.deinit();
        }
        if (self.screen) |*screen| {
            screen.showCursor() catch {};
        }
    }
    
    pub fn run(self: *InteractiveUI) !void {
        // Initialize TUI components
        self.screen = try Screen.init();
        self.input = try InputHandler.init();
        self.preview = FilePreview.init(self.allocator, self.config);
        
        var screen = &self.screen.?;
        var input = &self.input.?;
        
        try screen.hideCursor();
        defer screen.showCursor() catch {};
        
        try screen.clear();
        
        var running = true;
        while (running) {
            try self.render();
            
            const event = try input.readEvent();
            running = try self.handleInput(event);
        }
        
        try screen.clear();
        try screen.moveCursor(1, 1);
    }
    
    fn render(self: *InteractiveUI) !void {
        const entries = self.fs_engine.getEntries();
        if (entries.len == 0) return;
        
        var screen = &self.screen.?;
        
        try screen.updateSize();
        const width = screen.width;
        const height = screen.height;
        
        // Calculate layout
        const list_width = if (self.show_preview) width * 2 / 3 else width;
        const preview_width = if (self.show_preview) width - list_width else 0;
        
        // Draw file list
        try self.renderFileList(entries, 1, 1, list_width, height - 1);
        
        // Draw preview pane
        if (self.show_preview and preview_width > 0) {
            try self.renderPreview(entries, list_width + 1, 1, preview_width, height - 1);
        }
        
        // Draw status bar
        try self.renderStatusBar(entries, height);
        
        try screen.flush();
    }
    
    fn renderFileList(self: *InteractiveUI, entries: []const core.FileEntry, row: usize, col: usize, width: usize, height: usize) !void {
        var screen = &self.screen.?;
        try screen.drawBox(row, col, width, height, "ZEN-LS");
        
        const list_height = height - 2;
        const max_visible = list_height;
        
        // Adjust scroll offset
        if (self.selected_index < self.scroll_offset) {
            self.scroll_offset = self.selected_index;
        }
        if (self.selected_index >= self.scroll_offset + max_visible) {
            self.scroll_offset = self.selected_index - max_visible + 1;
        }
        
        // Render visible entries
        var line: usize = 0;
        var idx = self.scroll_offset;
        while (idx < entries.len and line < max_visible) : ({idx += 1; line += 1;}) {
            const entry = &entries[idx];
            const is_selected = idx == self.selected_index;
            
            try screen.moveCursor(row + 1 + line, col + 2);
            
            // Highlight selected
            if (is_selected) {
                try screen.setColor("\x1b[7m"); // Reverse video
            }
            
            // Icon
            if (self.config.show_icons) {
                const icon = switch (self.config.icon_set) {
                    .nerd_fonts => icons.getFileIcon(entry.name, entry.is_directory, entry.is_executable),
                    .unicode => icons.getUnicodeIcon(entry.name, entry.is_directory, entry.is_executable),
                    .ascii => icons.getAsciiIcon(entry.is_directory, entry.is_executable),
                    .none => icons.Icon{ .symbol = "", .color = "" },
                };
                try screen.stdout.writeAll(icon.symbol);
                if (icon.symbol.len > 0) {
                    try screen.stdout.writeAll(" ");
                }
            }
            
            // Color
            if (!is_selected) {
                const color = themes.getFileTypeColor(
                    self.config.theme,
                    entry.name,
                    entry.is_directory,
                    entry.is_executable,
                    entry.is_symlink
                );
                try screen.setColor(color);
            }
            
            // Name (truncate if needed)
            const max_name_len = width - 6;
            if (entry.name.len > max_name_len) {
                try screen.stdout.writeAll(entry.name[0..max_name_len - 3]);
                try screen.stdout.writeAll("...");
            } else {
                try screen.stdout.writeAll(entry.name);
                // Pad to clear line
                var i: usize = entry.name.len;
                while (i < max_name_len) : (i += 1) {
                    try screen.stdout.writeAll(" ");
                }
            }
            
            try screen.resetColor();
        }
        
        // Show scroll indicator
        if (entries.len > max_visible) {
            const indicator_row = row + 1 + (self.selected_index * list_height / entries.len);
            try screen.moveCursor(indicator_row, col + width - 2);
            try screen.setColor("\x1b[1;33m");
            try screen.stdout.writeAll("◆");
            try screen.resetColor();
        }
    }
    
    fn renderPreview(self: *InteractiveUI, entries: []const core.FileEntry, row: usize, col: usize, width: usize, height: usize) !void {
        if (self.selected_index >= entries.len) return;
        
        var screen = &self.screen.?;
        var preview = &self.preview.?;
        
        try screen.drawBox(row, col, width, height, "Preview");
        
        const entry = &entries[self.selected_index];
        var preview_lines = try preview.getPreview(entry, height - 4);
        defer {
            for (preview_lines.items) |line| {
                self.allocator.free(line);
            }
            preview_lines.deinit(self.allocator);
        }
        
        var line: usize = 0;
        for (preview_lines.items) |text| {
            if (line >= height - 2) break;
            
            try screen.moveCursor(row + 1 + line, col + 2);
            
            // Truncate if needed
            const max_len = width - 4;
            if (text.len > max_len) {
                try screen.stdout.writeAll(text[0..max_len]);
            } else {
                try screen.stdout.writeAll(text);
            }
            
            line += 1;
        }
    }
    
    fn renderStatusBar(self: *InteractiveUI, entries: []const core.FileEntry, row: usize) !void {
        var screen = &self.screen.?;
        try screen.moveCursor(row, 1);
        try screen.setColor("\x1b[7m"); // Reverse video
        
        var buf: [256]u8 = undefined;
        const status = try std.fmt.bufPrint(
            &buf,
            " {d}/{d} files | ↑↓:Navigate Enter:Open Tab:Preview Q:Quit ",
            .{ self.selected_index + 1, entries.len }
        );
        
        try screen.stdout.writeAll(status);
        
        // Pad to screen width
        var i: usize = status.len;
        while (i < screen.width) : (i += 1) {
            try screen.stdout.writeAll(" ");
        }
        
        try screen.resetColor();
    }
    
    fn handleInput(self: *InteractiveUI, event: InputEvent) !bool {
        const entries = self.fs_engine.getEntries();
        if (entries.len == 0) return false;
        
        switch (event.key) {
            .up => {
                if (self.selected_index > 0) {
                    self.selected_index -= 1;
                }
            },
            .down => {
                if (self.selected_index < entries.len - 1) {
                    self.selected_index += 1;
                }
            },
            .page_up => {
                if (self.selected_index >= 10) {
                    self.selected_index -= 10;
                } else {
                    self.selected_index = 0;
                }
            },
            .page_down => {
                if (self.selected_index + 10 < entries.len) {
                    self.selected_index += 10;
                } else {
                    self.selected_index = entries.len - 1;
                }
            },
            .home => {
                self.selected_index = 0;
            },
            .end => {
                self.selected_index = entries.len - 1;
            },
            .tab => {
                self.show_preview = !self.show_preview;
            },
            .char => {
                if (event.char == 'q' or event.char == 'Q') {
                    return false;
                }
                // Vim-style navigation
                if (event.char == 'j') {
                    if (self.selected_index < entries.len - 1) {
                        self.selected_index += 1;
                    }
                } else if (event.char == 'k') {
                    if (self.selected_index > 0) {
                        self.selected_index -= 1;
                    }
                } else if (event.char == 'h') {
                    // Navigate to parent directory (TODO)
                } else if (event.char == 'l') {
                    // Navigate into directory (TODO)
                }
            },
            .ctrl_c, .ctrl_q, .escape => {
                return false;
            },
            else => {},
        }
        
        return true;
    }
};
