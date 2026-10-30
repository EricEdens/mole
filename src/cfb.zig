const std = @import("std");
const Allocator = std.mem.Allocator;

const ByteSource = @import("io.zig").ByteSource;
pub const Cfb = @import("cfb/Cfb.zig");
const Difat = @import("cfb/Difat.zig");
const Directory = @import("cfb/Directory.zig");
const Fat = @import("cfb/Fat.zig");
const MiniFat = @import("cfb/MiniFat.zig");
const SectorNumber = @import("cfb/SectorNumber.zig").SectorNumber;

pub fn open(source: ByteSource) !Cfb {
    const h = source.readValue(Cfb.Header, 0) catch |err| {
        switch (err) {
            error.EndOfStream => return error.HeaderEndOfStream,
            error.ReadFailed => return error.HeaderReadFailed,
        }
    };
    const cfb: Cfb = .{
        .source = source,
        .version = try h.validate(),
        .first_dir = .fromInt(h.first_dir),
        .first_mini_fat = .fromInt(h.first_mini),
        .first_difat = .fromInt(h.first_difat),
        .num_fat = h.num_fat,
        .difat = @bitCast(h.difat),
    };
    try Difat.validate(&cfb, h.num_difat);
    try Fat.validate(&cfb);
    try Directory.validate(&cfb, h.num_dirs);
    try MiniFat.validate(&cfb, h.num_mini);

    if (cfb.version == .v3) {
        var fat: Fat = .init(&cfb);
        _ = try fat.chainLength(cfb.first_dir);
    }
    var dir: Directory = .init(&cfb);
    if ((try dir.directoryEntry(.root)).obj_type != 5) return error.BadRootType;
    return cfb;
}

comptime {
    _ = @import("cfb/Difat.zig");
    _ = @import("cfb/Directory.zig");
    _ = @import("cfb/Fat.zig");
    _ = @import("cfb/MiniFat.zig");
    _ = @import("cfb/MiniStream.zig");
    _ = @import("cfb/Name.zig");
}

const testing = std.testing;

pub fn testOpen(src: *ByteSource.Memory) !Cfb {
    return open(src.byteSource());
}

test "open empty v3 Windows 11" {
    var src: ByteSource.Memory = try .fromPath(testing.io, "samples/00-empty-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();

    const cfb = try testOpen(&src);
    try testing.expectEqual(.v3, cfb.version);
    try testing.expectEqual(SectorNumber.fromInt(1), cfb.first_dir);
    try testing.expectEqual(SectorNumber.endofchain, cfb.first_mini_fat);
    try testing.expectEqual(SectorNumber.endofchain, cfb.first_difat);
    try testing.expectEqualSlices(SectorNumber, &(.{SectorNumber.fromInt(0)} ++ @as([108]SectorNumber, @splat(.free))), &cfb.difat);
}

test "read MS-CFB section 3 example" {
    var src: ByteSource.Memory = try .fromPath(testing.io, "samples/01-ms-cfb/ms-cfb.cfb");
    defer src.deinit();
    try testing.expectEqual(3072, src.byteSource().size());

    const cfb = try testOpen(&src);
    try testing.expectEqual(.v3, cfb.version);
    try testing.expectEqual(SectorNumber.fromInt(1), cfb.first_dir);
    try testing.expectEqual(SectorNumber.fromInt(2), cfb.first_mini_fat);
    try testing.expectEqual(SectorNumber.endofchain, cfb.first_difat);
    try testing.expectEqualSlices(SectorNumber, &(.{SectorNumber.fromInt(0)} ++ @as([108]SectorNumber, @splat(.free))), &cfb.difat);
    try testing.expectEqual(512, cfb.bytesPerSector());
    try testing.expectEqual(64, cfb.bytesPerMiniSector());
}

fn validHeader() ![1536]u8 {
    var src: ByteSource.Memory = try .fromPath(testing.io, "samples/00-empty-v3/win11-24h2-26100.9549-amd64.cfb");
    defer src.deinit();
    var h: [1536]u8 = undefined;
    try src.byteSource().readAt(&h, 0);
    return h;
}

test "given a header shorter than 512 bytes, open returns HeaderEndOfStream" {
    const h = try validHeader();
    var src: ByteSource.Memory = .fromSlice(h[0..511]);
    try testing.expectError(error.HeaderEndOfStream, testOpen(&src));
}

test "given a bad signature, open returns SignatureMismatch" {
    var h = try validHeader();
    h[7] = h[7] + 2;
    var src: ByteSource.Memory = .fromSlice(&h);
    try testing.expectError(error.SignatureMismatch, testOpen(&src));
}

test "given a major version above 4, open returns VersionGreaterThan4" {
    var h = try validHeader();
    for ([_]u16{ 5, 0xffff }) |v| {
        std.mem.writeInt(u16, h[0x1a..][0..2], v, .little);
        var src: ByteSource.Memory = .fromSlice(&h);
        try testing.expectError(error.VersionGreaterThan4, testOpen(&src));
    }
}

test "given any major version up to 4, open takes the version from the sector shift" {
    var h = try validHeader();
    for ([_]u16{ 0, 2, 4 }) |v| {
        std.mem.writeInt(u16, h[0x1a..][0..2], v, .little);
        var src: ByteSource.Memory = .fromSlice(&h);
        try testing.expectEqual(.v3, (try testOpen(&src)).version);
    }
}

test "given any byte order, open succeeds" {
    var h = try validHeader();
    for ([_]u16{ 0, 0xfeff }) |v| {
        std.mem.writeInt(u16, h[0x1c..][0..2], v, .little);
        var src: ByteSource.Memory = .fromSlice(&h);
        _ = try testOpen(&src);
    }
}
