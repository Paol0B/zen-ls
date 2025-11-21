const std = @import("std");
const Config = @import("../args.zig").Config;
const core = @import("../core/core.zig");

pub const InteractiveUI = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    fs_engine: *const core.FilesystemEngine,
    
    pub fn init(
        allocator: std.mem.Allocator,
        config: *const Config,
        fs_engine: *const core.FilesystemEngine
    ) !InteractiveUI {
        return InteractiveUI{
            .allocator = allocator,
            .config = config,
            .fs_engine = fs_engine,
        };
    }
    
    pub fn deinit(self: *InteractiveUI) void {
        _ = self;
    }
    
    pub fn run(self: *InteractiveUI) !void {
        const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        const stdout = stdout_file.deprecatedWriter();
        
        try stdout.writeAll("\x1b[2J\x1b[H"); // Clear screen and move cursor to top
        try stdout.writeAll("╔═══════════════════════════════════════════════════════════════╗\n");
        try stdout.writeAll("║          ZEN-LS Interactive Mode (Coming Soon!)              ║\n");
        try stdout.writeAll("╚═══════════════════════════════════════════════════════════════╝\n\n");
        
        try stdout.writeAll("Interactive features:\n");
        try stdout.writeAll("  • Vim-style navigation (hjkl)\n");
        try stdout.writeAll("  • Real-time file preview\n");
        try stdout.writeAll("  • Split view support\n");
        try stdout.writeAll("  • Fuzzy search filtering\n");
        try stdout.writeAll("  • Mouse support\n\n");
        
        try stdout.writeAll("Press Enter to continue with standard view...\n");
        
        // Wait for input
        const stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };
        const stdin = stdin_file.deprecatedReader();
        _ = try stdin.readByte();
        
        // Fall back to standard rendering for now
        const renderer = @import("../renderer/renderer.zig");
        var render_engine = try renderer.RenderEngine.init(self.allocator, self.config);
        defer render_engine.deinit();
        try render_engine.render(self.fs_engine);
    }
};
