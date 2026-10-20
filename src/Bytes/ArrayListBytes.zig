//! A slow, but simple, implementation of Bytes.
//!
//! std.ArrayList is the basis, and it's a really strong basis
//! because it provides the precise api that we need. The
//! problem, which needs to be validated with benchmarking, is
//! that ArrayList most likely will do N-squared copies as it
//! grows.

const ArrayListBytes = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const Bytes = @import("../Bytes.zig");

allocator: Allocator,
list: std.ArrayList(u8) = .empty,

pub fn init(allocator: Allocator) ArrayListBytes {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *ArrayListBytes) void {
    self.list.deinit(self.allocator);
    self.* = undefined;
}

pub fn bytes(self: *ArrayListBytes) Bytes {
    return .{ .ptr = self, .vtable = &.{
        .readPositional = readPositional,
        .writePositional = writePositional,
        .sync = sync,
        .getSize = getSize,
        .resize = resize,
    } };
}

fn readPositional(ptr: *anyopaque, buffer: []u8, offset: u64) Bytes.ReadError!usize {
    const self: *ArrayListBytes = @ptrCast(@alignCast(ptr));
    const src = self.list.items[@intCast(offset)..];
    // safety: The vtable's contract is that buffer and offset are clamped to
    // the bounds of [0..getSize()].
    @memcpy(buffer, src);
    return buffer.len;
}

fn writePositional(ptr: *anyopaque, buffer: []const u8, offset: u64) Bytes.WriteError!usize {
    const self: *ArrayListBytes = @ptrCast(@alignCast(ptr));
    const dst = self.list.items[@intCast(offset)..];
    // safety: The vtable's contract is that buffer and offset are within
    // the bounds of [0..getSize()].
    @memcpy(dst, buffer);
    return buffer.len;
}

fn sync(_: *anyopaque) Bytes.SyncError!void {}

fn getSize(ptr: *anyopaque) usize {
    const self: *ArrayListBytes = @ptrCast(@alignCast(ptr));
    return self.list.items.len;
}

fn resize(ptr: *anyopaque, new_size: usize) Bytes.ResizeError!void {
    const self: *ArrayListBytes = @ptrCast(@alignCast(ptr));
    try self.list.resize(self.allocator, new_size);
}
