const std = @import("std");
const Config = @import("../args.zig").Config;

pub const FileEntry = struct {
    name: []const u8,
    path: []const u8,
    size: u64,
    is_directory: bool,
    is_symlink: bool,
    is_executable: bool,
    permissions: u32,
    uid: u32,
    gid: u32,
    inode: u64,
    mtime: i128,
    atime: i128,
    ctime: i128,
    link_target: ?[]const u8,
    
    pub fn fromDirEntry(
        allocator: std.mem.Allocator,
        parent_path: []const u8,
        entry: std.fs.Dir.Entry,
        config: *const Config
    ) !FileEntry {
        const name = try allocator.dupe(u8, entry.name);
        
        // Build path on stack first, then allocate only if needed
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const path_tmp = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ parent_path, entry.name });
        const path = try allocator.dupe(u8, path_tmp);
        
        const is_directory = entry.kind == .directory;
        const is_symlink = entry.kind == .sym_link;
        
        // Lazy stat: only call stat if we absolutely need detailed info
        const need_stat = config.long_format or config.sort_by_size or config.sort_by_time;
        
        if (!need_stat) {
            // Fast path: skip stat entirely
            return FileEntry{
                .name = name,
                .path = path,
                .size = 0,
                .is_directory = is_directory,
                .is_symlink = is_symlink,
                .is_executable = false,
                .permissions = 0,
                .uid = 0,
                .gid = 0,
                .inode = 0,
                .mtime = 0,
                .atime = 0,
                .ctime = 0,
                .link_target = null,
            };
        }
        
        const stat = std.fs.cwd().statFile(path) catch {
            return FileEntry{
                .name = name,
                .path = path,
                .size = 0,
                .is_directory = is_directory,
                .is_symlink = is_symlink,
                .is_executable = false,
                .permissions = 0,
                .uid = 0,
                .gid = 0,
                .inode = 0,
                .mtime = 0,
                .atime = 0,
                .ctime = 0,
                .link_target = null,
            };
        };
        
        // Check if executable
        const mode = stat.mode;
        const is_executable = (mode & 0o111) != 0;
        
        // Read symlink target only if absolutely needed
        var link_target: ?[]const u8 = null;
        if (is_symlink and config.dereference) {
            var buf: [std.fs.max_path_bytes]u8 = undefined;
            if (std.fs.cwd().readLink(path, &buf)) |target| {
                link_target = try allocator.dupe(u8, target);
            } else |_| {}
        }
        
        return FileEntry{
            .name = name,
            .path = path,
            .size = stat.size,
            .is_directory = is_directory,
            .is_symlink = is_symlink,
            .is_executable = is_executable and !is_directory,
            .permissions = @intCast(mode & 0o777),
            .uid = if (@hasField(@TypeOf(stat), "uid")) stat.uid else 0,
            .gid = if (@hasField(@TypeOf(stat), "gid")) stat.gid else 0,
            .inode = stat.inode,
            .mtime = stat.mtime,
            .atime = stat.atime,
            .ctime = stat.ctime,
            .link_target = link_target,
        };
    }
    
    pub fn deinit(self: *FileEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.path);
        if (self.link_target) |target| {
            allocator.free(target);
        }
    }
    
    pub fn getPermissionsString(self: *const FileEntry, buffer: []u8) []const u8 {
        std.debug.assert(buffer.len >= 10);
        
        // File type
        buffer[0] = if (self.is_directory) 'd' else if (self.is_symlink) 'l' else '-';
        
        // Owner permissions
        buffer[1] = if (self.permissions & 0o400 != 0) 'r' else '-';
        buffer[2] = if (self.permissions & 0o200 != 0) 'w' else '-';
        buffer[3] = if (self.permissions & 0o100 != 0) 'x' else '-';
        
        // Group permissions
        buffer[4] = if (self.permissions & 0o040 != 0) 'r' else '-';
        buffer[5] = if (self.permissions & 0o020 != 0) 'w' else '-';
        buffer[6] = if (self.permissions & 0o010 != 0) 'x' else '-';
        
        // Other permissions
        buffer[7] = if (self.permissions & 0o004 != 0) 'r' else '-';
        buffer[8] = if (self.permissions & 0o002 != 0) 'w' else '-';
        buffer[9] = if (self.permissions & 0o001 != 0) 'x' else '-';
        
        return buffer[0..10];
    }
    
    pub fn getClassifier(self: *const FileEntry) u8 {
        if (self.is_directory) return '/';
        if (self.is_symlink) return '@';
        if (self.is_executable) return '*';
        return 0;
    }
    
    pub fn getIcon(self: *const FileEntry) []const u8 {
        if (self.is_directory) return "📁";
        if (self.is_symlink) return "🔗";
        
        // Get extension
        if (std.mem.lastIndexOf(u8, self.name, ".")) |dot_pos| {
            const ext = self.name[dot_pos + 1 ..];
            
            // Programming languages
            if (std.mem.eql(u8, ext, "zig")) return "";
            if (std.mem.eql(u8, ext, "rs")) return "";
            if (std.mem.eql(u8, ext, "py")) return "";
            if (std.mem.eql(u8, ext, "js")) return "";
            if (std.mem.eql(u8, ext, "ts")) return "";
            if (std.mem.eql(u8, ext, "go")) return "";
            if (std.mem.eql(u8, ext, "c") or std.mem.eql(u8, ext, "h")) return "";
            if (std.mem.eql(u8, ext, "cpp") or std.mem.eql(u8, ext, "hpp")) return "";
            
            // Web
            if (std.mem.eql(u8, ext, "html")) return "";
            if (std.mem.eql(u8, ext, "css")) return "";
            if (std.mem.eql(u8, ext, "json")) return "";
            
            // Documents
            if (std.mem.eql(u8, ext, "pdf")) return "";
            if (std.mem.eql(u8, ext, "md")) return "";
            if (std.mem.eql(u8, ext, "txt")) return "";
            
            // Media
            if (std.mem.eql(u8, ext, "png") or std.mem.eql(u8, ext, "jpg") or std.mem.eql(u8, ext, "jpeg")) return "";
            if (std.mem.eql(u8, ext, "mp4") or std.mem.eql(u8, ext, "avi")) return "";
            if (std.mem.eql(u8, ext, "mp3") or std.mem.eql(u8, ext, "wav")) return "";
            
            // Archives
            if (std.mem.eql(u8, ext, "zip") or std.mem.eql(u8, ext, "tar") or std.mem.eql(u8, ext, "gz")) return "";
        }
        
        return "📄";
    }
};

test "file entry permissions" {
    const allocator = std.testing.allocator;
    
    var entry = FileEntry{
        .name = try allocator.dupe(u8, "test"),
        .path = try allocator.dupe(u8, "/test"),
        .size = 0,
        .is_directory = false,
        .is_symlink = false,
        .is_executable = false,
        .permissions = 0o755,
        .uid = 0,
        .gid = 0,
        .inode = 0,
        .mtime = 0,
        .atime = 0,
        .ctime = 0,
        .link_target = null,
    };
    defer entry.deinit(allocator);
    
    var buffer: [10]u8 = undefined;
    const perms = entry.getPermissionsString(&buffer);
    
    try std.testing.expectEqualStrings("-rwxr-xr-x", perms);
}
