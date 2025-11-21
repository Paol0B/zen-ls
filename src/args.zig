const std = @import("std");

pub const IconSet = enum {
    none,
    nerd_fonts,
    unicode,
    ascii,
};

pub const Theme = enum {
    standard,
    neon,
    matrix,
    cyberpunk,
    pastel,
    monochrome,
};

/// Configuration structure containing all parsed command-line options
pub const Config = struct {
    // Paths to list
    paths: std.ArrayList([]const u8),
    
    // POSIX standard options
    show_hidden: bool = false,
    show_almost_all: bool = false,
    long_format: bool = false,
    human_readable: bool = false,
    reverse_sort: bool = false,
    recursive: bool = false,
    sort_by_size: bool = false,
    sort_by_time: bool = false,
    one_per_line: bool = false,
    color_mode: ColorMode = .auto,
    classify: bool = false,
    directory_only: bool = false,
    group_directories_first: bool = false,
    show_inode: bool = false,
    numeric_ids: bool = false,
    dereference: bool = false,
    
    // ZEN-LS advanced options
    interactive_mode: bool = false,
    show_preview: bool = false,
    git_integration: bool = false,
    show_icons: bool = false,
    icon_set: IconSet = .nerd_fonts,
    tree_view: bool = false,
    show_stats: bool = false,
    
    // Visual enhancements
    theme: Theme = .standard,
    neon_mode: bool = false,
    matrix_mode: bool = false,
    cyberpunk_mode: bool = false,
    galaxy_mode: bool = false,
    
    // Performance
    turbo_mode: bool = false,
    cache_strategy: CacheStrategy = .balanced,
    
    // Developer features
    show_metrics: bool = false,
    show_deps: bool = false,
    show_build_status: bool = false,
    
    // Analysis & Security
    deep_scan: bool = false,
    security_audit: bool = false,
    find_duplicates: bool = false,
    
    // Internal flags
    show_help: bool = false,
    show_version: bool = false,
    
    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        self.paths.deinit(allocator);
    }
};

pub const ColorMode = enum {
    always,
    auto,
    never,
};

pub const CacheStrategy = enum {
    aggressive,
    balanced,
    minimal,
};

pub fn parseArgs(allocator: std.mem.Allocator) !Config {
    var config = Config{
        .paths = std.ArrayList([]const u8){},
    };
    
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    
    // Skip program name
    _ = args_iter.skip();
    
    while (args_iter.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            try parseLongOption(&config, arg);
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
            try parseShortOptions(&config, arg[1..]);
        } else {
            // It's a path
            try config.paths.append(allocator, arg);
        }
    }
    
    // Default to current directory if no paths specified
    if (config.paths.items.len == 0) {
        try config.paths.append(allocator, ".");
    }
    
    return config;
}

fn parseLongOption(config: *Config, arg: []const u8) !void {
    const option = arg[2..]; // Skip "--"
    
    if (std.mem.eql(u8, option, "help")) {
        config.show_help = true;
    } else if (std.mem.eql(u8, option, "version")) {
        config.show_version = true;
    } else if (std.mem.eql(u8, option, "all")) {
        config.show_hidden = true;
    } else if (std.mem.eql(u8, option, "almost-all")) {
        config.show_almost_all = true;
    } else if (std.mem.eql(u8, option, "human-readable")) {
        config.human_readable = true;
    } else if (std.mem.eql(u8, option, "reverse")) {
        config.reverse_sort = true;
    } else if (std.mem.eql(u8, option, "recursive")) {
        config.recursive = true;
    } else if (std.mem.eql(u8, option, "classify")) {
        config.classify = true;
    } else if (std.mem.eql(u8, option, "directory")) {
        config.directory_only = true;
    } else if (std.mem.eql(u8, option, "group-directories-first")) {
        config.group_directories_first = true;
    } else if (std.mem.startsWith(u8, option, "color")) {
        if (std.mem.indexOf(u8, option, "=")) |eq_pos| {
            const value = option[eq_pos + 1 ..];
            if (std.mem.eql(u8, value, "always")) {
                config.color_mode = .always;
            } else if (std.mem.eql(u8, value, "auto")) {
                config.color_mode = .auto;
            } else if (std.mem.eql(u8, value, "never")) {
                config.color_mode = .never;
            }
        } else {
            config.color_mode = .always;
        }
    } else if (std.mem.eql(u8, option, "interactive")) {
        config.interactive_mode = true;
    } else if (std.mem.eql(u8, option, "preview")) {
        config.show_preview = true;
    } else if (std.mem.eql(u8, option, "git")) {
        config.git_integration = true;
    } else if (std.mem.eql(u8, option, "icons")) {
        config.show_icons = true;
    } else if (std.mem.eql(u8, option, "tree")) {
        config.tree_view = true;
    } else if (std.mem.eql(u8, option, "stats")) {
        config.show_stats = true;
    } else if (std.mem.eql(u8, option, "neon")) {
        config.neon_mode = true;
        config.theme = .neon;
    } else if (std.mem.eql(u8, option, "matrix")) {
        config.matrix_mode = true;
        config.theme = .matrix;
    } else if (std.mem.eql(u8, option, "cyberpunk")) {
        config.cyberpunk_mode = true;
        config.theme = .cyberpunk;
    } else if (std.mem.eql(u8, option, "pastel")) {
        config.theme = .pastel;
    } else if (std.mem.eql(u8, option, "monochrome")) {
        config.theme = .monochrome;
    } else if (std.mem.eql(u8, option, "galaxy")) {
        config.galaxy_mode = true;
    } else if (std.mem.eql(u8, option, "turbo")) {
        config.turbo_mode = true;
    } else if (std.mem.startsWith(u8, option, "cache-strategy=")) {
        const value = option["cache-strategy=".len..];
        if (std.mem.eql(u8, value, "aggressive")) {
            config.cache_strategy = .aggressive;
        } else if (std.mem.eql(u8, value, "balanced")) {
            config.cache_strategy = .balanced;
        } else if (std.mem.eql(u8, value, "minimal")) {
            config.cache_strategy = .minimal;
        }
    } else if (std.mem.eql(u8, option, "metrics")) {
        config.show_metrics = true;
    } else if (std.mem.eql(u8, option, "deps")) {
        config.show_deps = true;
    } else if (std.mem.eql(u8, option, "build-status")) {
        config.show_build_status = true;
    } else if (std.mem.eql(u8, option, "deep-scan")) {
        config.deep_scan = true;
    } else if (std.mem.eql(u8, option, "security-audit")) {
        config.security_audit = true;
    } else if (std.mem.eql(u8, option, "dupes")) {
        config.find_duplicates = true;
    }
    // Add more long options as needed
}

fn parseShortOptions(config: *Config, options: []const u8) !void {
    for (options) |opt| {
        switch (opt) {
            'a' => config.show_hidden = true,
            'A' => config.show_almost_all = true,
            'l' => config.long_format = true,
            'h' => config.human_readable = true,
            'r' => config.reverse_sort = true,
            'R' => config.recursive = true,
            'S' => config.sort_by_size = true,
            't' => config.sort_by_time = true,
            '1' => config.one_per_line = true,
            'F' => config.classify = true,
            'd' => config.directory_only = true,
            'i' => config.show_inode = true,
            'n' => config.numeric_ids = true,
            'L' => config.dereference = true,
            else => {}, // Unknown option, skip for now
        }
    }
}

test "parse basic args" {
    // Test would require mocking std.process.args
    // Placeholder for now
}
