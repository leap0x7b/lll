const std = @import("std");
const io = @import("io.zig");

pub fn putChar(char: u8) void {
    io.out(u8, 0xe9, char);
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
