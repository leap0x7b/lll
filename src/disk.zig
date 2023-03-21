const std = @import("std");
const root = @import("root");
const real = @import("real.zig");

pub const Dap = packed struct {
    size: u16,
    count: u16,
    offset: u16,
    segment: u16,
    lba: u64,
};

pub const DriveParameters = packed struct {
    buffer_size: u16,
    info_flags: u16,
    cylinders: u32,
    heads: u32,
    sectors: u32,
    lba_count: u64,
    bytes_per_sector: u16,
    edd: u32,
};

pub fn getSectorSize(drive: usize) usize {
    var drive_params: DriveParameters = undefined;
    drive_params.buffer_size = @sizeOf(DriveParameters);

    const regs = real.int(0x13, .{
        .eax = 0x4800,
        .edx = drive,
        .ds = real.segment(@ptrToInt(&drive_params)),
        .esi = real.offset(@ptrToInt(&drive_params)),
    });

    if ((regs.eflags & real.EFLAGS_CF) == 1) {
        const ah = (regs.eax >> 8) & 0xff;
        root.panicHex(ah);
    }

    return drive_params.bytes_per_sector;
}

pub fn read(drive: usize, sector_count: u64, sector_offset: u64, buffer: []u8) [*]u8 {
    var dap_buffer = [1]u8{0} ** 0x200;
    const sector_size = getSectorSize(drive);

    var sectors_left = sector_count;
    while (sectors_left > 0) {
        const buffer_sectors = @divExact(buffer.len, sector_size);
        const sectors_to_read = @intCast(u16, @min(sectors_left, buffer_sectors));
        defer sectors_left -= sectors_to_read;

        const lba_offset = sector_count - sectors_left;
        const lba = sector_offset + lba_offset;

        const dap = Dap{
            .size = 0x10,
            .count = sectors_to_read,
            .offset = @intCast(u16, @ptrToInt(&dap_buffer)),
            .segment = 0,
            .lba = lba,
        };

        const regs = real.int(0x13, .{
            .eax = 0x4200,
            .edx = drive,
            .esi = real.offset(@ptrToInt(&dap)),
            .ds = real.segment(@ptrToInt(&dap)),
        });

        if ((regs.eflags & real.EFLAGS_CF) == 1) {
            const ah = (regs.eax >> 8) & 0xff;
            root.panicHex(ah);
        }

        const buffer_offset = lba_offset * sector_size;
        const bytes_to_copy = sectors_to_read * sector_size;
        const dst_slice = buffer[@intCast(usize, buffer_offset)..];
        const src_slice = buffer[0..bytes_to_copy];
        std.mem.copy(u8, dst_slice, src_slice);
    }

    return buffer.ptr;
}

pub inline fn getProvidedBuffer(comptime T: type, count: usize, allocator: *std.mem.Allocator) ![]u8 {
    const result = try allocator.alloc(T, count);
    const slice = @ptrCast([*]u8, result)[0..result.len];
    return slice;
}

pub fn readTypedSectors(drive: usize, comptime T: type, sector_offset: u64, allocator: *std.mem.Allocator) !*T {
    const sector_count = @divExact(@sizeOf(T), getSectorSize(drive));
    const provided_buffer = try getProvidedBuffer(T, 1, allocator);
    const result = read(drive, sector_count, sector_offset, provided_buffer);

    return @ptrCast(*T, @alignCast(@alignOf(T), result));
}

pub fn readSlice(drive: usize, comptime T: type, len: usize, sector_offset: u64, allocator: *std.mem.Allocator) ![]T {
    const element_count_per_sector = @divExact(getSectorSize(drive), @sizeOf(T));
    const sector_count = @divExact(len, element_count_per_sector);
    const provided_buffer = try getProvidedBuffer(T, len, allocator);
    const result = read(drive, sector_count, sector_offset, provided_buffer);

    return @ptrCast([*]T, @alignCast(@alignOf(T), result))[0..len];
}
