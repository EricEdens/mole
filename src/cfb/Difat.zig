const Difat = @This();

const Cfb = @import("../cfb.zig").Cfb;
const SectorId = @import("../cfb.zig").SectorId;

cfb: *const Cfb,

/// The DIFAT's own sector IDs.
///
/// This occurs when the DIFAT spills beyond the first 109
/// entries of header.
pub fn sectorIds(self: Difat) Iterator {
    return .{
        .n = self.cfb.header.firstDifat(),
        .cfb = self.cfb,
    };
}

pub const Iterator = struct {
    /// The next sectorId to return.
    n: SectorId,
    cfb: *const Cfb,

    pub fn next(self: *Iterator) Cfb.ReadError!?SectorId {
        if (!self.n.is_regular()) return null;
        const current = self.n;
        const offset = self.cfb.sectorSize() - @sizeOf(u32);
        self.n = SectorId.fromInt(try self.cfb.readWithinSector(u32, current, offset));
        return current;
    }
};

/// Iterate over FAT sector numbers.
///
/// The first element is difat[0] from the CFB header.
pub fn fatSectorIds(self: Difat) FatIterator {
    return .{
        .difat = self.sectorIds(),
        .cfb = self.cfb,
    };
}

pub const FatIterator = struct {
    difat: Iterator,
    cfb: *const Cfb,
    done: bool = false,

    // Phase 1: The 109 in the header.
    header_index: usize = 0,

    // Phase 2: Reading the Fat pages that are in the table.
    sector: ?SectorId = null,
    // Offset within the fat page.
    offset: u32 = 0,

    pub fn next(self: *FatIterator) Cfb.ReadError!?SectorId {
        if (self.done) return null;
        const id = if (self.header_index < self.cfb.header.difat.len) blk: {
            const id = SectorId.fromInt(self.cfb.header.difat[self.header_index]);
            self.header_index += 1;
            break :blk id;
        } else blk: {
            const last_position_in_sector = self.cfb.sectorSize() - @sizeOf(u32);
            if (self.sector == null or self.offset == last_position_in_sector) {
                self.sector = try self.difat.next();
                self.offset = 0;
            }
            const curr_fat_sector_id = self.sector orelse {
                self.done = true;
                return null;
            };
            const ret = SectorId.fromInt(try self.cfb.readWithinSector(u32, curr_fat_sector_id, self.offset));
            self.offset += @sizeOf(u32);
            break :blk ret;
        };
        if (!id.is_regular()) {
            self.done = true;
            return null;
        }
        return id;
    }
};
