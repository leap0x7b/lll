const std = @import("std");
const builtin = @import("builtin");
const e9 = @import("e9.zig");
const a20 = @import("a20.zig");
const console = @import("console.zig");
const e820 = @import("e820.zig");
const real = @import("real.zig");
const heap = @import("heap.zig");
const disk = @import("disk.zig");
pub const panic = if (@import("build_options").panic_fn)
    @import("panic.zig").panic
else
    dummyPanic;

pub const std_options = struct {
    pub fn logFn(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
        const scope_prefix = if (scope == .default) "main" else @tagName(scope);
        const prefix = "\x1b[32m[lll:" ++ scope_prefix ++ "] " ++ switch (level) {
            .err => "\x1b[31merror",
            .warn => "\x1b[33mwarning",
            .info => "\x1b[36minfo",
            .debug => "\x1b[90mdebug",
        } ++ ": \x1b[0m";
        e9.print(prefix ++ format ++ "\n", args) catch unreachable;
    }
};

pub export fn main() void {
    a20.init() catch unreachable;
    std.log.info("Lazy Linux Loader version {s}", .{"0.1.0"});
    std.log.info("Compiled with Zig v{}", .{builtin.zig_version});
    std.log.info("All your {s} are belong to us", .{"codebase"});
    console.init();
    console.putChar('L');
    e820.init() catch unreachable;
    std.log.info("{any}", .{disk.readSlice(0x80, u8, 128, 0, &heap.allocator)});
    @panic("test");
    //while (true) asm volatile ("hlt");
}

pub fn panicHex(code: usize) noreturn {
    console.print("{x:0>4}", .{code}) catch unreachable;
    _ = real.int(0x16, .{});
    asm volatile ("ljmpw $0xffff, $0");
    console.write("\nHow did you get here?");
    unreachable;
}

fn dummyPanic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = real.int(0x16, .{});
    asm volatile ("ljmpw $0xffff, $0");
    console.write("\nHow did you get here?");
    unreachable;
}
