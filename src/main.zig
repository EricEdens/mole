const std = @import("std");

const stg = @import("stg");

pub fn main(init: std.process.Init) !void {
    const args = (try init.minimal.args.toSlice(init.arena.allocator()))[1..];

    var src: stg.Source = try .fromPath(init.io, args[0]);
    defer src.deinit();

    const cfb = try stg.Cfb.open(src);
    std.debug.print("major={d}\n", .{cfb.header.major_ver});

    var difat = cfb.difat().sectorIds();
    while (try difat.next()) |sector_id| {
        std.debug.print("difat={d}\n", .{sector_id});
    }

    var fat = cfb.difat().fatSectorIds();
    while (try fat.next()) |sector_id| {
        std.debug.print("fat={d}\n", .{sector_id});
    }
}
