const std = @import("std");

const Buffer = @import("Buffer.zig");
pub const Difat = @import("cfb/Difat.zig");
pub const DirectoryEntry = @import("cfb/DirectoryEntry.zig");
pub const Fat = @import("cfb/Fat.zig");
pub const Header = @import("cfb/header.zig").Header;

pub const SectorId = enum(u32) {
    max_reg = 0xfffffffa,
    difat = 0xfffffffc,
    fat = 0xfffffffd,
    endofchain = 0xfffffffe,
    free = 0xffffffff,
    _,

    pub fn fromInt(value: u32) SectorId {
        return @fromBackingInt(value);
    }

    pub fn is_regular(s: SectorId) bool {
        return @backingInt(s) <= 0xfffffffa;
    }
};

pub const Control = enum {
    fat,
    minifat,
    difat,
    dir,
};

pub const StreamId = enum(u32) {
    root = 0,
    max_reg = 0xfffffffa,
    nostream = 0xffffffff,
    _,

    pub fn is_regular(s: StreamId) bool {
        return @backingInt(s) <= 0xfffffffa;
    }
};

pub const Cfb = struct {
    buffer: Buffer,
    header: Header,
    difat: Difat = .{},
    fat: Fat = .{},

    pub const ReadError = Buffer.ReadError || error{ InvalidSector, InvalidSectorOffset, EndOfStream };
    pub const OpenError = Buffer.ReadError || error{ EndOfStream, InvalidHeader };

    pub fn open(buffer: Buffer) OpenError!Cfb {
        if (buffer.size() < @sizeOf(Header)) return error.EndOfStream;
        const h = try Header.read(buffer);
        if (!std.mem.eql(u8, &h.signature, &.{ 0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1 }))
            return error.InvalidHeader;
        if (h.byte_order != 0xfffe) return error.InvalidHeader;
        switch (h.major_ver) {
            3 => if (h.sector_shift != 9) return error.InvalidHeader,
            4 => if (h.sector_shift != 12) return error.InvalidHeader,
            else => return error.InvalidHeader,
        }
        return .{ .buffer = buffer, .header = h };
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
        if (position + byte_count > self.buffer.size()) return error.EndOfStream;
        var bytes: [byte_count]u8 = undefined;
        const result = self.buffer.readAt(&bytes, position);
        if (result.err) |err| return err;
        if (result.bytes_read != byte_count) return error.EndOfStream;
        return std.mem.readInt(Int, &bytes, .little);
    }
};

comptime {
    _ = DirectoryEntry;
    _ = Header;
    _ = Difat;
    _ = Fat;
}
