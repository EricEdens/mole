//! Interface for a file.
//!
//! https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-istream

const Stream = @This();

const Cfb = @import("Cfb.zig");

cfb: *Cfb,
stream_id: u32,
