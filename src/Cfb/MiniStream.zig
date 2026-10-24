//! Array-style access to the mini stream.
const MiniStream = @This();

const std = @import("std");

const Cfb = @import("../Cfb.zig");
const Directory = @import("Directory.zig");
const Fat = @import("Fat.zig");
const MiniFat = @import("MiniFat.zig");
const SectorNumber = @import("SectorNumber.zig").SectorNumber;
const Source = @import("../source.zig").Source;

cfb: *const Cfb,
fat: Fat,
start: SectorNumber,
size: u64,
cursor: u32 = 0,
sector: SectorNumber,

/// root is Directory[0], whose start_sector and stream_size describe the mini stream.
pub fn init(cfb: *const Cfb, root: Directory.Entry) MiniStream {
    const start: SectorNumber = .fromInt(root.start_sector);
    return .{ .cfb = cfb, .fat = .init(cfb), .start = start, .size = root.stream_size, .sector = start };
}

/// Returns mini sector #n.
pub fn readMiniSector(self: *MiniStream, n: SectorNumber) Cfb.ReadError![64]u8 {
    if (!n.isRegular()) return error.InvalidSector;

    const offset = @as(u64, @backingInt(n)) * 64;
    if (offset + 64 > self.size) return error.EndOfStream;

    const next_cursor: u32 = @intCast(offset / self.cfb.bytesPerSector());

    if (next_cursor < self.cursor) {
        self.cursor = 0;
        self.sector = self.start;
    }

    while (self.cursor < next_cursor) : (self.cursor += 1) {
        self.sector = try self.fat.nextSectorInChain(self.sector);
    }

    return self.cfb.readValue([64]u8, self.sector, @intCast(offset % self.cfb.bytesPerSector() / 64));
}

const testing = std.testing;

test readMiniSector {
    var src: Source = try .fromPath(testing.io, "samples/01-ms-cfb/ms-cfb.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src);
    var dir: Directory = .init(&cfb);
    var ms: MiniStream = .init(&cfb, try dir.directoryEntry(.root));

    var expected: [9 * 64]u8 = @splat(0);
    for (expected[0..544], 0..) |*b, i| b.* = "Data for stream 1"[i % 17];

    for ([_]u32{ 0, 1, 7, 8, 3, 0, 8 }) |n|
        try testing.expectEqualSlices(u8, expected[n * 64 ..][0..64], &try ms.readMiniSector(.fromInt(n)));

    try testing.expectError(error.EndOfStream, ms.readMiniSector(.fromInt(9)));
    try testing.expectError(error.InvalidSector, ms.readMiniSector(.endofchain));
}

test "readMiniSector big v3" {
    var src: Source = try .fromPath(testing.io, "samples/02-big-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src);
    var dir: Directory = .init(&cfb);
    var ms: MiniStream = .init(&cfb, try dir.directoryEntry(.root));

    var expected: [100]u8 = undefined;
    for (&expected, 0..) |*b, i| b.* = @intCast((i + 4) % 251);

    try testing.expectEqualSlices(u8, expected[0..64], &try ms.readMiniSector(.fromInt(0)));
    try testing.expectEqualSlices(u8, expected[64..], (try ms.readMiniSector(.fromInt(1)))[0..36]);

    try testing.expectError(error.EndOfStream, ms.readMiniSector(.fromInt(2)));
}

test "readMiniSector minifat v3" {
    // id, seed
    const streams = [_][2]u32{
        // Interleaved with fifteen others
        .{ 17, 15 },
        // Reuses sectors freed by M1, M2, M4 and M11
        .{ 13, 201 },
        // Truncated from 8192 bytes
        .{ 4, 200 },
    };
    var src: Source = try .fromPath(testing.io, "samples/03-minifat-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src);
    var dir: Directory = .init(&cfb);
    var mini_fat: MiniFat = .init(&cfb);
    var ms: MiniStream = .init(&cfb, try dir.directoryEntry(.root));

    for (streams) |e| {
        const d = try dir.directoryEntry(@fromBackingInt(@intCast(e[0])));
        var n: SectorNumber = .fromInt(d.start_sector);
        var off: u64 = 0;
        while (off < d.stream_size) : (off += 64) {
            const buf = try ms.readMiniSector(n);
            for (buf[0..@min(64, d.stream_size - off)], off..) |b, i|
                try testing.expectEqual(@as(u8, @intCast((i + e[1]) % 251)), b);
            n = try mini_fat.nextSectorInChain(n);
        }
        try testing.expectEqual(SectorNumber.endofchain, n);
    }
}
