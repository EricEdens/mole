//! Array-style access to the Difat.
const Difat = @This();

const std = @import("std");

const Cfb = @import("../cfb.zig").Cfb;
const SectorNumber = @import("SectorNumber.zig").SectorNumber;

cfb: *const Cfb,

// Cursor and sector memoize one position in the DIFAT chain. If you
// only read in ascending order, then you avoid the typical n-squared hit
// that comes from each restart.
//
// If you read in random patterns, I don't know. We'll have to measure it.
cursor: u32 = 0,
sector: SectorNumber,

pub fn init(cfb: *const Cfb) Difat {
    return .{ .cfb = cfb, .sector = cfb.firstDifat() };
}

/// Returns DIFAT[n], the sector number of FAT sector #n.
pub fn fatSectorLocation(self: *Difat, n: u32) Cfb.ReadError!SectorNumber {
    if (self.hdrDifat(n)) |s| return s;

    const idx: u32 = n - self.hdrLen();
    const next_cursor = idx / self.difatPerSector();

    if (next_cursor < self.cursor) {
        self.cursor = 0;
        self.sector = self.cfb.firstDifat();
    }

    while (self.cursor < next_cursor) : (self.cursor += 1) {
        self.sector = .fromInt(
            try self.cfb.readValue(u32, self.sector, self.difatPerSector()),
        );
    }

    return .fromInt(try self.cfb.readValue(u32, self.sector, idx % self.difatPerSector()));
}

fn hdrLen(self: *const Difat) u32 {
    return @intCast(self.cfb.header.difat.len);
}

fn hdrDifat(self: *const Difat, n: u32) ?SectorNumber {
    return if (n < self.hdrLen()) SectorNumber.fromInt(self.cfb.header.difat[n]) else null;
}

fn difatPerSector(self: *const Difat) u32 {
    return (self.cfb.bytesPerSector() / @sizeOf(u32)) - 1;
}

const ByteSource = @import("../io.zig").ByteSource;
const testing = std.testing;

test fatSectorLocation {
    const expected = [_][2]u32{
        // Header
        .{ 0, 0x0000 },
        .{ 1, 0x007a },
        .{ 108, 0x35fd },

        // First DIFAT sector
        .{ 109, 0x367e },
        .{ 110, 0x3700 },
        .{ 235, 0x757d },

        // Second DIFAT sector
        .{ 236, 0x75fe },

        // Backwards
        .{ 120, 0x3bfa },
        .{ 5, 0x027e },

        // Forwards
        .{ 237, 0x7680 },
        .{ 300, 0x95ff },
        .{ 322, 0xa0fd },
        .{ 323, 0xffffffff },

        // Header to second DIFAT sector
        .{ 108, 0x35fd },
        .{ 236, 0x75fe },
    };
    var src: ByteSource.Memory = try .fromPath(testing.io, "samples/02-big-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src.byteSource());
    var difat: Difat = .init(&cfb);

    for (expected) |e| {
        const actual = @backingInt(try difat.fatSectorLocation(e[0]));
        if (actual != e[1]) {
            std.debug.print("DIFAT[{d}]: expected 0x{x}, found 0x{x}\n", .{ e[0], e[1], actual });
            return error.TestExpectedEqual;
        }
    }
}
