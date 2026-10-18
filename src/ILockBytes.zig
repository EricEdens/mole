//! Interface providing random-access of bytes with optional locking.
//!
//! https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-ilockbytes

const std = @import("std");

test "hello world" {
    try std.testing.expectEqualStrings("hello, world", "hello, world");
}
