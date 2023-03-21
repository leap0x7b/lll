const std = @import("std");
const io = @import("io.zig");

const VGA_COLUMNS = 80;
const VGA_ROWS = 25;
const VGA_SIZE = VGA_COLUMNS * VGA_ROWS;

pub const Color = enum(u8) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGray = 7,
    DarkGray = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    LightBrown = 14,
    White = 15,
};

var row: usize = 0;
var column: usize = 0;
var color = vgaEntryColor(.LightGray, .Black);
var buffer = @intToPtr([*]volatile u16, 0xb8000);

inline fn vgaEntryColor(fg: ?Color, bg: ?Color) u8 {
    return @enumToInt(fg orelse Color.LightGray) | (@enumToInt(bg orelse Color.Black) << 4);
}

inline fn vgaEntry(char: u8, new_color: u8) u16 {
    return char | (@intCast(u16, new_color) << 8);
}

pub fn init() void {
    row = getCursorPosition() / VGA_COLUMNS;
    column = getCursorPosition() % VGA_COLUMNS;
}

pub fn enableCursor() void {
    io.out(u8, 0x3d4, 0x0a);
    io.out(u8, 0x3d5, (io.in(u8, 0x3d5) & 0xc0) | 13);

    io.out(u8, 0x3d4, 0x0b);
    io.out(u8, 0x3d5, (io.in(u8, 0x3d5) & 0xe0) | 15);
}

pub fn disableCursor() void {
    io.out(u8, 0x3d4, 0x0a);
    io.out(u8, 0x3d5, 0x20);
}

pub fn setCursorPosition(x: usize, y: usize) void {
    const pos = y * VGA_COLUMNS + x;

    io.out(u8, 0x3d4, 0x0f);
    io.out(u8, 0x3d5, @truncate(u8, pos) & 0xff);

    io.out(u8, 0x3d4, 0x0e);
    io.out(u8, 0x3d5, @truncate(u8, pos >> 8) & 0xff);
}

pub fn getCursorPosition() u16 {
    var pos: u16 = 0;

    io.out(u8, 0x3d4, 0x0f);
    pos |= io.in(u8, 0x3D5);

    io.out(u8, 0x3d4, 0x0e);
    pos |= @intCast(u16, io.in(u8, 0x3d5)) << 8;

    return pos;
}

pub fn setColor(fg: ?Color, bg: ?Color) void {
    color = vgaEntryColor(fg, bg);
}

pub fn clear() void {
    std.mem.set(u16, buffer[0..VGA_SIZE], vgaEntry(' ', color));
}

fn scroll() void {
    var x: usize = 0;
    var y: usize = 0;

    while (y < VGA_ROWS - 1) : (y += 1) {
        while (x < VGA_COLUMNS) : (x += 1) {
            buffer[y * VGA_COLUMNS + x] = buffer[(y + 1) * VGA_COLUMNS + x];
        }
    }

    while (x < VGA_COLUMNS) : (x += 1) {
        buffer[y * VGA_COLUMNS + x] = vgaEntry(' ', color);
    }

    column = 0;
    row = VGA_ROWS - 1;
}

pub fn putCharAt(char: u8, new_color: u8, x: usize, y: usize) void {
    const offset: usize = y * VGA_COLUMNS + x;
    buffer[offset] = vgaEntry(char, new_color);
}

pub fn putChar(char: u8) void {
    switch (char) {
        '\r' => column = 0,
        '\n' => {
            column = 0;
            row += 1;
        },
        '\t' => column += 8,
        else => putCharAt(char, color, column, row),
    }

    if (char != '\n') {
        defer column += 1;
        if (column == VGA_COLUMNS) {
            column = 0;
            defer row += 1;
            if (row == VGA_ROWS) {
                scroll();
            }
        }
    } else {
        if (row == VGA_ROWS) {
            scroll();
        }
    }

    setCursorPosition(column, row);
}

pub fn write(string: []const u8) void {
    for (string) |c| putChar(c);
}

pub const writer = std.io.Writer(void, error{}, callback){
    .context = {},
};

fn callback(_: void, string: []const u8) error{}!usize {
    write(string);
    return string.len;
}

pub fn print(comptime format: []const u8, args: anytype) !void {
    try std.fmt.format(writer, format, args);
}
