const std = @import("std");
const Config = @import("../args.zig").Config;
const core = @import("../core/core.zig");
const colors = @import("colors.zig");
const formatter = @import("formatter.zig");

pub const RenderEngine = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    stdout: @TypeOf((std.fs.File{ .handle = std.posix.STDOUT_FILENO }).deprecatedWriter()),
    color_enabled: bool,
    
    pub fn init(allocator: std.mem.Allocator, config: *const Config) !RenderEngine {
        const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        const stdout = stdout_file.deprecatedWriter();
        
        // Determine if colors should be used
        const color_enabled = switch (config.color_mode) {
            .always => true,
            .never => false,
            .auto => std.posix.isatty(std.posix.STDOUT_FILENO),
        };
        
        return RenderEngine{
            .allocator = allocator,
            .config = config,
            .stdout = stdout,
            .color_enabled = color_enabled,
        };
    }
    
    pub fn deinit(self: *RenderEngine) void {
        _ = self;
    }
    
    pub fn render(self: *RenderEngine, fs_engine: *const core.FilesystemEngine) !void {
        const entries = fs_engine.getEntries();
        
        if (entries.len == 0) {
            return;
        }
        
        // Choose rendering mode based on configuration
        if (self.config.tree_view) {
            try self.renderTree(entries);
        } else if (self.config.long_format) {
            try self.renderLong(entries);
        } else if (self.config.one_per_line) {
            try self.renderOneLine(entries);
        } else {
            try self.renderGrid(entries);
        }
    }
    
    fn renderLong(self: *RenderEngine, entries: []const core.FileEntry) !void {
        var total_blocks: u64 = 0;
        for (entries) |entry| {
            total_blocks += (entry.size + 511) / 512;
        }
        
        try self.stdout.print("total {d}\n", .{total_blocks});
        
        for (entries) |entry| {
            // Permissions
            var perm_buffer: [10]u8 = undefined;
            const perms = entry.getPermissionsString(&perm_buffer);
            try self.stdout.writeAll(perms);
            try self.stdout.writeAll(" ");
            
            // Number of hard links (placeholder for now)
            try self.stdout.print("{d:>3} ", .{1});
            
            // Owner and group
            if (self.config.numeric_ids) {
                try self.stdout.print("{d:<8} {d:<8} ", .{ entry.uid, entry.gid });
            } else {
                // For now, just use numeric IDs
                // TODO: Implement user/group name lookup
                try self.stdout.print("{d:<8} {d:<8} ", .{ entry.uid, entry.gid });
            }
            
            // Size
            if (self.config.human_readable) {
                try self.printHumanSize(entry.size);
            } else {
                try self.stdout.print("{d:>8} ", .{entry.size});
            }
            
            // Modification time
            try self.printTime(entry.mtime);
            try self.stdout.writeAll(" ");
            
            // Inode (if requested)
            if (self.config.show_inode) {
                try self.stdout.print("{d:>8} ", .{entry.inode});
            }
            
            // Name with color
            try self.printFileName(&entry);
            
            // Symlink target
            if (entry.is_symlink and entry.link_target != null) {
                try self.stdout.writeAll(" -> ");
                try self.stdout.writeAll(entry.link_target.?);
            }
            
            try self.stdout.writeAll("\n");
        }
    }
    
    fn renderOneLine(self: *RenderEngine, entries: []const core.FileEntry) !void {
        for (entries) |entry| {
            if (self.config.show_inode) {
                try self.stdout.print("{d:>8} ", .{entry.inode});
            }
            
            try self.printFileName(&entry);
            try self.stdout.writeAll("\n");
        }
    }
    
    fn renderGrid(self: *RenderEngine, entries: []const core.FileEntry) !void {
        // Get terminal width
        const term_width = getTerminalWidth();
        
        // Calculate column width
        var max_name_len: usize = 0;
        for (entries) |entry| {
            const name_len = entry.name.len + if (self.config.classify) @as(usize, 1) else 0;
            if (name_len > max_name_len) max_name_len = name_len;
        }
        
        // Add icon width if enabled
        if (self.config.show_icons) {
            max_name_len += 3; // Icon + space
        }
        
        const col_width = max_name_len + 2; // Add spacing
        const num_cols = @max(1, term_width / col_width);
        
        var col: usize = 0;
        for (entries) |entry| {
            if (self.config.show_icons) {
                try self.stdout.writeAll(entry.getIcon());
                try self.stdout.writeAll(" ");
            }
            
            try self.printFileName(&entry);
            
            col += 1;
            if (col >= num_cols) {
                try self.stdout.writeAll("\n");
                col = 0;
            } else {
                // Padding to next column
                const name_len = entry.name.len + if (self.config.classify) @as(usize, 1) else 0;
                const pad = col_width - name_len - if (self.config.show_icons) @as(usize, 3) else 0;
                try self.stdout.writeByteNTimes(' ', pad);
            }
        }
        
        if (col > 0) {
            try self.stdout.writeAll("\n");
        }
    }
    
    fn renderTree(self: *RenderEngine, entries: []const core.FileEntry) !void {
        // Simple tree rendering for now
        for (entries) |entry| {
            if (self.config.show_icons) {
                try self.stdout.writeAll(entry.getIcon());
                try self.stdout.writeAll(" ");
            }
            
            try self.printFileName(&entry);
            try self.stdout.writeAll("\n");
        }
    }
    
    fn printFileName(self: *RenderEngine, entry: *const core.FileEntry) !void {
        if (self.color_enabled) {
            const color_code = colors.getColorForEntry(entry, self.config);
            try self.stdout.writeAll(color_code);
        }
        
        try self.stdout.writeAll(entry.name);
        
        if (self.config.classify) {
            const classifier = entry.getClassifier();
            if (classifier != 0) {
                try self.stdout.writeByte(classifier);
            }
        }
        
        if (self.color_enabled) {
            try self.stdout.writeAll(colors.RESET);
        }
    }
    
    fn printHumanSize(self: *RenderEngine, size: u64) !void {
        const units = [_][]const u8{ "B", "K", "M", "G", "T", "P" };
        var size_float: f64 = @floatFromInt(size);
        var unit_idx: usize = 0;
        
        while (size_float >= 1024.0 and unit_idx < units.len - 1) {
            size_float /= 1024.0;
            unit_idx += 1;
        }
        
        if (unit_idx == 0) {
            try self.stdout.print("{d:>4}{s} ", .{ size, units[unit_idx] });
        } else {
            try self.stdout.print("{d:>3.1}{s} ", .{ size_float, units[unit_idx] });
        }
    }
    
    fn printTime(self: *RenderEngine, timestamp: i128) !void {
        const epoch_seconds: i64 = @intCast(@divFloor(timestamp, std.time.ns_per_s));
        const epoch_day = std.time.epoch.EpochDay{ .day = @intCast(@divFloor(epoch_seconds, std.time.s_per_day)) };
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();
        
        const seconds_today: u32 = @intCast(@mod(epoch_seconds, std.time.s_per_day));
        const hours = seconds_today / 3600;
        const minutes = (seconds_today % 3600) / 60;
        
        const month_names = [_][]const u8{
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        };
        
        try self.stdout.print("{s} {d:>2} {d:>2}:{d:>2}", .{
            month_names[month_day.month.numeric() - 1],
            month_day.day_index + 1,
            hours,
            minutes,
        });
    }
};

fn getTerminalWidth() usize {
    // Try to get terminal size, default to 80
    if (std.posix.isatty(std.posix.STDOUT_FILENO)) {
        var ws: std.posix.winsize = undefined;
        const result = std.posix.system.ioctl(std.posix.STDOUT_FILENO, std.posix.system.T.IOCGWINSZ, @intFromPtr(&ws));
        if (result == 0 and ws.col > 0) {
            return ws.col;
        }
    }
    return 80;
}
