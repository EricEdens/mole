pub const StreamId = enum(u32) {
    root = 0,
    max_reg = 0xfffffffa,
    nostream = 0xffffffff,
    _,

    pub fn is_regular(s: StreamId) bool {
        return @backingInt(s) <= 0xfffffffa;
    }
};
