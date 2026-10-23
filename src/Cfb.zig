const Cfb = @This();

const std = @import("std");

const Difat = @import("Difat.zig");
const Fat = @import("Fat.zig");
const Header = @import("header.zig").Header;
const SectorId = @import("SectorId.zig").SectorId;
const Source = @import("source.zig").Source;

source: Source,
header: Header,
fat: Fat = .{},

pub const ReadError = Source.ReadError || error{ InvalidSector, InvalidSectorOffset, EndOfStream };
pub const OpenError = Header.ReadError || error{InvalidHeader};

pub fn open(source: Source) OpenError!Cfb {
    const h = try Header.read(source);
    if (!std.mem.eql(u8, &h.signature, &.{ 0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1 }))
        return error.InvalidHeader;
    if (h.byte_order != 0xfffe) return error.InvalidHeader;
    switch (h.major_ver) {
        3 => if (h.sector_shift != 9) return error.InvalidHeader,
        4 => if (h.sector_shift != 12) return error.InvalidHeader,
        else => return error.InvalidHeader,
    }
    return .{ .source = source, .header = h };
}

pub fn difat(self: *const Cfb) Difat {
    return .{ .cfb = self };
}

pub fn sectorSize(self: *const Cfb) u32 {
    return @as(u32, 1) << @intCast(self.header.sector_shift);
}

pub fn readWithinSector(self: *const Cfb, comptime T: type, sector: SectorId, offset: u32) ReadError!T {
    if (!sector.is_regular()) return error.InvalidSector;

    const Int = switch (@typeInfo(T)) {
        .int => T,
        else => @compileError("readWithinSector only works on ints"),
    };
    const byte_count = @sizeOf(Int);
    const sector_size = self.sectorSize();
    if (offset > sector_size or byte_count > sector_size - offset)
        return error.InvalidSectorOffset;

    const position = (@as(u64, @backingInt(sector)) + 1) * sector_size + offset;
    if (position + byte_count > self.source.size()) return error.EndOfStream;
    var bytes: [byte_count]u8 = undefined;
    if (try self.source.readAt(&bytes, position) != byte_count) return error.EndOfStream;
    return std.mem.readInt(Int, &bytes, .little);
}

comptime {
    _ = Difat;
    _ = @import("DirectoryEntry.zig");
}

const testing = std.testing;

test "read MS-CFB section 3 example" {
    var src: Source = try .fromPath(testing.io, "samples/01-ms-cfb/ms-cfb.cfb");
    defer src.deinit();
    try testing.expectEqual(3072, src.size());

    const cfb: Cfb = try .open(src);
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
    }, cfb.header);
    try testing.expectEqual(SectorId.fromInt(1), cfb.header.firstDir());
    try testing.expectEqual(SectorId.fromInt(2), cfb.header.firstMiniFat());
    try testing.expectEqual(SectorId.endofchain, cfb.header.firstDifat());
    try testing.expectEqual(512, cfb.sectorSize());

    var difat_iter = cfb.difat().sectorIds();
    try testing.expectEqual(null, try difat_iter.next());

    var fat_iter = cfb.difat().fatSectorIds();
    try testing.expectEqual(SectorId.fromInt(0), try fat_iter.next());
    try testing.expectEqual(null, try fat_iter.next());
}
