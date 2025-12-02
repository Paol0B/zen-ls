const std = @import("std");

// C structures for getpwuid and getgrgid
const c = @cImport({
    @cInclude("pwd.h");
    @cInclude("grp.h");
});

/// Cache to avoid repeated system calls
pub const UserCache = struct {
    allocator: std.mem.Allocator,
    user_names: std.AutoHashMap(u32, []const u8),
    group_names: std.AutoHashMap(u32, []const u8),

    pub fn init(allocator: std.mem.Allocator) UserCache {
        return UserCache{
            .allocator = allocator,
            .user_names = std.AutoHashMap(u32, []const u8).init(allocator),
            .group_names = std.AutoHashMap(u32, []const u8).init(allocator),
        };
    }

    pub fn deinit(self: *UserCache) void {
        var user_it = self.user_names.valueIterator();
        while (user_it.next()) |name| {
            self.allocator.free(name.*);
        }
        self.user_names.deinit();

        var group_it = self.group_names.valueIterator();
        while (group_it.next()) |name| {
            self.allocator.free(name.*);
        }
        self.group_names.deinit();
    }

    /// Get username for a UID, with caching
    pub fn getUserName(self: *UserCache, uid: u32) []const u8 {
        // Check cache
        if (self.user_names.get(uid)) |cached| {
            return cached;
        }

        // Call getpwuid
        const pw = c.getpwuid(uid);
        if (pw != null and pw.*.pw_name != null) {
            const name_ptr = pw.*.pw_name;
            const name_len = std.mem.len(name_ptr);
            const name = self.allocator.dupe(u8, name_ptr[0..name_len]) catch {
                return formatUid(uid);
            };
            self.user_names.put(uid, name) catch {};
            return name;
        }

        // Fallback to numeric UID
        return formatUid(uid);
    }

    /// Get group name for a GID, with caching
    pub fn getGroupName(self: *UserCache, gid: u32) []const u8 {
        // Check cache
        if (self.group_names.get(gid)) |cached| {
            return cached;
        }

        // Call getgrgid
        const gr = c.getgrgid(gid);
        if (gr != null and gr.*.gr_name != null) {
            const name_ptr = gr.*.gr_name;
            const name_len = std.mem.len(name_ptr);
            const name = self.allocator.dupe(u8, name_ptr[0..name_len]) catch {
                return formatGid(gid);
            };
            self.group_names.put(gid, name) catch {};
            return name;
        }

        // Fallback to numeric GID
        return formatGid(gid);
    }
};

// Static buffers for numeric fallbacks
var uid_buffer: [16]u8 = undefined;
var gid_buffer: [16]u8 = undefined;

fn formatUid(uid: u32) []const u8 {
    return std.fmt.bufPrint(&uid_buffer, "{d}", .{uid}) catch "?";
}

fn formatGid(gid: u32) []const u8 {
    return std.fmt.bufPrint(&gid_buffer, "{d}", .{gid}) catch "?";
}
