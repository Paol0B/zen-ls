const std = @import("std");
const Config = @import("../args.zig").Config;
const FileEntry = @import("file_entry.zig").FileEntry;

pub const FilesystemEngine = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    entries: std.ArrayList(FileEntry),
    arena: std.heap.ArenaAllocator,
    
    pub fn init(allocator: std.mem.Allocator, config: *const Config) !FilesystemEngine {
        return FilesystemEngine{
            .allocator = allocator,
            .config = config,
            .entries = std.ArrayList(FileEntry){},
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }
    
    pub fn deinit(self: *FilesystemEngine) void {
        self.entries.deinit(self.allocator);
        self.arena.deinit();
    }
    
    pub fn scan(self: *FilesystemEngine) !void {
        for (self.config.paths.items) |path| {
            if (self.config.recursive) {
                try self.scanRecursiveSimple(path);
            } else {
                try self.scanDirectory(path);
            }
        }
        
        // Sort entries based on configuration
        try self.sortEntries();
    }
    
    fn scanDirectory(self: *FilesystemEngine, path: []const u8) !void {
        var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        defer dir.close();
        
        const arena_allocator = self.arena.allocator();
        var iterator = dir.iterate();
        
        // Pre-allocate capacity hint
        try self.entries.ensureUnusedCapacity(self.allocator, 256);
        
        while (try iterator.next()) |entry| {
            // Filter hidden files
            if (!self.config.show_hidden and !self.config.show_almost_all) {
                if (entry.name[0] == '.') continue;
            }
            
            if (self.config.show_almost_all) {
                if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) {
                    continue;
                }
            }
            
            const file_entry = try FileEntry.fromDirEntry(
                arena_allocator,
                path,
                entry,
                self.config
            );
            
            try self.entries.append(self.allocator, file_entry);
        }
    }
    
    fn scanRecursive(self: *FilesystemEngine, path: []const u8) !void {
        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
            // Skip directories we can't access
            if (err == error.AccessDenied or err == error.PermissionDenied) return;
            return err;
        };
        defer dir.close();
        
        const arena_allocator = self.arena.allocator();
        var iterator = dir.iterate();
        
        // Pre-allocate for better performance
        try self.entries.ensureUnusedCapacity(self.allocator, 128);
        
        while (try iterator.next()) |entry| {
            // Filter hidden files
            if (!self.config.show_hidden and !self.config.show_almost_all) {
                if (entry.name[0] == '.') continue;
            }
            
            if (self.config.show_almost_all) {
                if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) {
                    continue;
                }
            }
            
            const file_entry = try FileEntry.fromDirEntry(
                arena_allocator,
                path,
                entry,
                self.config
            );
            
            try self.entries.append(self.allocator, file_entry);
            
            // Recurse into subdirectories
            if (entry.kind == .directory and !std.mem.eql(u8, entry.name, ".") and !std.mem.eql(u8, entry.name, "..")) {
                const full_path = try std.fs.path.join(
                    arena_allocator,
                    &[_][]const u8{ path, entry.name }
                );
                
                try self.scanRecursive(full_path);
            }
        }
    }
    
    fn sortEntries(self: *FilesystemEngine) !void {
        const Context = struct {
            config: *const Config,
            
            pub fn lessThan(ctx: @This(), a: FileEntry, b: FileEntry) bool {
                // Group directories first if requested
                if (ctx.config.group_directories_first) {
                    if (a.is_directory and !b.is_directory) return !ctx.config.reverse_sort;
                    if (!a.is_directory and b.is_directory) return ctx.config.reverse_sort;
                }
                
                // Sort by size
                if (ctx.config.sort_by_size) {
                    const result = a.size < b.size;
                    return if (ctx.config.reverse_sort) !result else result;
                }
                
                // Sort by time
                if (ctx.config.sort_by_time) {
                    const result = a.mtime < b.mtime;
                    return if (ctx.config.reverse_sort) !result else result;
                }
                
                // Default: alphabetical sort
                const result = std.mem.lessThan(u8, a.name, b.name);
                return if (ctx.config.reverse_sort) !result else result;
            }
        };
        
        const context = Context{ .config = self.config };
        std.mem.sort(FileEntry, self.entries.items, context, Context.lessThan);
    }
    
    fn scanRecursiveSimple(self: *FilesystemEngine, root_path: []const u8) !void {
        var dir = std.fs.cwd().openDir(root_path, .{ .iterate = true }) catch return;
        defer dir.close();
        
        var iterator = dir.iterate();
        const arena_allocator = self.arena.allocator();
        
        // Reusable path buffer to avoid allocations
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        
        // Batch subdirectories to scan after finishing current directory
        var subdirs = std.ArrayList([]const u8){};
        defer subdirs.deinit(self.allocator);
        
        // Pre-allocate for typical directory size
        try self.entries.ensureUnusedCapacity(self.allocator, 64);
        
        while (try iterator.next()) |entry| {
            // Filter hidden files
            if (!self.config.show_hidden and !self.config.show_almost_all) {
                if (entry.name.len > 0 and entry.name[0] == '.') continue;
            }
            
            if (self.config.show_almost_all) {
                if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) {
                    continue;
                }
            }
            
            const file_entry = try FileEntry.fromDirEntry(
                arena_allocator,
                root_path,
                entry,
                self.config,
            );
            
            try self.entries.append(self.allocator, file_entry);
            
            // Queue subdirectories for later scanning
            if (entry.kind == .directory and 
                !std.mem.eql(u8, entry.name, ".") and 
                !std.mem.eql(u8, entry.name, "..")) 
            {
                // Build path directly in stack buffer
                const full_path = try std.fmt.bufPrint(
                    &path_buffer,
                    "{s}/{s}",
                    .{ root_path, entry.name }
                );
                const path_copy = try arena_allocator.dupe(u8, full_path);
                try subdirs.append(self.allocator, path_copy);
            }
        }
        
        // Scan subdirectories after finishing current level
        for (subdirs.items) |subdir| {
            try self.scanRecursiveSimple(subdir);
        }
    }
    
    pub fn getEntries(self: *const FilesystemEngine) []const FileEntry {
        return self.entries.items;
    }
};

test "filesystem engine init" {
    const allocator = std.testing.allocator;
    var config = Config{
        .paths = std.ArrayList([]const u8){},
    };
    defer config.deinit(allocator);
    
    var engine = try FilesystemEngine.init(allocator, &config);
    defer engine.deinit();
    
    try std.testing.expect(engine.entries.items.len == 0);
}
