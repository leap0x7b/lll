const std = @import("std");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    std.log.err("Panic: {s}", .{message});
    dumpStackTrace(return_address orelse @returnAddress(), @frameAddress());
    std.log.err("System halted.", .{});

    while (true)
        asm volatile ("hlt");

    unreachable;
}

fn dumpStackTrace(start_address: usize, frame_pointer: usize) void {
    var stack_iterator = std.debug.StackIterator.init(start_address, frame_pointer);
    std.log.err("Stack trace:", .{});

    while (stack_iterator.next()) |return_address| {
        if (return_address != 0)
            std.log.err("  - 0x{x}", .{return_address});
    }
}
