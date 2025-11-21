const std = @import("std");

pub fn formatSize(size: u64, human_readable: bool, buffer: []u8) ![]const u8 {
    if (!human_readable) {
        return try std.fmt.bufPrint(buffer, "{d}", .{size});
    }
    
    const units = [_][]const u8{ "B", "K", "M", "G", "T", "P" };
    var size_float: f64 = @floatFromInt(size);
    var unit_idx: usize = 0;
    
    while (size_float >= 1024.0 and unit_idx < units.len - 1) {
        size_float /= 1024.0;
        unit_idx += 1;
    }
    
    if (unit_idx == 0) {
        return try std.fmt.bufPrint(buffer, "{d}{s}", .{ size, units[unit_idx] });
    } else {
        return try std.fmt.bufPrint(buffer, "{d:.1}{s}", .{ size_float, units[unit_idx] });
    }
}

pub fn formatTimestamp(timestamp: i128, buffer: []u8) ![]const u8 {
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
    
    return try std.fmt.bufPrint(buffer, "{s} {d:>2} {d:>2}:{d:>2}", .{
        month_names[month_day.month.numeric() - 1],
        month_day.day_index + 1,
        hours,
        minutes,
    });
}
