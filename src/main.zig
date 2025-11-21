const std = @import("std");
const builtin = @import("builtin");
const args = @import("args.zig");
const core = @import("core/core.zig");
const renderer = @import("renderer/renderer.zig");
const ui = @import("ui/ui.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    var config = try args.parseArgs(allocator);
    defer config.deinit(allocator);

    // Handle special modes
    if (config.show_help) {
        try printHelp();
        return;
    }

    if (config.show_version) {
        try printVersion();
        return;
    }

    // Initialize core filesystem engine
    var fs_engine = try core.FilesystemEngine.init(allocator, &config);
    defer fs_engine.deinit();

    // Scan directory/directories
    try fs_engine.scan();

    // Choose output mode based on configuration
    if (config.interactive_mode) {
        // Launch interactive TUI
        var tui = try ui.InteractiveUI.init(allocator, &config, &fs_engine);
        defer tui.deinit();
        try tui.run();
    } else {
        // Standard output rendering
        var render_engine = try renderer.RenderEngine.init(allocator, &config);
        defer render_engine.deinit();
        try render_engine.render(&fs_engine);
    }
}

fn printHelp() !void {
    const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    const stdout = stdout_file.deprecatedWriter();
    try stdout.writeAll(
        \\ZEN-LS: Zero-overhead Enhanced Navigator for Linux Systems
        \\
        \\Usage: zen-ls [OPTIONS] [PATH...]
        \\
        \\POSIX Compatible Options:
        \\  -a, --all                     Show hidden files
        \\  -A, --almost-all              Show all except . and ..
        \\  -l                            Long listing format
        \\  -h, --human-readable          Human readable sizes (1K, 234M, 2G)
        \\  -r, --reverse                 Reverse sort order
        \\  -R, --recursive               List subdirectories recursively
        \\  -S                            Sort by size, largest first
        \\  -t                            Sort by time, newest first
        \\  -1                            List one file per line
        \\  --color[=WHEN]                Colorize output (always, auto, never)
        \\  -F, --classify                Append indicator (*/=>@|) to entries
        \\  -d, --directory               List directories themselves, not contents
        \\  --group-directories-first     List directories first
        \\
        \\ZEN-LS Advanced Options:
        \\  --interactive                 Launch interactive TUI mode
        \\  --preview                     Enable file preview pane
        \\  --git                         Show Git status information
        \\  --icons                       Show file type icons (Nerd Fonts)
        \\  --tree                        Tree view display
        \\  --stats                       Show detailed statistics
        \\  
        \\Visual Enhancement:
        \\  --neon                        Neon glow effects
        \\  --matrix                      Matrix-style visualization
        \\  --cyberpunk                   Cyberpunk theme with glitch effects
        \\  --galaxy                      3D galaxy filesystem visualization
        \\  
        \\Performance:
        \\  --turbo                       Maximum performance mode
        \\  --cache-strategy=MODE         Cache strategy (aggressive|balanced|minimal)
        \\  
        \\Developer Features:
        \\  --metrics                     Show code metrics (LOC, complexity)
        \\  --deps                        Visualize dependency tree
        \\  --build-status                Show build status indicators
        \\  
        \\Analysis & Security:
        \\  --deep-scan                   Deep content analysis
        \\  --security-audit              Full security audit
        \\  --dupes                       Find duplicate files
        \\  
        \\For full documentation: https://github.com/zen-ls/zen-ls
        \\
    );
}

fn printVersion() !void {
    const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    const stdout = stdout_file.deprecatedWriter();
    try stdout.writeAll("zen-ls 0.1.0 (alpha)\n");
    try stdout.print("Zig version: {s}\n", .{builtin.zig_version_string});
    try stdout.print("Target: {s}-{s}\n", .{ @tagName(builtin.cpu.arch), @tagName(builtin.os.tag) });
}

test "main tests" {
    @import("std").testing.refAllDecls(@This());
}
