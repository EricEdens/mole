//! Interface for a directory.
//!
//! https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-istorage

const Storage = @This();

const std = @import("std");
const Buffer = @import("Buffer.zig");
const idl = @import("idl.zig");
const IStream = @import("IStream.zig");
const Name = @import("Name.zig");

buffer: Buffer,

pub const OpenError = error{};

/// Opens 'buffer' and interprets it as an existing MS-CFB file.
///
/// This handles the behavior of the classic stg openers:
///   * Classic via filename: [StgOpenStorage](https://learn.microsoft.com/en-us/windows/win32/api/coml2api/nf-coml2api-stgopenstorage)
///   * New via filename: [StgOpenStorageEx](https://learn.microsoft.com/en-us/windows/win32/api/coml2api/nf-coml2api-stgopenstorageex)
///   * From arbitrary ILockBytes: [StgOpenStorageOnILockBytes](https://learn.microsoft.com/en-us/windows/win32/api/coml2api/nf-coml2api-stgopenstorageonilockbytes).
pub fn open(buffer: Buffer) OpenError!Storage {
    _ = buffer;
}

pub const CreateError = error{};

/// Creates a new MS-CFB file, backed by 'buffer'.
///
/// This handles the behavior of the classic stg creators:
///   * Classic via filename: [StgCreateDocfile](https://learn.microsoft.com/en-us/windows/win32/api/coml2api/nf-coml2api-stgcreatedocfile)
///   * New via filename: [StgCreateStorageEx](https://learn.microsoft.com/en-us/windows/win32/api/coml2api/nf-coml2api-stgcreatestorageex)
///   * From arbitrary ILockBytes: [StgCreateDocfileOnILockBytes](https://learn.microsoft.com/en-us/windows/win32/api/coml2api/nf-coml2api-stgcreatedocfileonilockbytes).
pub fn create(buffer: Buffer, options: CreateOptions) CreateError!Storage {
    _ = buffer;
    _ = options;
}

pub const FlushError = error{};

/// [IStorage::Commit](https://learn.microsoft.com/en-us/windows/win32/api/objidl/nf-objidl-istorage-commit)
pub fn flush(self: Storage) FlushError!void {
    return self.buffer.flush();
}

pub const OpenElementError = error{};

/// [IStorage::OpenStream](https://learn.microsoft.com/en-us/windows/win32/api/objidl/nf-objidl-istorage-openstream)
pub fn openStream(self: Storage, name: Name) OpenElementError!IStream {
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
pub fn createStream(self: Storage, name: Name) CreateElementError!IStream {
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

pub const Version = enum { v3, v4 };

pub const OpenOptions = struct {};

pub const CreateOptions = struct {
    version: Version = .v3,
};
