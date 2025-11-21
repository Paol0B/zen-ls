const std = @import("std");
const Theme = @import("../args.zig").Theme;

pub const ThemeColors = struct {
    directory: []const u8,
    executable: []const u8,
    symlink: []const u8,
    file: []const u8,
    archive: []const u8,
    image: []const u8,
    video: []const u8,
    audio: []const u8,
    document: []const u8,
    code: []const u8,
    special: []const u8,
};

pub fn getThemeColors(theme: Theme) ThemeColors {
    return switch (theme) {
        .standard => ThemeColors{
            .directory = "\x1b[1;34m",      // Bold blue
            .executable = "\x1b[1;32m",     // Bold green
            .symlink = "\x1b[1;36m",        // Bold cyan
            .file = "\x1b[0m",              // Default
            .archive = "\x1b[1;31m",        // Bold red
            .image = "\x1b[1;35m",          // Bold magenta
            .video = "\x1b[1;35m",          // Bold magenta
            .audio = "\x1b[0;36m",          // Cyan
            .document = "\x1b[0m",          // Default
            .code = "\x1b[0;33m",           // Yellow
            .special = "\x1b[1;33m",        // Bold yellow
        },
        .neon => ThemeColors{
            .directory = "\x1b[38;5;51m",   // Bright cyan
            .executable = "\x1b[38;5;46m",  // Neon green
            .symlink = "\x1b[38;5;213m",    // Pink
            .file = "\x1b[38;5;255m",       // Bright white
            .archive = "\x1b[38;5;196m",    // Neon red
            .image = "\x1b[38;5;201m",      // Neon magenta
            .video = "\x1b[38;5;165m",      // Purple
            .audio = "\x1b[38;5;87m",       // Bright cyan
            .document = "\x1b[38;5;231m",   // White
            .code = "\x1b[38;5;226m",       // Bright yellow
            .special = "\x1b[38;5;208m",    // Orange
        },
        .matrix => ThemeColors{
            .directory = "\x1b[38;5;40m",   // Matrix green
            .executable = "\x1b[38;5;46m",  // Bright green
            .symlink = "\x1b[38;5;34m",     // Dark green
            .file = "\x1b[38;5;28m",        // Green
            .archive = "\x1b[38;5;22m",     // Dark green
            .image = "\x1b[38;5;40m",       // Matrix green
            .video = "\x1b[38;5;34m",       // Dark green
            .audio = "\x1b[38;5;46m",       // Bright green
            .document = "\x1b[38;5;28m",    // Green
            .code = "\x1b[38;5;82m",        // Lime green
            .special = "\x1b[38;5;118m",    // Light green
        },
        .cyberpunk => ThemeColors{
            .directory = "\x1b[38;5;201m",  // Hot pink
            .executable = "\x1b[38;5;51m",  // Cyan
            .symlink = "\x1b[38;5;213m",    // Pink
            .file = "\x1b[38;5;231m",       // White
            .archive = "\x1b[38;5;196m",    // Red
            .image = "\x1b[38;5;165m",      // Purple
            .video = "\x1b[38;5;93m",       // Dark purple
            .audio = "\x1b[38;5;87m",       // Bright cyan
            .document = "\x1b[38;5;255m",   // Bright white
            .code = "\x1b[38;5;226m",       // Yellow
            .special = "\x1b[38;5;208m",    // Orange
        },
        .pastel => ThemeColors{
            .directory = "\x1b[38;5;117m",  // Pastel blue
            .executable = "\x1b[38;5;120m", // Pastel green
            .symlink = "\x1b[38;5;189m",    // Pastel cyan
            .file = "\x1b[38;5;252m",       // Light gray
            .archive = "\x1b[38;5;217m",    // Pastel red
            .image = "\x1b[38;5;219m",      // Pastel pink
            .video = "\x1b[38;5;183m",      // Pastel purple
            .audio = "\x1b[38;5;159m",      // Pastel cyan
            .document = "\x1b[38;5;230m",   // Pastel yellow
            .code = "\x1b[38;5;223m",       // Pastel orange
            .special = "\x1b[38;5;221m",    // Pastel gold
        },
        .monochrome => ThemeColors{
            .directory = "\x1b[1;37m",      // Bold white
            .executable = "\x1b[1;37m",     // Bold white
            .symlink = "\x1b[0;37m",        // White
            .file = "\x1b[0;37m",           // White
            .archive = "\x1b[1;37m",        // Bold white
            .image = "\x1b[0;37m",          // White
            .video = "\x1b[0;37m",          // White
            .audio = "\x1b[0;37m",          // White
            .document = "\x1b[0;37m",       // White
            .code = "\x1b[1;37m",           // Bold white
            .special = "\x1b[1;37m",        // Bold white
        },
    };
}

