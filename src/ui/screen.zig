const std = @import("std");

pub const Screen = struct {
    stdout: std.fs.File,
    width: usize,
    height: usize,
    
    pub fn init() !Screen {
        const stdout = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
        const size = try getTerminalSize();
        
        return Screen{
            .stdout = stdout,
            .width = size.width,
            .height = size.height,
        };
    }
    
    pub fn clear(self: *Screen) !void {
        try self.stdout.writeAll("\x1b[2J");
        try self.moveCursor(1, 1);
    }
    
    pub fn moveCursor(self: *Screen, row: usize, col: usize) !void {
        var buf: [32]u8 = undefined;
        const cmd = try std.fmt.bufPrint(&buf, "\x1b[{d};{d}H", .{ row, col });
        try self.stdout.writeAll(cmd);
    }
    
    pub fn hideCursor(self: *Screen) !void {
        try self.stdout.writeAll("\x1b[?25l");
    }
    
    pub fn showCursor(self: *Screen) !void {
        try self.stdout.writeAll("\x1b[?25h");
    }
    
    pub fn setColor(self: *Screen, color: []const u8) !void {
        try self.stdout.writeAll(color);
    }
    
    pub fn resetColor(self: *Screen) !void {
        try self.stdout.writeAll("\x1b[0m");
    }
    
    pub fn drawBox(self: *Screen, row: usize, col: usize, width: usize, height: usize, title: []const u8) !void {
        // Top border
        try self.moveCursor(row, col);
        try self.stdout.writeAll("┌");
        if (title.len > 0 and title.len + 2 < width) {
            try self.stdout.writeAll(" ");
            try self.stdout.writeAll(title);
            try self.stdout.writeAll(" ");
            var i: usize = title.len + 2;
            while (i < width - 1) : (i += 1) {
                try self.stdout.writeAll("─");
            }
        } else {
            var i: usize = 0;
            while (i < width - 2) : (i += 1) {
                try self.stdout.writeAll("─");
            }
        }
        try self.stdout.writeAll("┐");
        
        // Sides
        var r: usize = 1;
        while (r < height - 1) : (r += 1) {
            try self.moveCursor(row + r, col);
            try self.stdout.writeAll("│");
            try self.moveCursor(row + r, col + width - 1);
            try self.stdout.writeAll("│");
        }
        
        // Bottom border
        try self.moveCursor(row + height - 1, col);
        try self.stdout.writeAll("└");
        var i: usize = 0;
        while (i < width - 2) : (i += 1) {
            try self.stdout.writeAll("─");
        }
        try self.stdout.writeAll("┘");
    }
    
    pub fn writeAt(self: *Screen, row: usize, col: usize, text: []const u8) !void {
        try self.moveCursor(row, col);
        try self.stdout.writeAll(text);
    }
    
    pub fn flush(self: *Screen) !void {
        _ = self;
    }
    
    pub fn updateSize(self: *Screen) !void {
        const size = try getTerminalSize();
        self.width = size.width;
        self.height = size.height;
    }
};

const TermSize = struct {
    width: usize,
    height: usize,
};

fn getTerminalSize() !TermSize {
    var ws: std.posix.winsize = undefined;
    const result = std.posix.system.ioctl(std.posix.STDOUT_FILENO, std.posix.system.T.IOCGWINSZ, @intFromPtr(&ws));
    
    if (result == 0 and ws.col > 0 and ws.row > 0) {
        return TermSize{
            .width = ws.col,
            .height = ws.row,
        };
    }
    
    return TermSize{
        .width = 80,
        .height = 24,
    };
}
