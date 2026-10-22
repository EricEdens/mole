const std = @import("std");
const Io = std.Io;

const stg = @import("stg");

pub fn main(init: std.process.Init) !void {
    const args = (try init.minimal.args.toSlice(init.arena.allocator()))[1..];

    const f = try Io.Dir.cwd().openFile(init.io, args[0], .{});
    defer f.close(init.io);
    var b: stg.Buffer.ArrayListBuffer = .init(init.arena.allocator());

    const stat = try f.stat(init.io);
    try b.buffer().resize(stat.size);
    const read = try f.readPositionalAll(init.io, b.list.items, 0);
    std.debug.assert(stat.size == read);

    const cfb = try stg.cfb.Cfb.open(b.buffer());
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
