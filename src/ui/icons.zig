const std = @import("std");

pub const IconSet = enum {
    none,
    nerd_fonts,
    unicode,
    ascii,
};

pub const Icon = struct {
    symbol: []const u8,
    color: []const u8,
};

pub fn getFileIcon(filename: []const u8, is_directory: bool, is_executable: bool) Icon {
    if (is_directory) {
        return .{ .symbol = "", .color = "\x1b[34m" }; // Blue folder
    }

    if (is_executable) {
        return .{ .symbol = "", .color = "\x1b[32m" }; // Green executable
    }

    // Get extension
    const ext = getExtension(filename);
    
    // Programming languages
    if (std.mem.eql(u8, ext, ".zig")) return .{ .symbol = "⚡", .color = "\x1b[38;5;208m" };
    if (std.mem.eql(u8, ext, ".rs")) return .{ .symbol = "", .color = "\x1b[38;5;208m" };
    if (std.mem.eql(u8, ext, ".go")) return .{ .symbol = "", .color = "\x1b[36m" };
    if (std.mem.eql(u8, ext, ".py")) return .{ .symbol = "", .color = "\x1b[33m" };
    if (std.mem.eql(u8, ext, ".js") or std.mem.eql(u8, ext, ".mjs")) return .{ .symbol = "", .color = "\x1b[33m" };
    if (std.mem.eql(u8, ext, ".ts")) return .{ .symbol = "", .color = "\x1b[34m" };
    if (std.mem.eql(u8, ext, ".c")) return .{ .symbol = "", .color = "\x1b[34m" };
    if (std.mem.eql(u8, ext, ".cpp") or std.mem.eql(u8, ext, ".cc")) return .{ .symbol = "", .color = "\x1b[35m" };
    if (std.mem.eql(u8, ext, ".h") or std.mem.eql(u8, ext, ".hpp")) return .{ .symbol = "", .color = "\x1b[35m" };
    if (std.mem.eql(u8, ext, ".java")) return .{ .symbol = "", .color = "\x1b[31m" };
    if (std.mem.eql(u8, ext, ".rb")) return .{ .symbol = "", .color = "\x1b[31m" };
    if (std.mem.eql(u8, ext, ".php")) return .{ .symbol = "", .color = "\x1b[35m" };
    if (std.mem.eql(u8, ext, ".lua")) return .{ .symbol = "", .color = "\x1b[34m" };
    if (std.mem.eql(u8, ext, ".vim")) return .{ .symbol = "", .color = "\x1b[32m" };
    if (std.mem.eql(u8, ext, ".sh") or std.mem.eql(u8, ext, ".bash")) return .{ .symbol = "", .color = "\x1b[32m" };
    
    // Web files
    if (std.mem.eql(u8, ext, ".html") or std.mem.eql(u8, ext, ".htm")) return .{ .symbol = "", .color = "\x1b[31m" };
    if (std.mem.eql(u8, ext, ".css")) return .{ .symbol = "", .color = "\x1b[34m" };
    if (std.mem.eql(u8, ext, ".scss") or std.mem.eql(u8, ext, ".sass")) return .{ .symbol = "", .color = "\x1b[35m" };
    if (std.mem.eql(u8, ext, ".json")) return .{ .symbol = "", .color = "\x1b[33m" };
    if (std.mem.eql(u8, ext, ".xml")) return .{ .symbol = "", .color = "\x1b[33m" };
    if (std.mem.eql(u8, ext, ".yaml") or std.mem.eql(u8, ext, ".yml")) return .{ .symbol = "", .color = "\x1b[33m" };
    if (std.mem.eql(u8, ext, ".toml")) return .{ .symbol = "", .color = "\x1b[33m" };
    
    // Documents
    if (std.mem.eql(u8, ext, ".md")) return .{ .symbol = "", .color = "\x1b[37m" };
    if (std.mem.eql(u8, ext, ".txt")) return .{ .symbol = "", .color = "\x1b[37m" };
    if (std.mem.eql(u8, ext, ".pdf")) return .{ .symbol = "", .color = "\x1b[31m" };
    if (std.mem.eql(u8, ext, ".doc") or std.mem.eql(u8, ext, ".docx")) return .{ .symbol = "", .color = "\x1b[34m" };
    
    // Images
    if (std.mem.eql(u8, ext, ".png") or std.mem.eql(u8, ext, ".jpg") or 
        std.mem.eql(u8, ext, ".jpeg") or std.mem.eql(u8, ext, ".gif") or
        std.mem.eql(u8, ext, ".svg") or std.mem.eql(u8, ext, ".webp")) 
        return .{ .symbol = "", .color = "\x1b[35m" };
    
    // Video
    if (std.mem.eql(u8, ext, ".mp4") or std.mem.eql(u8, ext, ".mkv") or
        std.mem.eql(u8, ext, ".avi") or std.mem.eql(u8, ext, ".mov"))
        return .{ .symbol = "", .color = "\x1b[35m" };
    
    // Audio
    if (std.mem.eql(u8, ext, ".mp3") or std.mem.eql(u8, ext, ".flac") or
        std.mem.eql(u8, ext, ".wav") or std.mem.eql(u8, ext, ".ogg"))
        return .{ .symbol = "", .color = "\x1b[36m" };
    
    // Archives
    if (std.mem.eql(u8, ext, ".zip") or std.mem.eql(u8, ext, ".tar") or
        std.mem.eql(u8, ext, ".gz") or std.mem.eql(u8, ext, ".bz2") or
        std.mem.eql(u8, ext, ".xz") or std.mem.eql(u8, ext, ".7z") or
        std.mem.eql(u8, ext, ".rar"))
        return .{ .symbol = "", .color = "\x1b[31m" };
    
    // Git
    if (std.mem.eql(u8, filename, ".gitignore") or 
        std.mem.eql(u8, filename, ".gitmodules") or
        std.mem.eql(u8, filename, ".gitattributes"))
        return .{ .symbol = "", .color = "\x1b[31m" };
    
    // Config files
    if (std.mem.eql(u8, filename, "Dockerfile")) return .{ .symbol = "", .color = "\x1b[34m" };
    if (std.mem.eql(u8, filename, "Makefile")) return .{ .symbol = "", .color = "\x1b[32m" };
    if (std.mem.eql(u8, filename, "README.md")) return .{ .symbol = "", .color = "\x1b[33m" };
    if (std.mem.eql(u8, filename, "LICENSE")) return .{ .symbol = "", .color = "\x1b[33m" };
    
    // Default
    return .{ .symbol = "", .color = "\x1b[37m" };
}

