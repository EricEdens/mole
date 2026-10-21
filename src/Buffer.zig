//! Our version of 'ILockBytes'.
//!
//! https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-ilockbytes
const Buffer = @This();

const std = @import("std");
const Stat = @import("idl.zig").Stat;

pub const ArrayListBuffer = @import("Buffer/ArrayListBuffer.zig");

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Write data from Buffer into 'buffer'.
    ///
    /// Notes:
    ///   * You don't have to fill the buffer.
    ///   * Above the vtable we validate that everything fits.
    readPositional: *const fn (ptr: *anyopaque, buffer: []u8, offset: u64) ReadError!usize,

    /// Write data from 'buffer' into the Buffer.
    ///
    /// Same notes as readPositional.
    writePositional: *const fn (ptr: *anyopaque, buffer: []const u8, offset: u64) WriteError!usize,

    /// Drains bytes to the underlying storage.
    sync: *const fn (ptr: *anyopaque) SyncError!void,

    /// Returns the amount of bytes for which it is safe to read or write.
    ///
    /// Important: This is infallible, meaning that implementations can't
    /// reach out a backend to get it.
    getSize: *const fn (ptr: *anyopaque) usize,

    /// Grow or truncate the storage.
    resize: *const fn (ptr: *anyopaque, new_size: usize) ResizeError!void,

    close: *const fn (ptr: *anyopaque) void,
};

pub const ReadResult = struct {
    bytes_read: usize,
    err: ?ReadError = null,
};

pub const WriteResult = struct {
    bytes_written: usize,
    err: ?WriteError = null,
};

pub fn readAt(self: Buffer, buffer: []u8, offset: u64) ReadResult {
    // TODO: check capacity. the vtable is infallible here.
    // TODO: re-drive on short reads. ILockBytes::ReadAt
    // only allows short-reads if: there was an error or you've reached
    // EOF.
    if (self.vtable.readPositional(self.ptr, buffer, offset)) |n| {
        return .{ .bytes_read = n };
    } else |err| {
        return .{ .bytes_read = 0, .err = err };
    }
}

pub fn writeAt(self: Buffer, buffer: []const u8, offset: u64) WriteResult {
    // TODO: check capacity and grow if needed. the vtable is infallible here.
    // TODO: re-drive on short writes, similar to readAt.
    if (self.vtable.writePositional(self.ptr, buffer, offset)) |n| {
        return .{ .bytes_written = n };
    } else |err| {
        return .{ .bytes_written = 0, .err = err };
    }
}

pub fn flush(self: Buffer) SyncError!void {
    return self.vtable.sync(self.ptr);
}

pub fn setSize(self: Buffer, new_size: usize) ResizeError!void {
    return self.vtable.resize(self.ptr, new_size);
}

pub fn stat(self: Buffer) StatError!Stat {
    return .{ .kind = .lockbytes, .size = self.vtable.getSize(self.ptr) };
}

pub fn close(self: Buffer) void {
    self.vtable.close(self.ptr);
}

pub const ReadError = error{};
pub const WriteError = error{};
pub const SyncError = error{};
pub const StatError = error{};
pub const ResizeError = error{OutOfMemory};

test {
    std.testing.refAllDecls(@This());
}
