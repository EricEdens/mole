pub const SectorNumber = enum(u32) {
    max_reg = 0xfffffffa,
    difat = 0xfffffffc,
    fat = 0xfffffffd,
    endofchain = 0xfffffffe,
    free = 0xffffffff,
    _,

    pub fn fromInt(value: u32) SectorNumber {
        return @fromBackingInt(value);
    }

    pub fn isRegular(s: SectorNumber) bool {
        return @backingInt(s) <= 0xfffffffa;
    }
};