fn getExtension(filename: []const u8) []const u8 {
    var i = filename.len;
    while (i > 0) : (i -= 1) {
        if (filename[i - 1] == '.') {
            return filename[i - 1..];
        }
        if (filename[i - 1] == '/') break;
    }
    return "";
}

pub fn getUnicodeIcon(filename: []const u8, is_directory: bool, is_executable: bool) Icon {
    if (is_directory) return .{ .symbol = "📁", .color = "\x1b[34m" };
    if (is_executable) return .{ .symbol = "⚙️", .color = "\x1b[32m" };
    
    const ext = getExtension(filename);
    
    if (std.mem.eql(u8, ext, ".zip") or std.mem.eql(u8, ext, ".tar") or
        std.mem.eql(u8, ext, ".gz")) return .{ .symbol = "📦", .color = "\x1b[31m" };
    if (std.mem.eql(u8, ext, ".png") or std.mem.eql(u8, ext, ".jpg") or
        std.mem.eql(u8, ext, ".jpeg")) return .{ .symbol = "🖼️", .color = "\x1b[35m" };
    if (std.mem.eql(u8, ext, ".mp4") or std.mem.eql(u8, ext, ".mkv")) return .{ .symbol = "🎬", .color = "\x1b[35m" };
    if (std.mem.eql(u8, ext, ".mp3") or std.mem.eql(u8, ext, ".flac")) return .{ .symbol = "🎵", .color = "\x1b[36m" };
    if (std.mem.eql(u8, ext, ".pdf")) return .{ .symbol = "📄", .color = "\x1b[31m" };
    
    return .{ .symbol = "📄", .color = "\x1b[37m" };
}

pub fn getAsciiIcon(is_directory: bool, is_executable: bool) Icon {
    if (is_directory) return .{ .symbol = "[DIR]", .color = "\x1b[34m" };
    if (is_executable) return .{ .symbol = "[EXE]", .color = "\x1b[32m" };
    return .{ .symbol = "[FILE]", .color = "\x1b[37m" };
}
