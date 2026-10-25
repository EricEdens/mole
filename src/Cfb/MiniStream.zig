//! Array-style access to the mini stream.
const MiniStream = @This();

const std = @import("std");

const Cfb = @import("../Cfb.zig");
const Directory = @import("Directory.zig");
const Fat = @import("Fat.zig");
const SectorNumber = @import("SectorNumber.zig").SectorNumber;

cfb: *const Cfb,
fat: Fat,
start: SectorNumber,
size: u64,
cursor: u32 = 0,
sector: SectorNumber,

/// root is Directory[0], whose start_sector and stream_size describe the mini stream.
pub fn init(cfb: *const Cfb) Cfb.ReadError!MiniStream {
    var dir: Directory = .init(cfb);
    const root = try dir.directoryEntry(.root);
    const start: SectorNumber = .fromInt(root.start_sector);
    const size = if (cfb.header.major_ver == 3) root.stream_size & 0xffffffff else root.stream_size;
    return .{ .cfb = cfb, .fat = .init(cfb), .start = start, .size = size, .sector = start };
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

const ByteSource = @import("../ByteSource.zig");
const MiniFat = @import("MiniFat.zig");
const testing = std.testing;

test readMiniSector {
    var src: ByteSource.Memory = try .fromPath(testing.io, "samples/01-ms-cfb/ms-cfb.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src.byteSource());
    var ms: MiniStream = try .init(&cfb);

    var expected: [9 * 64]u8 = @splat(0);
    for (expected[0..544], 0..) |*b, i| b.* = "Data for stream 1"[i % 17];

    for ([_]u32{ 0, 1, 7, 8, 3, 0, 8 }) |n|
        try testing.expectEqualSlices(u8, expected[n * 64 ..][0..64], &try ms.readMiniSector(.fromInt(n)));

    try testing.expectError(error.EndOfStream, ms.readMiniSector(.fromInt(9)));
    try testing.expectError(error.InvalidSector, ms.readMiniSector(.endofchain));
}

test "readMiniSector big v3" {
    var src: ByteSource.Memory = try .fromPath(testing.io, "samples/02-big-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src.byteSource());
    var ms: MiniStream = try .init(&cfb);

    var expected: [100]u8 = undefined;
    for (&expected, 0..) |*b, i| b.* = @intCast((i + 4) % 251);

    try testing.expectEqualSlices(u8, expected[0..64], &try ms.readMiniSector(.fromInt(0)));
    try testing.expectEqualSlices(u8, expected[64..], (try ms.readMiniSector(.fromInt(1)))[0..36]);

    try testing.expectError(error.EndOfStream, ms.readMiniSector(.fromInt(2)));
}

test "readMiniSector big v3 clears high bits" {
    const f = try std.Io.Dir.cwd().openFile(testing.io, "samples/03-minifat-v3/win11-24h2-26100.9549-amd64.cfb", .{});
    defer f.close(testing.io);
    var reader = f.reader(testing.io, &.{});
    const bytes = try reader.interface.readAllocShort(testing.allocator, 100 * 1024);
    defer testing.allocator.free(bytes);
    var src: ByteSource.Memory = .fromSlice(bytes);
    defer src.deinit();
    const cfb = try Cfb.open(src.byteSource());
    // The directory entry starts at sector 1. We bump it to a size, using the
    // high bits, such that the code would think we have 5000 minifat entries.
    var root = std.mem.bytesAsValue(Directory.Entry, bytes[1024..][0..128]);
    root.stream_size = 0x100000000 | root.stream_size;

    var mini_stream: MiniStream = try .init(&cfb);

    try std.testing.expectError(error.EndOfStream, mini_stream.readMiniSector(.fromInt(5000)));
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
    var src: ByteSource.Memory = try .fromPath(testing.io, "samples/03-minifat-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src.byteSource());
    var dir: Directory = .init(&cfb);
    var mini_fat: MiniFat = .init(&cfb);
    var ms: MiniStream = try .init(&cfb);

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
