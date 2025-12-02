const std = @import("std");
const Config = @import("../args.zig").Config;
const core = @import("../core/core.zig");
const colors = @import("colors.zig");
const formatter = @import("formatter.zig");
const icons = @import("../ui/icons.zig");
const themes = @import("../ui/themes.zig");
const TreeRenderer = @import("tree.zig").TreeRenderer;

pub const RenderEngine = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    stdout: @TypeOf((std.fs.File{ .handle = std.posix.STDOUT_FILENO }).deprecatedWriter()),
    color_enabled: bool,
    user_cache: core.UserCache,

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
            .user_cache = core.UserCache.init(allocator),
        };
    }

    pub fn deinit(self: *RenderEngine) void {
        self.user_cache.deinit();
    }

    pub fn render(self: *RenderEngine, fs_engine: *const core.FilesystemEngine) !void {
        const entries = fs_engine.getEntries();

        if (entries.len == 0) {
            return;
        }

        // Choose rendering mode based on configuration
        if (self.config.tree_view) {
            var tree_renderer = TreeRenderer.init(self.allocator, self.config);
            const root_path = if (self.config.paths.items.len > 0) self.config.paths.items[0] else ".";
            try tree_renderer.render(entries, root_path);
        } else if (self.config.long_format) {
            try self.renderLong(entries);
        } else if (self.config.one_per_line) {
            try self.renderOneLine(entries);
        } else {
            try self.renderGrid(entries);
        }
    }

    fn renderLong(self: *RenderEngine, entries: []const core.FileEntry) !void {
        // Calcola le larghezze massime per allineamento
        var max_user_len: usize = 0;
        var max_group_len: usize = 0;
        var max_size_len: usize = 0;
        var total_blocks: u64 = 0;

        for (entries) |entry| {
            total_blocks += (entry.size + 511) / 512;
            const user_name = self.user_cache.getUserName(entry.uid);
            const group_name = self.user_cache.getGroupName(entry.gid);
            if (user_name.len > max_user_len) max_user_len = user_name.len;
            if (group_name.len > max_group_len) max_group_len = group_name.len;
            // Calcola lunghezza size
            var size_buf: [16]u8 = undefined;
            const size_str = if (self.config.human_readable) blk: {
                const units = [_][]const u8{ "B", "K", "M", "G", "T", "P" };
                var size_float: f64 = @floatFromInt(entry.size);
                var unit_idx: usize = 0;
                while (size_float >= 1024.0 and unit_idx < units.len - 1) {
                    size_float /= 1024.0;
                    unit_idx += 1;
                }
                if (unit_idx == 0) {
                    break :blk std.fmt.bufPrint(&size_buf, "{d}{s}", .{ entry.size, units[unit_idx] }) catch "?";
                } else {
                    break :blk std.fmt.bufPrint(&size_buf, "{d:.1}{s}", .{ size_float, units[unit_idx] }) catch "?";
                }
            } else blk: {
                break :blk std.fmt.bufPrint(&size_buf, "{d}", .{entry.size}) catch "?";
            };
            if (size_str.len > max_size_len) max_size_len = size_str.len;
        }

        // Header colorato
        if (self.color_enabled) {
            try self.stdout.writeAll("\x1b[1;90m");
        }
        try self.stdout.print("total {d}\n", .{total_blocks});
        if (self.color_enabled) {
            try self.stdout.writeAll("\x1b[0m");
        }

        for (entries) |entry| {
            // Permessi con colori
            var perm_buffer: [10]u8 = undefined;
            const perms = entry.getPermissionsString(&perm_buffer);
            try self.printColoredPerms(perms);
            try self.stdout.writeAll(" ");

            // Owner e group con colori
            const user_name = self.user_cache.getUserName(entry.uid);
            const group_name = self.user_cache.getGroupName(entry.gid);
            if (self.color_enabled) try self.stdout.writeAll("\x1b[33m");
            try self.stdout.print("{s:<[1]} ", .{ user_name, max_user_len });
            if (self.color_enabled) try self.stdout.writeAll("\x1b[35m");
            try self.stdout.print("{s:<[1]} ", .{ group_name, max_group_len });
            if (self.color_enabled) try self.stdout.writeAll("\x1b[0m");

            // Size con colori
            try self.printColoredSize(entry.size, max_size_len);
            try self.stdout.writeAll(" ");

            // Modification time (già colorato)
            try self.printTime(entry.mtime);
            try self.stdout.writeAll(" ");

            // Nome con colore e icona
            try self.printFileName(&entry);

            // Symlink target
            if (entry.is_symlink and entry.link_target != null) {
                if (self.color_enabled) try self.stdout.writeAll("\x1b[90m");
                try self.stdout.writeAll(" → ");
                if (self.color_enabled) try self.stdout.writeAll("\x1b[36m");
                try self.stdout.writeAll(entry.link_target.?);
                if (self.color_enabled) try self.stdout.writeAll("\x1b[0m");
            }

            try self.stdout.writeAll("\n");
        }
    }

    fn printColoredPerms(self: *RenderEngine, perms: []const u8) !void {
        for (perms, 0..) |c, i| {
            if (self.color_enabled) {
                if (i == 0) {
                    // Tipo file - più evidente
                    const color: []const u8 = switch (c) {
                        'd' => "\x1b[1;38;5;33m", // Directory - blue bold
                        'l' => "\x1b[1;38;5;51m", // Link - cyan bold
                        else => "\x1b[38;5;250m", // File - gray
                    };
                    try self.stdout.writeAll(color);
                } else if (i <= 3) {
                    // Owner permissions - more visible
                    if (c == 'r') {
                        try self.stdout.writeAll("\x1b[38;5;82m"); // Read - bright green
                    } else if (c == 'w') {
                        try self.stdout.writeAll("\x1b[38;5;209m"); // Write - orange
                    } else if (c == 'x') {
                        try self.stdout.writeAll("\x1b[1;38;5;226m"); // Execute - yellow bold
                    } else {
                        try self.stdout.writeAll("\x1b[38;5;240m"); // - dark gray
                    }
                } else if (i <= 6) {
                    // Group permissions - medium gray
                    if (c == '-') {
                        try self.stdout.writeAll("\x1b[38;5;240m");
                    } else {
                        try self.stdout.writeAll("\x1b[38;5;244m");
                    }
                } else {
                    // Other permissions - dark gray
                    if (c == '-') {
                        try self.stdout.writeAll("\x1b[38;5;238m");
                    } else {
                        try self.stdout.writeAll("\x1b[38;5;242m");
                    }
                }
            }
            try self.stdout.writeByte(c);
        }
        if (self.color_enabled) try self.stdout.writeAll("\x1b[0m");
    }

    fn printColoredSize(self: *RenderEngine, size: u64, width: usize) !void {
        const units = [_][]const u8{ "B", "K", "M", "G", "T", "P" };
        var size_float: f64 = @floatFromInt(size);
        var unit_idx: usize = 0;

        while (size_float >= 1024.0 and unit_idx < units.len - 1) {
            size_float /= 1024.0;
            unit_idx += 1;
        }

        var buf: [16]u8 = undefined;
        const str = if (unit_idx == 0)
            std.fmt.bufPrint(&buf, "{d:>3}{s}", .{ size, units[unit_idx] }) catch "?"
        else
            std.fmt.bufPrint(&buf, "{d:>5.1}{s}", .{ size_float, units[unit_idx] }) catch "?";

        // Right-align with padding
        const padding = if (width > str.len) width - str.len else 0;
        try self.stdout.writeByteNTimes(' ', padding);

        // Color based on size - more visible
        if (self.color_enabled) {
            const color: []const u8 = switch (unit_idx) {
                0 => "\x1b[38;5;244m", // Bytes - dark gray
                1 => "\x1b[38;5;46m", // KB - bright green
                2 => "\x1b[38;5;226m", // MB - bright yellow
                3 => "\x1b[38;5;214m", // GB - orange
                else => "\x1b[1;38;5;196m", // TB+ - bright red bold
            };
            try self.stdout.writeAll(color);
        }

        try self.stdout.writeAll(str);

        if (self.color_enabled) try self.stdout.writeAll("\x1b[0m");
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
        // Print icon if enabled
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
            if (self.color_enabled) {
                try self.stdout.writeAll(colors.RESET);
            }
        }

        if (self.color_enabled) {
            const color_code = if (self.config.theme == .standard)
                colors.getColorForEntry(entry, self.config)
            else
                themes.getFileTypeColor(self.config.theme, entry.name, entry.is_directory, entry.is_executable, entry.is_symlink);
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
        const file_epoch_day: i64 = @divFloor(epoch_seconds, std.time.s_per_day);
        const epoch_day = std.time.epoch.EpochDay{ .day = @intCast(file_epoch_day) };
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();

        const seconds_today: u32 = @intCast(@mod(epoch_seconds, std.time.s_per_day));
        const hours = seconds_today / 3600;
        const minutes = (seconds_today % 3600) / 60;

        // Calculate current date
        const now_seconds = std.time.timestamp();
        const now_epoch_day: i64 = @divFloor(now_seconds, std.time.s_per_day);
        const days_ago = now_epoch_day - file_epoch_day;

        // Colors for relative dates
        const color_today = "\x1b[1;32m"; // Bold green for today
        const color_yesterday = "\x1b[1;33m"; // Bold yellow for yesterday
        const color_week = "\x1b[36m"; // Cyan for this week
        const color_old = "\x1b[90m"; // Gray for old files
        const reset = "\x1b[0m";

        // Fixed width: 17 characters for perfect alignment
        if (days_ago == 0) {
            if (self.color_enabled) try self.stdout.writeAll(color_today);
            try self.stdout.print("   today  {d:0>2}:{d:0>2}  ", .{ hours, minutes });
            if (self.color_enabled) try self.stdout.writeAll(reset);
        } else if (days_ago == 1) {
            if (self.color_enabled) try self.stdout.writeAll(color_yesterday);
            try self.stdout.print("yesterday {d:0>2}:{d:0>2}  ", .{ hours, minutes });
            if (self.color_enabled) try self.stdout.writeAll(reset);
        } else if (days_ago >= 2 and days_ago <= 6) {
            const weekday_names = [_][]const u8{ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };
            const weekday: usize = @intCast(@mod(file_epoch_day + 4, 7));
            if (self.color_enabled) try self.stdout.writeAll(color_week);
            try self.stdout.print("{d}d ago {s} {d:0>2}:{d:0>2}  ", .{ days_ago, weekday_names[weekday], hours, minutes });
            if (self.color_enabled) try self.stdout.writeAll(reset);
        } else {
            const month_names = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
            if (self.color_enabled) try self.stdout.writeAll(color_old);
            try self.stdout.print("{d:0>2} {s} {d} {d:0>2}:{d:0>2}", .{
                month_day.day_index + 1,
                month_names[month_day.month.numeric() - 1],
                year_day.year,
                hours,
                minutes,
            });
            if (self.color_enabled) try self.stdout.writeAll(reset);
        }
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
