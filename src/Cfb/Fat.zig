//! Array-style access to the Fat.
const Fat = @This();

const std = @import("std");

const Cfb = @import("../Cfb.zig");
const Difat = @import("Difat.zig");
const SectorNumber = @import("SectorNumber.zig").SectorNumber;
const Source = @import("../source.zig").Source;

cfb: *const Cfb,
difat: Difat,
cursor: u32 = 0,
sector: SectorNumber,

pub fn init(cfb: *const Cfb) Fat {
    return .{ .cfb = cfb, .difat = .init(cfb), .sector = .fromInt(cfb.header.difat[0]) };
}

/// Returns FAT[n], the next sector number in the chain after sector #n.
pub fn nextSectorInChain(self: *Fat, n: SectorNumber) Cfb.ReadError!SectorNumber {
    if (!n.isRegular()) return error.InvalidSector;

    const next_cursor = @backingInt(n) / self.fatPerSector();

    if (next_cursor != self.cursor) {
        self.sector = try self.difat.fatSectorLocation(next_cursor);
        self.cursor = next_cursor;
    }

    return .fromInt(try self.cfb.readInt(u32, self.sector, @backingInt(n) % self.fatPerSector()));
}

fn fatPerSector(self: *const Fat) u32 {
    return (self.cfb.bytesPerSector() / @sizeOf(u32));
}

const testing = std.testing;

test nextSectorInChain {
    const expected = [_][2]u32{
        // First FAT sector
        .{ 0x0000, 0xfffffffd },
        .{ 0x0001, 0x60d4 },
        .{ 0x0002, 0x0003 },
        .{ 0x007a, 0xfffffffd },
        .{ 0x007f, 0x0080 },

        // Second FAT sector
        .{ 0x0080, 0x0081 },

        // Last FAT sector in header
        .{ 0x3605, 0x3616 },
        .{ 0x367e, 0xfffffffd },
        .{ 0x367f, 0xfffffffc },

        // First FAT sector in first DIFAT sector
        .{ 0x3680, 0x3681 },
        .{ 0x3687, 0x3698 },

        // End of chain and free
        .{ 0x60d4, 0xfffffffe },
        .{ 0x60d7, 0xffffffff },

        // First FAT sector in second DIFAT sector
        .{ 0x75fe, 0xfffffffd },
        .{ 0x75ff, 0xfffffffc },
        .{ 0x7600, 0xffffffff },
        .{ 0x760f, 0x7620 },

        // Backwards
        .{ 0x0001, 0x60d4 },

        // Last FAT sector
        .{ 0xa10d, 0xa116 },
        .{ 0xa13c, 0xa13d },
        .{ 0xa13d, 0x48a4 },
    };
    var src: Source = try .fromPath(testing.io, "samples/02-big-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src);
    var fat: Fat = .init(&cfb);

    for (expected) |e| {
        const actual = @backingInt(try fat.nextSectorInChain(.fromInt(e[0])));
        if (actual != e[1]) {
            std.debug.print("FAT[0x{x}]: expected 0x{x}, found 0x{x}\n", .{ e[0], e[1], actual });
            return error.TestExpectedEqual;
        }
    }
}
