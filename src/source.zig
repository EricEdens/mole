//! Our version of 'ILockBytes', read-only.
//!
//! https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-ilockbytes
const std = @import("std");

const Io = std.Io;
const PageAllocator = std.heap.PageAllocator;
const page_size_min = std.heap.page_size_min;

pub const Source = union(enum) {
    slice: []const u8,
    mapped: []align(page_size_min) u8,

    pub const FromFileError = Io.File.StatError || Io.File.ReadPositionalError ||
        error{ FileTooBig, OutOfMemory, EndOfStream };
    pub const FromPathError = Io.File.OpenError || FromFileError;
    pub const ReadError = error{};

    pub fn fromSlice(b: []const u8) Source {
        return .{ .slice = b };
    }

    pub fn fromFile(io: Io, file: Io.File) FromFileError!Source {
        const len = std.math.cast(usize, (try file.stat(io)).size) orelse return error.FileTooBig;
        if (len == 0) return .{ .slice = &.{} };
        const ptr = PageAllocator.map(len, .fromByteUnits(page_size_min)) orelse return error.OutOfMemory;
        const buf: []align(page_size_min) u8 = @alignCast(ptr[0..len]);
        errdefer PageAllocator.unmap(buf);

        if (try file.readPositionalAll(io, buf, 0) != len) return error.EndOfStream;
        return .{ .mapped = buf };
    }

    pub fn fromPath(io: Io, path: []const u8) FromPathError!Source {
        const f = try Io.Dir.cwd().openFile(io, path, .{});
        defer f.close(io);
        return fromFile(io, f);
    }

    pub fn deinit(self: *Source) void {
        switch (self.*) {
            .slice => {},
            .mapped => |m| PageAllocator.unmap(m),
        }
        self.* = undefined;
    }

    pub fn size(self: Source) u64 {
        return switch (self) {
            inline else => |b| b.len,
        };
    }

    /// Short only at EOF.
    pub fn readAt(self: Source, buff: []u8, offset: u64) ReadError!usize {
        const b: []const u8 = switch (self) {
            inline else => |b| b,
        };
        if (offset >= b.len) return 0;
        const src = b[@intCast(offset)..];
        const n = @min(buff.len, src.len);
        @memcpy(buff[0..n], src[0..n]);
        return n;
    }

    const testing = std.testing;

    test readAt {
        const s: Source = .fromSlice("abcdef");
        var b: [4]u8 = undefined;
        try testing.expectEqual(4, try s.readAt(&b, 1));
        try testing.expectEqualSlices(u8, "bcde", &b);
        try testing.expectEqual(2, try s.readAt(&b, 4));
        try testing.expectEqualSlices(u8, "ef", b[0..2]);
        try testing.expectEqual(0, try s.readAt(&b, 6));
        try testing.expectEqual(0, try s.readAt(&b, 100));
    }

    test fromFile {
        var tmp = testing.tmpDir(.{});
        defer tmp.cleanup();

        for ([_]usize{ 0, 1, 4096, (3 << 20) + 17 }) |len| {
            const expected = try testing.allocator.alloc(u8, len);
            defer testing.allocator.free(expected);
            var rand = std.Random.DefaultPrng.init(len);
            rand.random().bytes(expected);
            try tmp.dir.writeFile(testing.io, .{ .sub_path = "f", .data = expected });

            const f = try tmp.dir.openFile(testing.io, "f", .{});
            defer f.close(testing.io);
            var s: Source = try .fromFile(testing.io, f);
            defer s.deinit();
            const actual = try testing.allocator.alloc(u8, len);
            defer testing.allocator.free(actual);
            try testing.expectEqual(len, try s.readAt(actual, 0));
            try testing.expectEqualSlices(u8, expected, actual);
        }
    }
};
