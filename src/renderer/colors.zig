const std = @import("std");
const Config = @import("../args.zig").Config;
const FileEntry = @import("../core/file_entry.zig").FileEntry;

// ANSI Color Codes
pub const RESET = "\x1b[0m";
pub const BOLD = "\x1b[1m";

// Basic colors
pub const BLACK = "\x1b[30m";
pub const RED = "\x1b[31m";
pub const GREEN = "\x1b[32m";
pub const YELLOW = "\x1b[33m";
pub const BLUE = "\x1b[34m";
pub const MAGENTA = "\x1b[35m";
pub const CYAN = "\x1b[36m";
pub const WHITE = "\x1b[37m";

// Bright colors
pub const BRIGHT_BLACK = "\x1b[90m";
pub const BRIGHT_RED = "\x1b[91m";
pub const BRIGHT_GREEN = "\x1b[92m";
pub const BRIGHT_YELLOW = "\x1b[93m";
pub const BRIGHT_BLUE = "\x1b[94m";
pub const BRIGHT_MAGENTA = "\x1b[95m";
pub const BRIGHT_CYAN = "\x1b[96m";
pub const BRIGHT_WHITE = "\x1b[97m";

// Background colors
pub const BG_BLACK = "\x1b[40m";
pub const BG_RED = "\x1b[41m";
pub const BG_GREEN = "\x1b[42m";
pub const BG_YELLOW = "\x1b[43m";
pub const BG_BLUE = "\x1b[44m";
pub const BG_MAGENTA = "\x1b[45m";
pub const BG_CYAN = "\x1b[46m";
pub const BG_WHITE = "\x1b[47m";

// Special effects (ZEN-LS)
pub const NEON_GREEN = "\x1b[38;5;46m";
pub const NEON_PINK = "\x1b[38;5;201m";
pub const NEON_CYAN = "\x1b[38;5;51m";
pub const CYBERPUNK_YELLOW = "\x1b[38;5;226m";
pub const CYBERPUNK_MAGENTA = "\x1b[38;5;199m";

pub fn getColorForEntry(entry: *const FileEntry, config: *const Config) []const u8 {
    // Special visual modes
    if (config.neon_mode) {
        if (entry.is_directory) return NEON_CYAN;
        if (entry.is_executable) return NEON_GREEN;
        return NEON_PINK;
    }
    
    if (config.cyberpunk_mode) {
        if (entry.is_directory) return CYBERPUNK_MAGENTA;
        if (entry.is_executable) return CYBERPUNK_YELLOW;
        return BRIGHT_CYAN;
    }
    
    // Standard LS_COLORS logic
    if (entry.is_directory) {
        return BOLD ++ BLUE;
    }
    
    if (entry.is_symlink) {
        return BOLD ++ CYAN;
    }
    
    if (entry.is_executable) {
        return BOLD ++ GREEN;
    }
    
    // Check file extension for color coding
    if (std.mem.lastIndexOf(u8, entry.name, ".")) |dot_pos| {
        const ext = entry.name[dot_pos + 1 ..];
        
        // Archives
        if (std.mem.eql(u8, ext, "tar") or 
            std.mem.eql(u8, ext, "gz") or 
            std.mem.eql(u8, ext, "zip") or
            std.mem.eql(u8, ext, "bz2") or
            std.mem.eql(u8, ext, "xz") or
            std.mem.eql(u8, ext, "7z")) {
            return BOLD ++ RED;
        }
        
        // Images
        if (std.mem.eql(u8, ext, "jpg") or 
            std.mem.eql(u8, ext, "jpeg") or 
            std.mem.eql(u8, ext, "png") or
            std.mem.eql(u8, ext, "gif") or
            std.mem.eql(u8, ext, "bmp") or
            std.mem.eql(u8, ext, "svg")) {
            return BOLD ++ MAGENTA;
        }
        
        // Audio/Video
        if (std.mem.eql(u8, ext, "mp3") or 
            std.mem.eql(u8, ext, "mp4") or 
            std.mem.eql(u8, ext, "avi") or
            std.mem.eql(u8, ext, "mkv") or
            std.mem.eql(u8, ext, "wav") or
            std.mem.eql(u8, ext, "flac")) {
            return BOLD ++ YELLOW;
        }
        
        // Source code
        if (std.mem.eql(u8, ext, "zig") or
            std.mem.eql(u8, ext, "c") or
            std.mem.eql(u8, ext, "cpp") or
            std.mem.eql(u8, ext, "h") or
            std.mem.eql(u8, ext, "py") or
            std.mem.eql(u8, ext, "rs") or
            std.mem.eql(u8, ext, "go") or
            std.mem.eql(u8, ext, "js") or
            std.mem.eql(u8, ext, "ts")) {
            return CYAN;
        }
        
        // Documents
        if (std.mem.eql(u8, ext, "pdf") or
            std.mem.eql(u8, ext, "doc") or
            std.mem.eql(u8, ext, "docx") or
            std.mem.eql(u8, ext, "txt") or
            std.mem.eql(u8, ext, "md")) {
            return WHITE;
        }
    }
    
    // Default color
    return RESET;
}

pub fn rgb(r: u8, g: u8, b: u8) [20]u8 {
    var buf: [20]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "\x1b[38;2;{d};{d};{d}m", .{ r, g, b }) catch unreachable;
    return buf;
}

pub fn bg_rgb(r: u8, g: u8, b: u8) [20]u8 {
    var buf: [20]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "\x1b[48;2;{d};{d};{d}m", .{ r, g, b }) catch unreachable;
    return buf;
}
