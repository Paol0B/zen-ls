const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;

/// Ultra-fast directory scanner optimized for raw speed
/// Sacrifices features for performance:
/// - No stat calls (no metadata, sizes, times, permissions)
/// - No sorting
/// - Minimal allocations
/// - Direct syscalls
/// - Buffered output
pub const UltraFastScanner = struct {
    allocator: std.mem.Allocator,
    output_buffer: std.ArrayList(u8),
    
    pub fn init(allocator: std.mem.Allocator) !UltraFastScanner {
        return UltraFastScanner{
            .allocator = allocator,
            .output_buffer = std.ArrayList(u8){},
        };
    }
    
    pub fn deinit(self: *UltraFastScanner) void {
        self.output_buffer.deinit(self.allocator);
    }
    
    /// Scan directory and write names directly to buffer
    /// Returns number of entries found
    pub fn scanDirectory(self: *UltraFastScanner, path: []const u8) !usize {
        // Open directory using direct syscall
        const fd = posix.open(path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true }, 0) catch |err| {
            // Silently skip inaccessible directories
            if (err == error.AccessDenied or err == error.PermissionDenied) return 0;
            return err;
        };
        defer posix.close(fd);
        
        // Allocate stack buffer for getdents64 (32KB is optimal)
        var buffer: [32 * 1024]u8 = undefined;
        var entry_count: usize = 0;
        
        while (true) {
            // Direct getdents64 syscall - fastest way to read directory entries
            const nread = linux.getdents64(fd, &buffer, buffer.len);
            if (nread == 0) break; // End of directory
            if (nread < 0) return error.ReadFailed;
            
            // Parse all entries in buffer
            var offset: usize = 0;
            while (offset < @as(usize, @intCast(nread))) {
                // Cast to dirent64 structure (aligned access not required here)
                const dirent = @as(*align(1) linux.dirent64, @ptrCast(&buffer[offset]));
                
                // Extract null-terminated name
                const name_ptr = @as([*:0]u8, @ptrCast(@as([*]u8, @ptrCast(dirent)) + @offsetOf(linux.dirent64, "name")));
                const name = std.mem.span(name_ptr);
                
                // Skip . and .. (fastest check: compare first two bytes)
                if (name.len > 0 and name[0] != '.' or 
                    (name.len == 2 and name[1] != '.') or 
                    name.len > 2) 
                {
                    // Write name directly to buffer with newline
                    try self.output_buffer.appendSlice(self.allocator, name);
                    try self.output_buffer.append(self.allocator, '\n');
                    entry_count += 1;
                }
                
                // Move to next entry
                offset += dirent.reclen;
            }
        }
        
        return entry_count;
    }
    
    /// Recursive scan with minimal overhead
    pub fn scanRecursive(self: *UltraFastScanner, root_path: []const u8) !usize {
        var total_count: usize = 0;
        
        // Open directory
        const fd = posix.open(root_path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true }, 0) catch |err| {
            if (err == error.AccessDenied or err == error.PermissionDenied) return 0;
            return err;
        };
        defer posix.close(fd);
        
        // Stack buffer for getdents64
        var buffer: [32 * 1024]u8 = undefined;
        
        // Stack buffer for path construction (avoid heap allocations)
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        
        // Collect subdirectories in single pass
        var subdirs = std.ArrayList([]const u8){};
        defer {
            for (subdirs.items) |subdir| {
                self.allocator.free(subdir);
            }
            subdirs.deinit(self.allocator);
        }
        
        while (true) {
            const nread = linux.getdents64(fd, &buffer, buffer.len);
            if (nread == 0) break;
            if (nread < 0) return error.ReadFailed;
            
            var offset: usize = 0;
            while (offset < @as(usize, @intCast(nread))) {
                const dirent = @as(*align(1) linux.dirent64, @ptrCast(&buffer[offset]));
                const name_ptr = @as([*:0]u8, @ptrCast(@as([*]u8, @ptrCast(dirent)) + @offsetOf(linux.dirent64, "name")));
                const name = std.mem.span(name_ptr);
                
                // Skip . and ..
                const is_dot = name.len == 1 and name[0] == '.';
                const is_dotdot = name.len == 2 and name[0] == '.' and name[1] == '.';
                
                if (!is_dot and !is_dotdot) {
                    // Write name to output
                    try self.output_buffer.appendSlice(self.allocator, name);
                    try self.output_buffer.append(self.allocator, '\n');
                    total_count += 1;
                    
                    // If directory, queue for recursive scan
                    // DT.DIR = 4 (directory type from d_type field)
                    if (dirent.type == linux.DT.DIR) {
                        // Build full path on stack
                        const full_path = try std.fmt.bufPrint(
                            &path_buffer,
                            "{s}/{s}",
                            .{ root_path, name }
                        );
                        // Allocate copy for subdirs list
                        const path_copy = try self.allocator.dupe(u8, full_path);
                        try subdirs.append(self.allocator, path_copy);
                    }
                }
                
                offset += dirent.reclen;
            }
        }
        
        // Recursively scan subdirectories
        for (subdirs.items) |subdir| {
            total_count += try self.scanRecursive(subdir);
        }
        
        return total_count;
    }
    
    /// Flush output buffer to stdout
    pub fn flush(self: *UltraFastScanner) !void {
        if (self.output_buffer.items.len == 0) return;
        
        const stdout = std.fs.File{ .handle = posix.STDOUT_FILENO };
        
        // Single write syscall for entire buffer (much faster than many small writes)
        try stdout.writeAll(self.output_buffer.items);
        
        // Clear buffer
        self.output_buffer.clearRetainingCapacity();
    }
    
    pub fn getOutputSize(self: *const UltraFastScanner) usize {
        return self.output_buffer.items.len;
    }
};

test "ultra fast scanner basic" {
    const allocator = std.testing.allocator;
    
    var scanner = try UltraFastScanner.init(allocator);
    defer scanner.deinit();
    
    const count = try scanner.scanDirectory(".");
    try std.testing.expect(count > 0);
    try std.testing.expect(scanner.getOutputSize() > 0);
}
