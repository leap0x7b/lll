const io = @import("io.zig");
const real = @import("real.zig");

inline fn mminw(address: u64) u16 {
    var ret: u16 = 0;
    asm volatile ("movw (%[addr]), %[ret]"
        : [ret] "=r" (ret),
        : [addr] "r" (address),
        : "memory"
    );
    return ret;
}

inline fn mmoutw(address: u64, value: u16) void {
    asm volatile ("movw %[val], (%[addr])"
        :
        : [addr] "r" (address),
          [val] "ir" (value),
        : "memory"
    );
}

pub fn check() bool {
    if (mminw(0x7dfe) != mminw(0x7dfe + 0x100000))
        return true;

    mmoutw(0x7dfe, ~mminw(0x7dfe));

    if (mminw(0x7dfe) != mminw(0x7dfe + 0x100000))
        return true;

    return false;
}

pub fn init() !void {
    if (check())
        return;

    // BIOS method
    _ = real.int(0x15, .{ .eax = 0x2401 });

    if (check())
        return;

    // Keyboard controller method
    while ((io.in(u8, 0x64) & 2) == 1) {}
    io.out(u8, 0x64, 0xad);
    while ((io.in(u8, 0x64) & 2) == 1) {}
    io.out(u8, 0x64, 0xd0);
    while ((io.in(u8, 0x64) & 1) != 1) {}
    const b = io.in(u8, 0x60);
    while ((io.in(u8, 0x64) & 2) == 1) {}
    io.out(u8, 0x64, 0xd1);
    while ((io.in(u8, 0x64) & 2) == 1) {}
    io.out(u8, 0x60, b | 2);
    while ((io.in(u8, 0x64) & 2) == 1) {}
    io.out(u8, 0x64, 0xae);
    while ((io.in(u8, 0x64) & 2) == 1) {}

    if (check())
        return;

    // Fast A20 gate (very dangerous, so it's best to put it last)
    io.out(u8, 0x92, 0x2);
    if (check())
        return;

    return error.NoA20;
}
