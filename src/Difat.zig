const Difat = @This();

const Cfb = @import("Cfb.zig");
const SectorNumber = @import("SectorNumber.zig").SectorNumber;

cfb: *const Cfb,

/// Returns DIFAT[n], the sector number of FAT sector #n.
pub fn fatSectorLocation(self: *const Difat, n: u32) Cfb.ReadError!SectorNumber {
    _ = .{ self, n };
    @panic("TODO");
}
