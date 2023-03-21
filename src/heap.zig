const std = @import("std");

var buffer: [0x8000]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
pub var allocator = fba.allocator();
