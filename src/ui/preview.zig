const std = @import("std");
const Config = @import("../args.zig").Config;
const FileEntry = @import("../core/file_entry.zig").FileEntry;

pub const FilePreview = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    
    pub fn init(allocator: std.mem.Allocator, config: *const Config) FilePreview {
        return FilePreview{
            .allocator = allocator,
            .config = config,
        };
    }
    
    pub fn getPreview(self: *FilePreview, entry: *const FileEntry, max_lines: usize) !std.ArrayList([]const u8) {
        var lines = std.ArrayList([]const u8){};
        
        if (entry.is_directory) {
            try self.previewDirectory(entry, &lines, max_lines);
        } else {
            try self.previewFile(entry, &lines, max_lines);
        }
        
        return lines;
    }
    
    fn previewDirectory(self: *FilePreview, entry: *const FileEntry, lines: *std.ArrayList([]const u8), max_lines: usize) !void {
        var dir = std.fs.cwd().openDir(entry.path, .{ .iterate = true }) catch {
            try lines.append(self.allocator, try self.allocator.dupe(u8, "Cannot open directory"));
            return;
        };
        defer dir.close();
        
        var iter = dir.iterate();
        var count: usize = 0;
        
        try lines.append(self.allocator, try self.allocator.dupe(u8, "Directory contents:"));
        try lines.append(self.allocator, try self.allocator.dupe(u8, ""));
        
        while (try iter.next()) |item| {
            if (count >= max_lines - 3) {
                try lines.append(self.allocator, try self.allocator.dupe(u8, "..."));
                break;
            }
            
            const prefix = if (item.kind == .directory) "📁 " else "📄 ";
            const line = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ prefix, item.name });
            try lines.append(self.allocator, line);
            count += 1;
        }
    }
    
    fn previewFile(self: *FilePreview, entry: *const FileEntry, lines: *std.ArrayList([]const u8), max_lines: usize) !void {
        // Show file metadata
        try lines.append(self.allocator, try std.fmt.allocPrint(
            self.allocator,
            "File: {s}",
            .{entry.name}
        ));
        try lines.append(self.allocator, try std.fmt.allocPrint(
            self.allocator,
            "Size: {d} bytes",
            .{entry.size}
        ));
        
        var perm_buf: [10]u8 = undefined;
        const perms = entry.getPermissionsString(&perm_buf);
        try lines.append(self.allocator, try std.fmt.allocPrint(
            self.allocator,
            "Permissions: {s}",
            .{perms}
        ));
        try lines.append(self.allocator, try self.allocator.dupe(u8, ""));
        
        // Try to preview text content
        if (entry.size > 0 and entry.size < 1024 * 1024) { // Max 1MB
            const file = std.fs.cwd().openFile(entry.path, .{}) catch {
                try lines.append(self.allocator, try self.allocator.dupe(u8, "Cannot read file"));
                return;
            };
            defer file.close();
            
            var buf: [8192]u8 = undefined;
            const n = try file.read(&buf);
            
            if (n > 0) {
                // Check if it's likely text
                var is_text = true;
                for (buf[0..n]) |byte| {
                    if (byte < 32 and byte != '\n' and byte != '\r' and byte != '\t') {
                        is_text = false;
                        break;
                    }
                }
                
                if (is_text) {
                    try lines.append(self.allocator, try self.allocator.dupe(u8, "Content:"));
                    try lines.append(self.allocator, try self.allocator.dupe(u8, ""));
                    
                    var line_count: usize = 0;
                    var line_start: usize = 0;
                    
                    for (buf[0..n], 0..) |byte, i| {
                        if (byte == '\n' or i == n - 1) {
                            if (line_count >= max_lines - 8) {
                                try lines.append(self.allocator, try self.allocator.dupe(u8, "..."));
                                break;
                            }
                            
                            const end = if (byte == '\n') i else i + 1;
                            const line = try self.allocator.dupe(u8, buf[line_start..end]);
                            try lines.append(self.allocator, line);
                            line_start = i + 1;
                            line_count += 1;
                        }
                    }
                } else {
                    try lines.append(self.allocator, try self.allocator.dupe(u8, "[Binary file]"));
                }
            }
        } else if (entry.size >= 1024 * 1024) {
            try lines.append(self.allocator, try self.allocator.dupe(u8, "[File too large to preview]"));
        }
    }
};
