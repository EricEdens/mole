const DirectoryEntry = @This();

const std = @import("std");

name: [32]u16,
name_len: u16,
obj_type: u8,
color_flag: u8,
left_sib: u32,
right_sib: u32,
child: u32,
clsid: [16]u8,
state_bits: u32,
creation_time: u64,
modified_time: u64,
start_sector: u32,
stream_size: u64,
