const std = @import("std");
const FileEntry = @import("file_entry.zig").FileEntry;
const Config = @import("../args.zig").Config;

const ScanJob = struct {
    path: []const u8,
};

pub const ParallelScanner = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    entries: std.ArrayList(FileEntry),
    arena: std.heap.ArenaAllocator,
    mutex: std.Thread.Mutex,
    job_queue: std.ArrayList(ScanJob),
    queue_mutex: std.Thread.Mutex,
    done: std.atomic.Value(bool),
    num_threads: usize,
    
    pub fn init(allocator: std.mem.Allocator, config: *const Config) !ParallelScanner {
        const num_threads = @max(1, std.Thread.getCpuCount() catch 4);
        
        return ParallelScanner{
            .allocator = allocator,
            .config = config,
            .entries = std.ArrayList(FileEntry){},
            .arena = std.heap.ArenaAllocator.init(allocator),
            .mutex = .{},
            .job_queue = std.ArrayList(ScanJob){},
            .queue_mutex = .{},
            .done = std.atomic.Value(bool).init(false),
            .num_threads = num_threads,
        };
    }
    
    pub fn deinit(self: *ParallelScanner) void {
        self.entries.deinit(self.allocator);
        self.job_queue.deinit(self.allocator);
        self.arena.deinit();
    }
    
    pub fn scanRecursive(self: *ParallelScanner, root_path: []const u8) !void {
        const arena_allocator = self.arena.allocator();
        const path_copy = try arena_allocator.dupe(u8, root_path);
        
        try self.job_queue.append(self.allocator, .{ .path = path_copy });
        
        // Pre-allocate for better performance
        try self.entries.ensureUnusedCapacity(self.allocator, 4096);
        
        // Launch worker threads
        var threads = std.ArrayList(std.Thread){};
        defer {
            self.done.store(true, .seq_cst);
            for (threads.items) |thread| {
                thread.join();
            }
            threads.deinit(self.allocator);
        }
        
        for (0..self.num_threads) |_| {
            const thread = try std.Thread.spawn(.{}, workerThread, .{self});
            try threads.append(self.allocator, thread);
        }
    }
    
    fn workerThread(self: *ParallelScanner) void {
        while (true) {
            const job = self.getNextJob() orelse {
                // Check if work is complete
                if (self.done.load(.seq_cst)) break;
                std.Thread.yield() catch {};
                continue;
            };
            
            self.scanDirectory(job.path) catch {};
        }
    }
    
    fn getNextJob(self: *ParallelScanner) ?ScanJob {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();
        
        if (self.job_queue.items.len == 0) return null;
        return self.job_queue.orderedRemove(0);
    }
    
    fn addJob(self: *ParallelScanner, path: []const u8) !void {
        self.queue_mutex.lock();
        defer self.queue_mutex.unlock();
        
        try self.job_queue.append(self.allocator, .{ .path = path });
    }
    
    fn scanDirectory(self: *ParallelScanner, path: []const u8) !void {
        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
            if (err == error.AccessDenied or err == error.PermissionDenied) return;
            return err;
        };
        defer dir.close();
        
        const arena_allocator = self.arena.allocator();
        var iterator = dir.iterate();
        
        var local_entries = std.ArrayList(FileEntry){};
        defer local_entries.deinit(self.allocator);
        
        var subdirs = std.ArrayList([]const u8){};
        defer subdirs.deinit(self.allocator);
        
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
            
            try local_entries.append(self.allocator, file_entry);
            
            // Queue subdirectories for scanning
            if (entry.kind == .directory and 
                !std.mem.eql(u8, entry.name, ".") and 
                !std.mem.eql(u8, entry.name, "..")) 
            {
                const full_path = try std.fs.path.join(
                    arena_allocator,
                    &[_][]const u8{ path, entry.name }
                );
                try subdirs.append(self.allocator, full_path);
            }
        }
        
        // Batch append to main list
        if (local_entries.items.len > 0) {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            try self.entries.ensureUnusedCapacity(self.allocator, local_entries.items.len);
            for (local_entries.items) |entry| {
                try self.entries.append(self.allocator, entry);
            }
        }
        
        // Queue subdirectories
        for (subdirs.items) |subdir| {
            try self.addJob(subdir);
        }
    }
    
    pub fn getEntries(self: *const ParallelScanner) []const FileEntry {
        return self.entries.items;
    }
};
