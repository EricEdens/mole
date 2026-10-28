//! Our version of 'ILockBytes', read-only.
//!
//! https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-ilockbytes
const ByteSource = @This();

const std = @import("std");

const Io = std.Io;
const page_size_min = std.heap.page_size_min;
const PageAllocator = std.heap.PageAllocator;

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    size: *const fn (ctx: *anyopaque) u64,
    readAt: *const fn (ctx: *anyopaque, buf: []u8, offset: u64) error{ReadFailed}!usize,
};

pub const ReadError = error{ ReadFailed, EndOfStream };

pub fn size(self: ByteSource) u64 {
    return self.vtable.size(self.ptr);
}

pub fn readAt(self: ByteSource, buf: []u8, offset: u64) ReadError!void {
    const len = self.size();
    if (offset > len or buf.len > len - offset) return error.EndOfStream;
    var n: usize = 0;
    while (n < buf.len) {
        const r = try self.vtable.readAt(self.ptr, buf[n..], offset + n);
        std.debug.assert(r != 0);
        n += r;
    }
}

pub fn readValue(self: ByteSource, comptime T: type, offset: u64) ReadError!T {
    comptime switch (@typeInfo(T)) {
        .int, .@"enum" => {},
        .array => |a| if (@typeInfo(a.child) != .int) @compileError(@typeName(T) ++ " is not an array of ints"),
        .@"struct" => |s| if (s.layout != .@"extern") @compileError(@typeName(T) ++ " is not extern"),
        else => @compileError(@typeName(T) ++ " is not an int, enum, int array or extern struct"),
    };
    var ret: T = undefined;
    try self.readAt(std.mem.asBytes(&ret), offset);
    if (@import("builtin").cpu.arch.endian() == .big) std.mem.byteSwap(T, &ret);
    return ret;
}

pub const Memory = union(enum) {
    slice: []const u8,
    mapped: []align(page_size_min) u8,

    pub const FromFileError = Io.File.StatError || Io.File.ReadPositionalError ||
        error{ FileTooBig, OutOfMemory, EndOfStream };
    pub const FromPathError = Io.File.OpenError || FromFileError;

    pub fn fromSlice(b: []const u8) Memory {
        return .{ .slice = b };
    }

    pub fn fromFile(io: Io, file: Io.File) FromFileError!Memory {
        const len = std.math.cast(usize, (try file.stat(io)).size) orelse return error.FileTooBig;
        if (len == 0) return .{ .slice = &.{} };
        const ptr = PageAllocator.map(len, .fromByteUnits(page_size_min)) orelse return error.OutOfMemory;
        const buf: []align(page_size_min) u8 = @alignCast(ptr[0..len]);
        errdefer PageAllocator.unmap(buf);

        if (try file.readPositionalAll(io, buf, 0) != len) return error.EndOfStream;
        return .{ .mapped = buf };
    }

    pub fn fromPath(io: Io, path: []const u8) FromPathError!Memory {
        const f = try Io.Dir.cwd().openFile(io, path, .{});
        defer f.close(io);
        return fromFile(io, f);
    }

    pub fn deinit(self: *Memory) void {
        switch (self.*) {
            .slice => {},
            .mapped => |m| PageAllocator.unmap(m),
        }
        self.* = undefined;
    }

    pub fn byteSource(self: *Memory) ByteSource {
        return .{ .ptr = self, .vtable = &.{ .size = sizeFn, .readAt = readAtFn } };
    }

    fn bytes(ctx: *anyopaque) []const u8 {
        const self: *Memory = @ptrCast(@alignCast(ctx));
        return switch (self.*) {
            inline else => |b| b,
        };
    }

    fn sizeFn(ctx: *anyopaque) u64 {
        return bytes(ctx).len;
    }

    fn readAtFn(ctx: *anyopaque, buf: []u8, offset: u64) error{ReadFailed}!usize {
        @memcpy(buf, bytes(ctx)[@intCast(offset)..][0..buf.len]);
        return buf.len;
    }
};

const testing = std.testing;

const SlowSource = struct {
    b: []const u8,

    fn byteSource(self: *SlowSource) ByteSource {
        return .{ .ptr = self, .vtable = &.{ .size = sizeFn, .readAt = readAtFn } };
    }

    fn sizeFn(ctx: *anyopaque) u64 {
        const self: *SlowSource = @ptrCast(@alignCast(ctx));
        return self.b.len;
    }

    fn readAtFn(ctx: *anyopaque, buf: []u8, offset: u64) error{ReadFailed}!usize {
        const self: *SlowSource = @ptrCast(@alignCast(ctx));
        buf[0] = self.b[@intCast(offset)];
        return 1;
    }
};

test readAt {
    var t: SlowSource = .{ .b = "abcdef" };
    const s = t.byteSource();
    var b: [4]u8 = undefined;
    try s.readAt(&b, 1);
    try testing.expectEqualSlices(u8, "bcde", &b);
    try s.readAt(b[0..2], 4);
    try testing.expectEqualSlices(u8, "ef", b[0..2]);
    try s.readAt(b[0..0], 6);
    try testing.expectError(error.EndOfStream, s.readAt(&b, 4));
    try testing.expectError(error.EndOfStream, s.readAt(b[0..0], 7));
    try testing.expectError(error.EndOfStream, s.readAt(&b, std.math.maxInt(u64)));
}

test readValue {
    var t: SlowSource = .{ .b = "\x01\x02\x03\x04\x05" };
    const s = t.byteSource();
    try testing.expectEqual(0x05040302, try s.readValue(u32, 1));
    try testing.expectError(error.EndOfStream, s.readValue(u32, 2));
}

test "Memory.fromFile" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    for ([_]usize{ 0, 1, 4096 }) |len| {
        const expected = try testing.allocator.alloc(u8, len);
        defer testing.allocator.free(expected);
        var rand = std.Random.DefaultPrng.init(len);
        rand.random().bytes(expected);
        try tmp.dir.writeFile(testing.io, .{ .sub_path = "f", .data = expected });

        const f = try tmp.dir.openFile(testing.io, "f", .{});
        defer f.close(testing.io);
        var m: Memory = try .fromFile(testing.io, f);
        defer m.deinit();
        const s = m.byteSource();
        try testing.expectEqual(len, s.size());
        const actual = try testing.allocator.alloc(u8, len);
        defer testing.allocator.free(actual);
        try s.readAt(actual, 0);
        try testing.expectEqualSlices(u8, expected, actual);
    }
}
