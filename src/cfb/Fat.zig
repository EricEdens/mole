const Fat = @This();

const Cfb = @import("../cfb.zig").Cfb;
const Sect = @import("../cfb.zig").Sect;

/// Resolve a sector index along the FAT chain beginning at start.
pub fn next(self: *const Fat, n: Sect) Sect {
    _ = self;
    _ = n;
    // TODO: Walk the FAT sector chain.
    return error.NotImplemented;
}

fn parent(self: *const Fat) *const Cfb {
    return @alignCast(@fieldParentPtr("fat", self));
}
