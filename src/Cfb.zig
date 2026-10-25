const Cfb = @This();

const std = @import("std");

const ByteSource = @import("ByteSource.zig");
pub const Difat = @import("Cfb/Difat.zig");
const Directory = @import("Cfb/Directory.zig");
const Fat = @import("Cfb/Fat.zig");
const Header = @import("Cfb/header.zig").Header;
const MiniFat = @import("Cfb/MiniFat.zig");
const MiniStream = @import("Cfb/MiniStream.zig");
const SectorNumber = @import("Cfb/SectorNumber.zig").SectorNumber;

source: ByteSource,
header: Header,

pub const ReadError = ByteSource.ReadError || error{InvalidSector};
pub const OpenError = Header.ReadError || error{InvalidHeader};

pub fn open(source: ByteSource) OpenError!Cfb {
    const h = try Header.read(source);
    if (!std.mem.eql(u8, &h.signature, &.{ 0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1 }))
        return error.InvalidHeader;
    if (h.byte_order != 0xfffe) return error.InvalidHeader;
    if (h.mini_sector_shift != 6) return error.InvalidHeader;
    switch (h.major_ver) {
        3 => if (h.sector_shift != 9) return error.InvalidHeader,
        4 => if (h.sector_shift != 12) return error.InvalidHeader,
        else => return error.InvalidHeader,
    }
    return .{ .source = source, .header = h };
}

//-- Logical Stats --//

pub fn fileSize(self: *const Cfb) u64 {
    _ = self;
    @panic("TODO");
}

pub fn bytesPerSector(self: *const Cfb) u32 {
    return @as(u32, 1) << @intCast(self.header.sector_shift);
}

pub fn bytesPerMiniSector(self: *const Cfb) u32 {
    return @as(u32, 1) << @intCast(self.header.mini_sector_shift);
}

pub fn numSectors(self: *const Cfb) u32 {
    std.math.divCeil(u32, self.source.size() - self.bytesPerSector(), self.bytesPerSector());
}

//-- Pointers to start of entities --//

pub fn firstDifat(self: *const Cfb) SectorNumber {
    return .fromInt(self.header.first_difat);
}

pub fn firstDir(self: *const Cfb) SectorNumber {
    return .fromInt(self.header.first_dir);
}

pub fn firstMiniFat(self: *const Cfb) SectorNumber {
    return .fromInt(self.header.first_mini_fat);
}

//-- IO --//

pub fn readSector(self: *const Cfb, sector: SectorNumber, buf: []u8) ReadError!void {
    std.debug.assert(buf.len == self.bytesPerSector());
    if (!sector.isRegular()) return error.InvalidSector;
    const position = (@as(u64, @backingInt(sector)) + 1) * buf.len;
    try self.source.readAt(buf, position);
}

pub fn readValue(self: *const Cfb, comptime T: type, sector: SectorNumber, idx: u32) ReadError!T {
    std.debug.assert(idx < self.bytesPerSector() / @sizeOf(T));
    if (!sector.isRegular()) return error.InvalidSector;
    comptime if (512 % @sizeOf(T) != 0) @compileError(@typeName(T) ++ " straddles sectors");

    const position = (@as(u64, @backingInt(sector)) + 1) * self.bytesPerSector() + @as(u64, idx) * @sizeOf(T);
    return self.source.readValue(T, position);
}

pub fn readMiniSector(self: *const Cfb, sector: SectorNumber, buf: []u8) ReadError!void {
    _ = .{ self, sector, buf };
    @panic("TODO");
}

comptime {
    _ = Difat;
    _ = Fat;
    _ = Directory;
    _ = MiniFat;
    _ = MiniStream;
}

const testing = std.testing;

test "read MS-CFB section 3 example" {
    var src: ByteSource.Memory = try .fromPath(testing.io, "samples/01-ms-cfb/ms-cfb.cfb");
    defer src.deinit();
    try testing.expectEqual(3072, src.byteSource().size());

    const cfb: Cfb = try .open(src.byteSource());
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
    try testing.expectEqual(SectorNumber.fromInt(1), cfb.firstDir());
    try testing.expectEqual(SectorNumber.fromInt(2), cfb.firstMiniFat());
    try testing.expectEqual(SectorNumber.endofchain, cfb.firstDifat());
    try testing.expectEqual(512, cfb.bytesPerSector());
    try testing.expectEqual(64, cfb.bytesPerMiniSector());
}
