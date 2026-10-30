const Cfb = @This();

const std = @import("std");
const ByteSource = @import("../io.zig").ByteSource;
const SectorNumber = @import("SectorNumber.zig").SectorNumber;

pub const Version = enum { v3, v4 };

pub const Header = extern struct {
    signature: [8]u8,
    clsid: [16]u8,
    minor: u16,
    major: u16,
    byte_order: u16,
    shift: u16,
    mini_shift: u16,
    reserved: [6]u8,
    num_dirs: u32,
    num_fat: u32,
    first_dir: u32,
    txn: u32,
    mini_cutoff: u32,
    first_mini: u32,
    num_mini: u32,
    first_difat: u32,
    num_difat: u32,
    difat: [109]u32,

    pub fn validate(h: *const Header) !Version {
        if (!std.mem.eql(u8, &h.signature, &.{ 0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1 }))
            return error.SignatureMismatch;
        if (h.major > 4) return error.VersionGreaterThan4;
        const version: Version = switch (h.shift) {
            9 => .v3,
            12 => .v4,
            else => return error.BadMajorShift,
        };
        if (h.mini_shift != 6) return error.BadMiniShift;
        if (version == .v4 and h.mini_cutoff != 4096) return error.BadV4MiniCutoff;
        return version;
    }
};

pub const ReadError = ByteSource.ReadError || error{ InvalidSector, SectorBeyondFat, SelfLoop };

source: ByteSource,
version: Version,
first_dir: SectorNumber,
first_mini_fat: SectorNumber,
first_difat: SectorNumber,
num_fat: u32,
difat: [109]SectorNumber,

//-- Logical Stats --//

pub fn fileSize(self: *const Cfb) u64 {
    return self.source.size();
}

pub fn bytesPerSector(self: *const Cfb) u32 {
    return switch (self.version) {
        .v3 => 512,
        .v4 => 4096,
    };
}

pub fn bytesPerMiniSector(_: *const Cfb) u32 {
    return 64;
}

pub fn numSectors(self: *const Cfb) u64 {
    return self.source.size() / self.bytesPerSector() -| 1;
}

pub fn inFile(self: *const Cfb, sector: SectorNumber) bool {
    return sector.isRegular() and @backingInt(sector) < self.numSectors();
}

//-- IO --//

pub fn readValue(self: *const Cfb, comptime T: type, sector: SectorNumber, idx: u32) ReadError!T {
    std.debug.assert(idx < self.bytesPerSector() / @sizeOf(T));
    if (!sector.isRegular()) return error.InvalidSector;
    comptime if (512 % @sizeOf(T) != 0) @compileError(@typeName(T) ++ " straddles sectors");

    const position = (@as(u64, @backingInt(sector)) + 1) * self.bytesPerSector() + @as(u64, idx) * @sizeOf(T);
    return self.source.readValue(T, position);
}