pub fn getFileTypeColor(theme: Theme, filename: []const u8, is_directory: bool, is_executable: bool, is_symlink: bool) []const u8 {
    const colors = getThemeColors(theme);
    
    if (is_directory) return colors.directory;
    if (is_executable) return colors.executable;
    if (is_symlink) return colors.symlink;
    
    const ext = getExtension(filename);
    
    // Archives
    if (isArchive(ext)) return colors.archive;
    
    // Images
    if (isImage(ext)) return colors.image;
    
    // Video
    if (isVideo(ext)) return colors.video;
    
    // Audio
    if (isAudio(ext)) return colors.audio;
    
    // Documents
    if (isDocument(ext)) return colors.document;
    
    // Code
    if (isCode(ext)) return colors.code;
    
    return colors.file;
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

fn isArchive(ext: []const u8) bool {
    return std.mem.eql(u8, ext, ".zip") or std.mem.eql(u8, ext, ".tar") or
           std.mem.eql(u8, ext, ".gz") or std.mem.eql(u8, ext, ".bz2") or
           std.mem.eql(u8, ext, ".xz") or std.mem.eql(u8, ext, ".7z") or
           std.mem.eql(u8, ext, ".rar") or std.mem.eql(u8, ext, ".tgz");
}

fn isImage(ext: []const u8) bool {
    return std.mem.eql(u8, ext, ".png") or std.mem.eql(u8, ext, ".jpg") or
           std.mem.eql(u8, ext, ".jpeg") or std.mem.eql(u8, ext, ".gif") or
           std.mem.eql(u8, ext, ".svg") or std.mem.eql(u8, ext, ".webp") or
           std.mem.eql(u8, ext, ".bmp") or std.mem.eql(u8, ext, ".ico");
}

fn isVideo(ext: []const u8) bool {
    return std.mem.eql(u8, ext, ".mp4") or std.mem.eql(u8, ext, ".mkv") or
           std.mem.eql(u8, ext, ".avi") or std.mem.eql(u8, ext, ".mov") or
           std.mem.eql(u8, ext, ".wmv") or std.mem.eql(u8, ext, ".flv") or
           std.mem.eql(u8, ext, ".webm");
}

fn isAudio(ext: []const u8) bool {
    return std.mem.eql(u8, ext, ".mp3") or std.mem.eql(u8, ext, ".flac") or
           std.mem.eql(u8, ext, ".wav") or std.mem.eql(u8, ext, ".ogg") or
           std.mem.eql(u8, ext, ".m4a") or std.mem.eql(u8, ext, ".aac") or
           std.mem.eql(u8, ext, ".wma");
}

fn isDocument(ext: []const u8) bool {
    return std.mem.eql(u8, ext, ".pdf") or std.mem.eql(u8, ext, ".doc") or
           std.mem.eql(u8, ext, ".docx") or std.mem.eql(u8, ext, ".txt") or
           std.mem.eql(u8, ext, ".md") or std.mem.eql(u8, ext, ".rtf") or
           std.mem.eql(u8, ext, ".odt");
}

fn isCode(ext: []const u8) bool {
    return std.mem.eql(u8, ext, ".zig") or std.mem.eql(u8, ext, ".rs") or
           std.mem.eql(u8, ext, ".go") or std.mem.eql(u8, ext, ".py") or
           std.mem.eql(u8, ext, ".js") or std.mem.eql(u8, ext, ".ts") or
           std.mem.eql(u8, ext, ".c") or std.mem.eql(u8, ext, ".cpp") or
           std.mem.eql(u8, ext, ".h") or std.mem.eql(u8, ext, ".hpp") or
           std.mem.eql(u8, ext, ".java") or std.mem.eql(u8, ext, ".rb") or
           std.mem.eql(u8, ext, ".php") or std.mem.eql(u8, ext, ".lua") or
           std.mem.eql(u8, ext, ".sh") or std.mem.eql(u8, ext, ".bash");
}
