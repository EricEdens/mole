//! Interface for a directory.
//!
//! https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-istorage

const Storage = @This();

const std = @import("std");
const Cfb = @import("cfb.zig").Cfb;
const idl = @import("idl.zig");
const Stream = @import("Stream.zig");
const Name = @import("Name.zig");

cfb: *Cfb,
stream_id: u32,

pub const OpenElementError = error{};

/// [IStorage::OpenStream](https://learn.microsoft.com/en-us/windows/win32/api/objidl/nf-objidl-istorage-openstream)
pub fn openStream(self: Storage, name: Name) OpenElementError!Stream {
    _ = self;
    _ = name;
}

/// [IStorage::OpenStorage](https://learn.microsoft.com/en-us/windows/win32/api/objidl/nf-objidl-istorage-openstorage)
pub fn openStorage(self: Storage, name: Name) OpenElementError!Storage {
    // TODO: This makes it really clear that we'll need an indirection,
    // since the nested storage isn' re-parsing buffer. So, maybe another
    // vtable? :(
    _ = self;
    _ = name;
}

pub const CreateElementError = error{};

/// [IStorage::CreateStream](https://learn.microsoft.com/en-us/windows/win32/api/objidl/nf-objidl-istorage-createstream)
pub fn createStream(self: Storage, name: Name) CreateElementError!Stream {
    _ = self;
    _ = name;
}

/// [IStorage::CreateStorage](https://learn.microsoft.com/en-us/windows/win32/api/objidl/nf-objidl-istorage-createstorage)
pub fn createStorage(self: Storage, name: Name) CreateElementError!Storage {
    _ = self;
    _ = name;
}

pub const StatError = error{};

/// [IStorage::Stat](https://learn.microsoft.com/en-us/windows/win32/api/objidl/nf-objidl-istorage-stat)
/// and [ReadClassStg](https://learn.microsoft.com/en-us/windows/win32/api/coml2api/nf-coml2api-readclassstg).
pub fn stat(self: Storage) StatError!idl.Stat {
    _ = self;
}
