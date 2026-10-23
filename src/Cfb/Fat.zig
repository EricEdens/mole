const Fat = @This();

const Cfb = @import("../Cfb.zig");
const SectorNumber = @import("SectorNumber.zig").SectorNumber;

cfb: *const Cfb,

/// Returns FAT[n], the next sector number in the chain after sector #n.
pub fn nextSectorInChain(self: *const Fat, n: SectorNumber) Cfb.ReadError!SectorNumber {
    _ = .{ self, n };
    @panic("TODO");
}
