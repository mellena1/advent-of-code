const std = @import("std");

pub const fileparse = @import("fileparse.zig");
pub const args = @import("args.zig");
pub const slices = @import("slices.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
