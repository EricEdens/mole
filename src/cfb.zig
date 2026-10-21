const std = @import("std");

pub const DirectoryEntry = @import("cfb/DirectoryEntry.zig");
pub const Header = @import("cfb/header.zig").Header;

pub const Cfb = struct {};

comptime {
    _ = DirectoryEntry;
    _ = Header;
}
