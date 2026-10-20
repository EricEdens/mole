const std = @import("std");
const Guid = std.os.windows.GUID;
const Timestamp = std.Io.Timestamp;

/// https://learn.microsoft.com/en-us/windows/win32/api/objidl/ne-objidl-stgty
pub const Type = enum {
    storage,
    stream,
    lockbytes,
    property,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/objidl/ns-objidl-statstg
pub const Stat = struct {
    kind: Type,
    size: u64,
    clsid: Guid = std.mem.zeroes(Guid),
    state_bits: u32 = 0,
    ctime: Timestamp = .zero,
    mtime: Timestamp = .zero,
};
