const std = @import("std");

pub const Key = enum {
    up,
    down,
    left,
    right,
    enter,
    escape,
    backspace,
    delete,
    tab,
    home,
    end,
    page_up,
    page_down,
    char,
    ctrl_c,
    ctrl_q,
    ctrl_r,
    ctrl_h,
    ctrl_p,
    unknown,
};

pub const InputEvent = struct {
    key: Key,
    char: u8 = 0,
};

pub const InputHandler = struct {
    stdin: std.fs.File,
    original_termios: std.posix.termios = undefined,
    
    pub fn init() !InputHandler {
        const stdin = std.fs.File{ .handle = std.posix.STDIN_FILENO };
        var handler = InputHandler{
            .stdin = stdin,
        };
        
        // Save original terminal settings
        handler.original_termios = try std.posix.tcgetattr(stdin.handle);
        
        // Set raw mode
        var raw = handler.original_termios;
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.ISIG = false;
        raw.lflag.IEXTEN = false;
        raw.iflag.IXON = false;
        raw.iflag.ICRNL = false;
        raw.iflag.BRKINT = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.oflag.OPOST = false;
        raw.cflag.CSIZE = .CS8;
        raw.cc[@intFromEnum(std.posix.V.MIN)] = 1;
        raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;
        
        try std.posix.tcsetattr(stdin.handle, .FLUSH, raw);
        
        return handler;
    }
    
    pub fn deinit(self: *InputHandler) void {
        // Restore original terminal settings
        std.posix.tcsetattr(self.stdin.handle, .FLUSH, self.original_termios) catch {};
    }
    
    pub fn readEvent(self: *InputHandler) !InputEvent {
        var buf: [8]u8 = undefined;
        const n = try self.stdin.read(&buf);
        
        if (n == 0) return InputEvent{ .key = .unknown };
        
        // Check for escape sequences
        if (buf[0] == 27) { // ESC
            if (n == 1) return InputEvent{ .key = .escape };
            
            if (n >= 3 and buf[1] == '[') {
                return switch (buf[2]) {
                    'A' => InputEvent{ .key = .up },
                    'B' => InputEvent{ .key = .down },
                    'C' => InputEvent{ .key = .right },
                    'D' => InputEvent{ .key = .left },
                    'H' => InputEvent{ .key = .home },
                    'F' => InputEvent{ .key = .end },
                    '5' => if (n >= 4 and buf[3] == '~') InputEvent{ .key = .page_up } else InputEvent{ .key = .unknown },
                    '6' => if (n >= 4 and buf[3] == '~') InputEvent{ .key = .page_down } else InputEvent{ .key = .unknown },
                    '3' => if (n >= 4 and buf[3] == '~') InputEvent{ .key = .delete } else InputEvent{ .key = .unknown },
                    else => InputEvent{ .key = .unknown },
                };
            }
            
            return InputEvent{ .key = .unknown };
        }
        
        // Check for control characters
        return switch (buf[0]) {
            3 => InputEvent{ .key = .ctrl_c },   // Ctrl-C
            17 => InputEvent{ .key = .ctrl_q },  // Ctrl-Q
            18 => InputEvent{ .key = .ctrl_r },  // Ctrl-R
            8 => InputEvent{ .key = .ctrl_h },   // Ctrl-H
            16 => InputEvent{ .key = .ctrl_p },  // Ctrl-P
            '\r', '\n' => InputEvent{ .key = .enter },
            '\t' => InputEvent{ .key = .tab },
            127 => InputEvent{ .key = .backspace },
            32...126 => InputEvent{ .key = .char, .char = buf[0] },
            else => InputEvent{ .key = .unknown },
        };
    }
};
