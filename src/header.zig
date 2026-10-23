const std = @import("std");
const Source = @import("source.zig").Source;
const SectorId = @import("SectorId.zig").SectorId;

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

    pub const ReadError = Source.ReadError || error{EndOfStream};

    pub fn read(s: Source) ReadError!Header {
        var h: Header = undefined;
        if (try s.readAt(std.mem.asBytes(&h), 0) != @sizeOf(Header)) return error.EndOfStream;
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
    var src: Source = try .fromPath(testing.io, "samples/00-empty-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();

    const header = try Header.read(src);
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
