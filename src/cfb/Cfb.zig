const Cfb = @This();

const std = @import("std");
const ByteSource = @import("../io.zig").ByteSource;
const SectorNumber = @import("SectorNumber.zig").SectorNumber;

pub const Version = enum { v3, v4 };

pub const ReadError = ByteSource.ReadError || error{InvalidSector};

source: ByteSource,
version: Version,
first_dir: SectorNumber,
first_mini_fat: SectorNumber,
first_difat: SectorNumber,
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

pub fn numSectors(self: *const Cfb) u32 {
    std.math.divCeil(u32, self.source.size() - self.bytesPerSector(), self.bytesPerSector());
}

//-- IO --//

pub fn readValue(self: *const Cfb, comptime T: type, sector: SectorNumber, idx: u32) ReadError!T {
    std.debug.assert(idx < self.bytesPerSector() / @sizeOf(T));
    if (!sector.isRegular()) return error.InvalidSector;
    comptime if (512 % @sizeOf(T) != 0) @compileError(@typeName(T) ++ " straddles sectors");

    const position = (@as(u64, @backingInt(sector)) + 1) * self.bytesPerSector() + @as(u64, idx) * @sizeOf(T);
    return self.source.readValue(T, position);
}
