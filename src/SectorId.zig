pub const SectorId = enum(u32) {
    max_reg = 0xfffffffa,
    difat = 0xfffffffc,
    fat = 0xfffffffd,
    endofchain = 0xfffffffe,
    free = 0xffffffff,
    _,

    pub fn fromInt(value: u32) SectorId {
        return @fromBackingInt(value);
    }

    pub fn is_regular(s: SectorId) bool {
        return @backingInt(s) <= 0xfffffffa;
    }
};
