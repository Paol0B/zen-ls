# ZEN-LS: Zero-overhead Enhanced Navigator for Linux Systems

![Version](https://img.shields.io/badge/version-0.1.0--alpha-blue)
![Zig](https://img.shields.io/badge/zig-0.15.2-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**ZEN-LS** is a high-performance directory listing tool written in Zig that combines blazing speed with rich visual features. It's **2.3x faster than GNU ls** in ultra-fast mode while offering modern enhancements when you need them.

## ✨ Why ZEN-LS?

- ⚡ **2.3x faster than GNU ls** with `--fast` mode (106ms vs 246ms on 350K files)
- 🎨 **Rich visual themes** - 6 color schemes, Nerd Fonts icons (90+ file types)
- 🖥️ **Interactive TUI** - Full-screen interface with file preview
- 🔧 **POSIX compatible** - Drop-in replacement for standard `ls`
- 🦀 **Pure Zig** - No dependencies, cross-platform, memory-safe

## 🚀 Key Features

### ⚡ Performance Modes

**Ultra-Fast Mode** (`--fast`)
- Direct `getdents64()` syscalls
- Zero heap allocations
- Single buffered write
- **106ms** to scan 350K files (vs GNU ls 246ms)

**Normal Mode** (default)
- Full POSIX compatibility
- Sorting and formatting
- **355ms** for 350K files with all features

### 🎨 Visual Enhancements

**File Type Icons** (`--icons`)
- 90+ file types recognized
- Nerd Fonts, Unicode, ASCII fallback
- Language-aware (Zig, Rust, Python, JS, etc.)

**Color Themes**
- `--neon` - Vibrant neon colors
- `--matrix` - Green matrix style
- `--cyberpunk` - Pink/cyan aesthetic
- `--pastel` - Soft pastels
- `--monochrome` - Clean B&W
- Standard LS_COLORS compatible

**Tree View** (`--tree`)
- Clean ASCII box drawing
- Proper indentation
- Directory hierarchy visualization

### 🖥️ Interactive TUI (`--interactive`)

Full-screen terminal interface with:
- **Split-pane layout** - File list + preview
- **Keyboard navigation** - Arrow keys + Vim (hjkl)
- **File preview** - Text files, directories, permissions
- **Live filtering** - Real-time search
- **Status bar** - Selection info, help text

### 🔧 POSIX Compatibility

Full standard `ls` support:
```bash
-a, --all              # Show hidden files
-A, --almost-all       # Show all except . and ..
-l                     # Long listing format
-h, --human-readable   # Human readable sizes (1K, 234M, 2G)
-r, --reverse          # Reverse sort order
-R, --recursive        # List subdirectories recursively
-S                     # Sort by size, largest first
-t                     # Sort by time, newest first
-1                     # List one file per line
-F, --classify         # Append indicator (*/=>@|) to entries
-d, --directory        # List directories themselves
--group-directories-first  # List directories before files
--color[=WHEN]         # Colorize output (always/auto/never)
```

## 📦 Installation

### Prerequisites
- Zig 0.15.2 or later
- Linux (other platforms: experimental)

### Build from Source

```bash
git clone https://github.com/Paol0B/zen-ls.git
cd zen-ls
zig build -Doptimize=ReleaseFast
sudo cp zig-out/bin/zen-ls /usr/local/bin/
```

## 🎯 Usage Examples

### Speed Modes
```bash
# Ultra-fast: Just file names, maximum speed
zen-ls --fast -R /usr              # 106ms for 350K files

# Normal: Full features, still fast  
zen-ls -lh /usr/bin                # Sorted, colored, human-readable

# Visual: Icons and themes
zen-ls --icons --neon src/         # Beautiful output
```

### Interactive Mode
```bash
# Launch TUI with file preview
zen-ls --interactive /path/to/dir

# Controls:
#   ↑↓ or hjkl    Navigate
#   Enter         Select
#   Tab           Toggle preview
#   q             Quit
```

### Tree View
```bash
# ASCII tree with proper indentation
zen-ls --tree src/

# With icons and colors
zen-ls --tree --icons --cyberpunk
```

### POSIX Compatibility
```bash
# Works like standard ls
zen-ls -lha /etc                   # Long, hidden, all
zen-ls -Rt /var/log               # Recursive, time-sorted
zen-ls -Sh ~/Downloads            # Size-sorted, human-readable
```

## 🏗️ Architecture

**Modular Design:**
- **Core** - Filesystem scanning, file metadata, optimized traversal
- **Renderer** - Output formatting, colors, themes, icons
- **UI** - Interactive TUI with split-pane and preview
- **Args** - Comprehensive CLI parser with POSIX compatibility

**Performance Critical Paths:**
- Ultra-fast scanner: Direct `getdents64()` syscalls
- Zero-copy buffer management
- Stack-allocated hot paths
- Single-write output buffering

See [PERFORMANCE.md](PERFORMANCE.md) for detailed technical analysis.
- Built with the amazing Zig programming language
- Nerd Fonts for beautiful icons

## 📊 Performance Benchmarks

**Test:** `/usr` directory with 350,980 files (recursive scan)

| Mode | Time | vs GNU ls | Features |
|------|------|-----------|----------|
| **zen-ls --fast** | **106ms** | **2.3x faster** ⚡ | Raw speed, no metadata |
| GNU ls | 246ms | baseline | Standard features |
| zen-ls (normal) | 355ms | 0.7x | Full metadata, sorting |
| zen-ls --icons | 424ms | 0.6x | + icons, colors, themes |

### Ultra-Fast Mode (`--fast`)
- Direct `getdents64()` syscalls (32KB chunks)
- Zero heap allocations in hot path
- Single buffered write (~61K syscalls vs 400K+)
- Skips: stat calls, sorting, formatting
- **Use case:** Pipe to grep/awk, file counting, quick scans

### Normal Mode (default)
- Full POSIX compatibility with sorting
- Rich metadata (sizes, times, permissions)
- Color themes and file type detection
- **Use case:** Daily terminal usage, visual browsing

### Feature-Rich Mode (`--icons`, `--tree`, `--interactive`)
- Nerd Fonts icons (90+ file types)
- Tree visualization with box drawing
- Interactive TUI with preview pane
- **Use case:** Exploration, presentations, demos

## 🔧 Technical Details

**Built with:**
- Zig 0.15.2 (memory-safe systems language)
- Direct Linux syscalls (no libc for hot paths)
- LLVM optimizations (ReleaseFast)

**Key optimizations:**
- Lazy stat evaluation (only when needed)
- Stack buffers (4KB path, 32KB I/O)
- Arena allocator for batch operations
- Vectorized string operations

**Memory usage:**
- Ultra-fast: ~7MB for 350K files
- Normal: ~15MB for 350K files
- Interactive: +2MB for TUI buffers

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

## 🙏 Acknowledgments

- Inspired by **exa** and **lsd** - modern ls alternatives
- **Nerd Fonts** - Beautiful file icons
- **Zig language** - Systems programming made elegant

---

**ZEN-LS**: *When speed meets beauty in the terminal* ⚡✨
