const std = @import("std");
const real = @import("real.zig");
const log = std.log.scoped(.e820);

pub const MAX_ENTRIES = 256;

pub const Entry = packed struct {
    base: u64,
    length: u64,
    type: Type,
    _unused: u32,

    pub const Type = enum(u32) {
        Usable,
        Reserved,
        AcpiReclaimable,
        AcpiNvs,
        Corrupted,
    };
};

pub var entries: [MAX_ENTRIES]Entry = undefined;
pub var entry_count: usize = 0;

pub fn init() !void {
    log.debug("E820 memory map layout:", .{});
    var regs = real.Registers{};

    var i: usize = 0;
    while (i < MAX_ENTRIES) : (i += 1) {
        var entry: Entry = undefined;

        regs.eax = 0xe820;
        regs.ecx = 24;
        regs.edx = 0x534d4150;
        regs.edi = @ptrToInt(&entry);
        regs = real.int(0x15, regs);

        if ((regs.eflags & real.EFLAGS_CF) == 1) {
            entry_count = i;
            return;
        }

        log.debug("  base=0x{x:0>16}, length=0x{x:0>16}, type={s}", .{ entry.base, entry.length, @tagName(entry.type) });
        entries[i] = entry;

        if (regs.ebx == 0) {
            entry_count = i + 1;
            return;
        }
    }

    return error.TooManyEntries;
}
