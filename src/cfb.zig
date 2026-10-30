const std = @import("std");
const Allocator = std.mem.Allocator;

const ByteSource = @import("io.zig").ByteSource;
pub const Cfb = @import("cfb/Cfb.zig");
const SectorNumber = @import("cfb/SectorNumber.zig").SectorNumber;

const OpenError = error{
    OutOfMemory,
    ReadFailed,
    ParseCfb,

    /// STG_E_DOCFILECORRUPT
    CorruptCfb,

    /// The major version is larger than 4.
    ///
    /// This check is locked to `STG_E_OLDDLL`.
    UnsupportedVersion,

    /// The file isn't a CFB!
    ///
    /// Concretely, the signature doesn't match, or the header has fewer
    /// than 512 bytes.
    ///
    /// This check is locked to `STG_E_FILEALREADYEXISTS`.
    NotCfb,
};

pub fn open(source: ByteSource) OpenError!Cfb {
    const h = source.readValue(Cfb.Header, 0) catch |err| {
        switch (err) {
            error.EndOfStream => return error.NotCfb,
            error.ReadFailed => return error.ReadFailed,
        }
    };

    const cfb: Cfb = .{
        .source = source,
        .version =  try h.validate(),
        .first_dir = .fromInt(h.first_dir),
        .first_mini_fat = .fromInt(h.first_mini),
        .first_difat = .fromInt(h.first_difat),
        .difat = @bitCast(h.difat),
    };

    // Phase 4: Declared lengths.
    const total_sectors = source.size() / cfb.bytesPerSector() -| 1;
    const header_fat = @min(h.num_fat, cfb.difat.len);

    //  - 4a: NumDirs
    if (cfb.version == .v3 and h.num_dirs != 0) return error.CorruptCfb;
    if (cfb.version == .v4 and (h.num_dirs == 0 or h.num_dirs > total_sectors)) return error.CorruptCfb;

    //  - 4b: Fat
    if (h.num_fat > total_sectors) return error.CorruptCfb;
    for (cfb.difat[0..header_fat]) |e|
        if (!inFile(e, total_sectors)) return error.CorruptCfb;

    //  - 4c: Difat
    for (cfb.difat[header_fat..]) |e|
        if (e != .free) return error.CorruptCfb;
    if (h.num_fat > cfb.difat.len and h.num_difat == 0) return error.CorruptCfb;
    try chainStart(cfb.first_difat, h.num_difat, total_sectors);

    //  - 4d: Mini
    try chainStart(cfb.first_mini_fat, h.num_mini, total_sectors);

    //  -  4e: FirstDir
    if (!inFile(cfb.first_dir, total_sectors)) return error.CorruptCfb;

    return cfb;
}

fn inFile(sector: SectorNumber, total_sectors: u64) bool {
    return sector.isRegular() and @backingInt(sector) < total_sectors;
}

fn chainStart(first: SectorNumber, num: u32, total_sectors: u64) error{CorruptCfb}!void {
    if (num > total_sectors) return error.CorruptCfb;
    if (num == 0) {
        if (first != .endofchain and first != .free) return error.CorruptCfb;
    } else if (!inFile(first, total_sectors)) return error.CorruptCfb;
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

test "given a header shorter than 512 bytes, open returns NotCfb" {
    const h = try validHeader();
    var src: ByteSource.Memory = .fromSlice(h[0..511]);
    try testing.expectError(error.NotCfb, testOpen(&src));
}

test "given a bad signature, open returns NotCfb" {
    var h = try validHeader();
    h[7] = h[7] + 2;
    var src: ByteSource.Memory = .fromSlice(&h);
    try testing.expectError(error.NotCfb, testOpen(&src));
}

test "given a major version above 4, open returns UnsupportedVersion" {
    var h = try validHeader();
    for ([_]u16{ 5, 0xffff }) |v| {
        std.mem.writeInt(u16, h[0x1a..][0..2], v, .little);
        var src: ByteSource.Memory = .fromSlice(&h);
        try testing.expectError(error.UnsupportedVersion, testOpen(&src));
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
