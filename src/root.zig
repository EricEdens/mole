const std = @import("std");

pub const ILockBytes = @import("ILockBytes.zig");
pub const IStorage = @import("IStorage.zig");
pub const IStream = @import("IStream.zig");

test {
    std.testing.refAllDecls(@This());
}
