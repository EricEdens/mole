const Buffer = @import("Buffer.zig");
const Storage = @import("Storage.zig");

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

pub const Version = enum { v3, v4 };

pub const OpenOptions = struct {};

pub const CreateOptions = struct {
    version: Version = .v3,
};
