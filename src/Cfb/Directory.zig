//! Array-style access to the directory entry array.
const Directory = @This();

const std = @import("std");

const Cfb = @import("../Cfb.zig");
const Fat = @import("Fat.zig");
const SectorNumber = @import("SectorNumber.zig").SectorNumber;
const StreamId = @import("StreamId.zig").StreamId;

cfb: *const Cfb,
fat: Fat,
cursor: u32 = 0,
sector: SectorNumber,

pub const Entry = extern struct {
    name: [32]u16,
    name_len: u16,
    obj_type: u8,
    color_flag: u8,
    left_sib: u32,
    right_sib: u32,
    child: u32,
    clsid: [16]u8,
    state_bits: u32,
    creation_time: u64 align(4),
    modified_time: u64 align(4),
    start_sector: u32,
    stream_size: u64,
};

pub fn init(cfb: *const Cfb) Directory {
    return .{ .cfb = cfb, .fat = .init(cfb), .sector = cfb.firstDir() };
}

/// Returns Directory[id], the directory entry with stream ID #id.
pub fn directoryEntry(self: *Directory, id: StreamId) Cfb.ReadError!Entry {
    if (!id.isRegular()) return error.InvalidSector;

    const next_cursor = @backingInt(id) / self.entriesPerSector();

    if (next_cursor < self.cursor) {
        self.cursor = 0;
        self.sector = self.cfb.firstDir();
    }

    while (self.cursor < next_cursor) : (self.cursor += 1) {
        self.sector = try self.fat.nextSectorInChain(self.sector);
    }

    return self.cfb.readValue(Entry, self.sector, @backingInt(id) % self.entriesPerSector());
}

fn entriesPerSector(self: *const Directory) u32 {
    return self.cfb.bytesPerSector() / @sizeOf(Entry);
}

const ByteSource = @import("../ByteSource.zig");
const testing = std.testing;

test "Entry is 128 bytes" {
    try testing.expectEqual(128, @sizeOf(Entry));
}

test directoryEntry {
    // id, name_len, obj_type, left_sib, right_sib, child, start_sector, stream_size
    const expected = [_][8]u32{
        // First directory sector
        .{ 0, 22, 5, 0xffffffff, 0xffffffff, 0x3, 0x60d6, 128 },
        .{ 3, 4, 2, 0x1, 0x2, 0xffffffff, 0x12, 3145728 },

        // Second directory sector
        .{ 4, 4, 2, 0xffffffff, 0xffffffff, 0xffffffff, 0x0, 100 },
        .{ 7, 0, 0, 0xffffffff, 0xffffffff, 0xffffffff, 0x0, 0 },

        // Backwards
        .{ 2, 4, 2, 0xffffffff, 0x4, 0xffffffff, 0xa, 5242880 },
        .{ 1, 4, 2, 0xffffffff, 0xffffffff, 0xffffffff, 0x2, 8388608 },

        // Forwards
        .{ 5, 0, 0, 0xffffffff, 0xffffffff, 0xffffffff, 0x0, 0 },
    };
    var src: ByteSource.Memory = try .fromPath(testing.io, "samples/02-big-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();
    const cfb = try Cfb.open(src.byteSource());
    var dir: Directory = .init(&cfb);

    for (expected) |e| {
        const d = try dir.directoryEntry(@fromBackingInt(@intCast(e[0])));
        const actual = [_]u32{ e[0], d.name_len, d.obj_type, d.left_sib, d.right_sib, d.child, d.start_sector, @intCast(d.stream_size) };
        if (!std.mem.eql(u32, &actual, &e)) {
            std.debug.print("Directory[{d}]: expected {any}, found {any}\n", .{ e[0], e, actual });
            return error.TestExpectedEqual;
        }
    }

    try testing.expectError(error.InvalidSector, dir.directoryEntry(.nostream));
    try testing.expectError(error.InvalidSector, dir.directoryEntry(@fromBackingInt(@intCast(8))));
}
