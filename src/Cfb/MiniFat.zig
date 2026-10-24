//! Array-style access to the MiniFat.
const MiniFat = @This();

const std = @import("std");

const Cfb = @import("../Cfb.zig");
const Fat = @import("Fat.zig");
const SectorNumber = @import("SectorNumber.zig").SectorNumber;
const Source = @import("../source.zig").Source;

cfb: *const Cfb,
fat: Fat,
cursor: u32 = 0,
sector: SectorNumber,

pub fn init(cfb: *const Cfb) MiniFat {
    return .{ .cfb = cfb, .fat = .init(cfb), .sector = cfb.firstMiniFat() };
}

/// Returns MiniFAT[n], the next mini sector number in the chain after mini sector #n.
pub fn nextSectorInChain(self: *MiniFat, n: SectorNumber) Cfb.ReadError!SectorNumber {
    if (!n.isRegular()) return error.InvalidSector;

    const next_cursor = @backingInt(n) / self.miniFatPerSector();

    if (next_cursor < self.cursor) {
        self.cursor = 0;
        self.sector = self.cfb.firstMiniFat();
    }

    while (self.cursor < next_cursor) : (self.cursor += 1) {
        self.sector = try self.fat.nextSectorInChain(self.sector);
    }

    return .fromInt(try self.cfb.readValue(u32, self.sector, @backingInt(n) % self.miniFatPerSector()));
}

fn miniFatPerSector(self: *const MiniFat) u32 {
    return self.cfb.bytesPerSector() / @sizeOf(u32);
}

const testing = std.testing;

test nextSectorInChain {
    const expected = [_][2]u32{
        .{ 0, 1 },
        .{ 1, 2 },
        .{ 7, 8 },
        .{ 8, 0xfffffffe },
        .{ 9, 0xffffffff },
        .{ 127, 0xffffffff },

        // Backwards
        .{ 3, 4 },
    };
    var src: Source = try .fromPath(testing.io, "samples/01-ms-cfb/ms-cfb.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src);
    var mini_fat: MiniFat = .init(&cfb);

    for (expected) |e| {
        const actual = @backingInt(try mini_fat.nextSectorInChain(.fromInt(e[0])));
        if (actual != e[1]) {
            std.debug.print("MiniFAT[{d}]: expected 0x{x}, found 0x{x}\n", .{ e[0], e[1], actual });
            return error.TestExpectedEqual;
        }
    }

    try testing.expectError(error.InvalidSector, mini_fat.nextSectorInChain(.endofchain));
    try testing.expectError(error.InvalidSector, mini_fat.nextSectorInChain(.fromInt(128)));
}

test "nextSectorInChain minifat v3" {
    const expected = [_][2]u32{
        // First MiniFAT sector
        .{ 0, 0x18 },
        .{ 16, 0x29 },
        .{ 127, 0x92 },

        // Second MiniFAT sector
        .{ 128, 0x93 },
        .{ 255, 0x104 },

        // Third MiniFAT sector, free
        .{ 256, 0x10a },
        .{ 340, 0xffffffff },
        .{ 383, 0x188 },

        // Backwards
        .{ 142, 0x10 },

        // Fourth MiniFAT sector
        .{ 384, 0x189 },
        .{ 420, 0xffffffff },
        .{ 511, 0x206 },

        // Last MiniFAT sector, end of chain and past the last mini sector
        .{ 512, 0x207 },
        .{ 565, 0xfffffffe },
        .{ 569, 0xfffffffe },
        .{ 570, 0xffffffff },
        .{ 639, 0xffffffff },
    };
    var src: Source = try .fromPath(testing.io, "samples/03-minifat-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src);
    var mini_fat: MiniFat = .init(&cfb);

    for (expected) |e| {
        const actual = @backingInt(try mini_fat.nextSectorInChain(.fromInt(e[0])));
        if (actual != e[1]) {
            std.debug.print("MiniFAT[{d}]: expected 0x{x}, found 0x{x}\n", .{ e[0], e[1], actual });
            return error.TestExpectedEqual;
        }
    }

    try testing.expectError(error.InvalidSector, mini_fat.nextSectorInChain(.fromInt(640)));
}
