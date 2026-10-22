const std = @import("std");
const Buffer = @import("../Buffer.zig");
const SectorId = @import("../cfb.zig").SectorId;

pub const Header = extern struct {
    signature: [8]u8,
    clsid: [16]u8,
    minor_ver: u16,
    major_ver: u16,
    byte_order: u16,
    sector_shift: u16,
    mini_sector_shift: u16,
    reserved: [6]u8,
    num_dir: u32,
    num_fat: u32,
    first_dir: u32,
    tx_sig: u32,
    mini_cutoff: u32,
    first_mini_fat: u32,
    num_mini_fat: u32,
    first_difat: u32,
    num_difat: u32,
    difat: [109]u32,

    /// Sector IDs are in native byte order after read().
    pub fn firstDir(self: Header) SectorId {
        return SectorId.fromInt(self.first_dir);
    }

    pub fn firstMiniFat(self: Header) SectorId {
        return SectorId.fromInt(self.first_mini_fat);
    }

    pub fn firstDifat(self: Header) SectorId {
        return SectorId.fromInt(self.first_difat);
    }

    pub fn read(b: Buffer) !Header {
        var h: Header = undefined;
        const result = b.readAt(std.mem.asBytes(&h), 0);
        if (result.err) |err| return err;
        if (result.bytes_read != @sizeOf(Header)) return error.EndOfStream;
        if (@import("builtin").cpu.arch.endian() == .big)
            std.mem.byteSwap(Header, &h);
        return h;
    }
};

const testing = std.testing;

test "Header is 512 bytes" {
    try testing.expectEqual(512, @sizeOf(Header));
}

test "read empty v3 Windows 11 header" {
    var buffer = Buffer.ArrayListBuffer.init(testing.allocator);
    defer buffer.deinit();
    const contents = try std.Io.Dir.cwd().readFileAlloc(
        testing.io,
        "samples/00-empty-v3/win11-24h2-26100.9549-amd64.cfb",
        testing.allocator,
        .unlimited,
    );
    buffer.list = .fromOwnedSlice(contents);

    const header = try Header.read(buffer.buffer());
    try testing.expectEqualDeep(Header{
        .signature = .{ 0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1 },
        .clsid = @splat(0),
        .minor_ver = 0x003e,
        .major_ver = 3,
        .byte_order = 0xfffe,
        .sector_shift = 9,
        .mini_sector_shift = 6,
        .reserved = @splat(0),
        .num_dir = 0,
        .num_fat = 1,
        .first_dir = 1,
        .tx_sig = 0,
        .mini_cutoff = 4096,
        .first_mini_fat = 0xfffffffe,
        .num_mini_fat = 0,
        .first_difat = 0xfffffffe,
        .num_difat = 0,
        .difat = .{0} ++ @as([108]u32, @splat(0xffffffff)),
    }, header);
    try testing.expectEqual(SectorId.fromInt(1), header.firstDir());
    try testing.expectEqual(SectorId.endofchain, header.firstMiniFat());
    try testing.expectEqual(SectorId.endofchain, header.firstDifat());
}

test "read MS-CFB section 3 example header" {
    var buffer = Buffer.ArrayListBuffer.init(testing.allocator);
    defer buffer.deinit();
    const contents = try std.Io.Dir.cwd().readFileAlloc(
        testing.io,
        "samples/01-ms-cfb/ms-cfb.cfb",
        testing.allocator,
        .unlimited,
    );
    buffer.list = .fromOwnedSlice(contents);
    try testing.expectEqual(3072, contents.len);

    const header = try Header.read(buffer.buffer());
    try testing.expectEqualDeep(Header{
        .signature = .{ 0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1 },
        .clsid = @splat(0),
        .minor_ver = 0x003e,
        .major_ver = 3,
        .byte_order = 0xfffe,
        .sector_shift = 9,
        .mini_sector_shift = 6,
        .reserved = @splat(0),
        .num_dir = 0,
        .num_fat = 1,
        .first_dir = 1,
        .tx_sig = 0,
        .mini_cutoff = 4096,
        .first_mini_fat = 2,
        .num_mini_fat = 1,
        .first_difat = 0xfffffffe,
        .num_difat = 0,
        .difat = .{0} ++ @as([108]u32, @splat(0xffffffff)),
    }, header);
    try testing.expectEqual(SectorId.fromInt(1), header.firstDir());
    try testing.expectEqual(SectorId.fromInt(2), header.firstMiniFat());
    try testing.expectEqual(SectorId.endofchain, header.firstDifat());
}
