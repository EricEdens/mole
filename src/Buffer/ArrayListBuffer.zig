//! A slow, but simple, implementation of Buffer.
//!
//! std.ArrayList is the basis, and it's a really strong basis
//! because it provides the precise api that we need. The
//! problem, which needs to be validated with benchmarking, is
//! that ArrayList most likely will do N-squared copies as it
//! grows.

const ArrayListBuffer = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const Buffer = @import("../Buffer.zig");
const testing = std.testing;

allocator: Allocator,
list: std.ArrayList(u8) = .empty,

pub fn init(allocator: Allocator) ArrayListBuffer {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *ArrayListBuffer) void {
    self.list.deinit(self.allocator);
    self.* = undefined;
}

pub fn interface(self: *ArrayListBuffer) Buffer {
    return .{ .ptr = self, .vtable = &.{
        .readPositional = readPositional,
        .writePositional = writePositional,
        .sync = sync,
        .getSize = getSize,
        .resize = resize,
        .close = deinit,
    } };
}

fn readPositional(ptr: *anyopaque, buffer: []u8, offset: u64) Buffer.ReadError!usize {
    const self: *ArrayListBuffer = @ptrCast(@alignCast(ptr));
    const src = self.list.items[@intCast(offset)..][0..buffer.len];
    // safety: The vtable's contract is that buffer and offset are clamped to
    // the bounds of [0..getSize()].
    @memcpy(buffer, src);
    return buffer.len;
}

test readPositional {
    var a = ArrayListBuffer.init(testing.allocator);
    defer a.deinit();
    try resize(&a, 1024);

    var content: [512]u8 = @splat(99);
    _ = try writePositional(&a, &content, 100);
    var actual: [512]u8 = undefined;

    const n = try readPositional(&a, &actual, 100);
    // Only write to the specified area, and write the whole thing.
    try testing.expectEqual(512, n);
    try testing.expectEqualSlices(u8, &content, &actual);
}

fn writePositional(ptr: *anyopaque, buffer: []const u8, offset: u64) Buffer.WriteError!usize {
    const self: *ArrayListBuffer = @ptrCast(@alignCast(ptr));
    const dst = self.list.items[@intCast(offset)..][0..buffer.len];
    // safety: The vtable's contract is that buffer and offset are within
    // the bounds of [0..getSize()].
    @memcpy(dst, buffer);
    return buffer.len;
}

test writePositional {
    var a = ArrayListBuffer.init(testing.allocator);
    defer a.deinit();
    try resize(&a, 1024);

    var content: [512]u8 = @splat(99);

    // Only write to the specified area, and write the whole thing.
    const n = try writePositional(&a, &content, 100);
    try testing.expectEqual(512, n);
    try testing.expect(std.mem.allEqual(u8, a.list.items[0..100], 0));
    try testing.expect(std.mem.allEqual(u8, a.list.items[100..612], 99));
    try testing.expect(std.mem.allEqual(u8, a.list.items[612..1024], 0));
}

fn sync(_: *anyopaque) Buffer.SyncError!void {}

fn getSize(ptr: *anyopaque) usize {
    const self: *ArrayListBuffer = @ptrCast(@alignCast(ptr));
    return self.list.items.len;
}

test getSize {
    var a = ArrayListBuffer.init(testing.allocator);
    defer a.deinit();
    var rand = std.Random.DefaultPrng.init(33);
    for (0..100) |_| {
        const new_size = rand.random().intRangeAtMost(usize, 0, 1024);
        try resize(&a, new_size);

        // Track the sizes as we grow and shrink.
        try testing.expectEqual(new_size, getSize(&a));
    }
}

fn resize(ptr: *anyopaque, new_size: usize) Buffer.ResizeError!void {
    const self: *ArrayListBuffer = @ptrCast(@alignCast(ptr));
    const old_size = self.list.items.len;
    try self.list.resize(self.allocator, new_size);
    if (old_size < new_size) {
        @memset(self.list.items[old_size..new_size], 0);
    }
}

test resize {
    var a = ArrayListBuffer.init(testing.allocator);
    defer a.deinit();
    var rand = std.Random.DefaultPrng.init(33);
    for (0..100) |_| {
        const sentinel = rand.random().intRangeAtMost(u8, 1, 255);
        @memset(a.list.items, sentinel);
        const old_size = a.list.items.len;
        const new_size = rand.random().intRangeAtMost(usize, 0, 1024);
        try resize(&a, new_size);
        if (old_size < new_size) {
            // Make sure we zero the grown area, but that we don't touch
            // the area that we didn't grow.
            try testing.expect(std.mem.allEqual(u8, a.list.items[0..old_size], sentinel));
            try testing.expect(std.mem.allEqual(u8, a.list.items[old_size..], 0));
        }
    }
}
