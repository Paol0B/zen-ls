const std = @import("std");
const Config = @import("../args.zig").Config;
const FileEntry = @import("../core/file_entry.zig").FileEntry;
const icons = @import("../ui/icons.zig");
const themes = @import("../ui/themes.zig");

pub const TreeRenderer = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    stdout: @TypeOf((std.fs.File{ .handle = std.posix.STDOUT_FILENO }).deprecatedWriter()),
    color_enabled: bool,
    
    pub fn init(allocator: std.mem.Allocator, config: *const Config) TreeRenderer {
        const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        const stdout = stdout_file.deprecatedWriter();
        
        const color_enabled = switch (config.color_mode) {
            .always => true,
            .never => false,
            .auto => std.posix.isatty(std.posix.STDOUT_FILENO),
        };
        
        return TreeRenderer{
            .allocator = allocator,
            .config = config,
            .stdout = stdout,
            .color_enabled = color_enabled,
        };
    }
    
    pub fn render(self: *TreeRenderer, entries: []const FileEntry, root_path: []const u8) !void {
        // Build tree structure
        var tree = std.StringHashMap(std.ArrayList(FileEntry)).init(self.allocator);
        defer {
            var iter = tree.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            tree.deinit();
        }
        
        // Group entries by directory
        for (entries) |entry| {
            const dir_path = std.fs.path.dirname(entry.path) orelse root_path;
            const gop = try tree.getOrPut(dir_path);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayList(FileEntry){};
            }
            try gop.value_ptr.append(self.allocator, entry);
        }
        
        // Render tree starting from root
        try self.renderDirectory(root_path, &tree, "");
    }
    
    fn renderDirectory(
        self: *TreeRenderer,
        path: []const u8,
        tree: *std.StringHashMap(std.ArrayList(FileEntry)),
        prefix: []const u8
    ) !void {
        const entries_opt = tree.get(path);
        if (entries_opt == null) return;
        
        const entries = entries_opt.?.items;
        
        for (entries, 0..) |entry, i| {
            const is_last_entry = i == entries.len - 1;
            
            // Print tree structure
            try self.stdout.writeAll(prefix);
            
            if (is_last_entry) {
                try self.stdout.writeAll("└── ");
            } else {
                try self.stdout.writeAll("├── ");
            }
            
            // Print icon
            if (self.config.show_icons) {
                const icon = switch (self.config.icon_set) {
                    .nerd_fonts => icons.getFileIcon(entry.name, entry.is_directory, entry.is_executable),
                    .unicode => icons.getUnicodeIcon(entry.name, entry.is_directory, entry.is_executable),
                    .ascii => icons.getAsciiIcon(entry.is_directory, entry.is_executable),
                    .none => icons.Icon{ .symbol = "", .color = "" },
                };
                
                if (self.color_enabled and icon.color.len > 0) {
                    try self.stdout.writeAll(icon.color);
                }
                try self.stdout.writeAll(icon.symbol);
                if (icon.symbol.len > 0) {
                    try self.stdout.writeAll(" ");
                }
            }
            
            // Print filename with color
            if (self.color_enabled) {
                const color = themes.getFileTypeColor(
                    self.config.theme,
                    entry.name,
                    entry.is_directory,
                    entry.is_executable,
                    entry.is_symlink
                );
                try self.stdout.writeAll(color);
            }
            
            try self.stdout.writeAll(entry.name);
            
            if (self.color_enabled) {
                try self.stdout.writeAll("\x1b[0m");
            }
            
            try self.stdout.writeAll("\n");
            
            // Recursively render subdirectories
            if (entry.is_directory) {
                var new_prefix = std.ArrayList(u8){};
                defer new_prefix.deinit(self.allocator);
                
                try new_prefix.appendSlice(self.allocator, prefix);
                if (is_last_entry) {
                    try new_prefix.appendSlice(self.allocator, "    ");
                } else {
                    try new_prefix.appendSlice(self.allocator, "│   ");
                }
                
                try self.renderDirectory(entry.path, tree, new_prefix.items);
            }
        }
    }
};
