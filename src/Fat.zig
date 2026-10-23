const Fat = @This();

const Cfb = @import("Cfb.zig");
const SectorId = @import("SectorId.zig").SectorId;

/// Resolve a sector index along the FAT chain beginning at start.
pub fn next(self: *const Fat, n: SectorId) SectorId {
    _ = self;
    _ = n;
    // TODO: Walk the FAT sector chain.
    return error.NotImplemented;
}

fn parent(self: *const Fat) *const Cfb {
    return @alignCast(@fieldParentPtr("fat", self));
}
