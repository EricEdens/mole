//! Name of a directory entry.
//!
//! https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/60fe8611-66c3-496b-b70d-a504c94c9ace

const Name = @This();

units: [32:0]u16 = undefined,
len: u8 = 0,
