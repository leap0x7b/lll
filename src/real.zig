pub inline fn segment(x: u32) u16 {
    return @intCast(u16, (x & 0xffff0) >> 4);
}

pub inline fn offset(x: u32) u16 {
    return @intCast(u16, (x & 0x0f));
}

pub inline fn desegment(seg: u16, off: u16) u32 {
    return (seg << 4) + off;
}

pub const EFLAGS_CF: u32 = 1 << 0;
pub const EFLAGS_ZF: u32 = 1 << 6;

pub const Registers = extern struct {
    gs: u16 = 0,
    fs: u16 = 0,
    es: u16 = 0,
    ds: u16 = 0,
    eflags: u32 = 0,
    ebp: u32 = 0,
    edi: u32 = 0,
    esi: u32 = 0,
    edx: u32 = 0,
    ecx: u32 = 0,
    ebx: u32 = 0,
    eax: u32 = 0,
};

extern fn real_int(int_num: u8, out_regs: *Registers, in_regs: *Registers) void;

pub fn int(int_num: u8, registers: Registers) Registers {
    var ret = registers;
    real_int(int_num, &ret, &ret);
    return ret;
}
