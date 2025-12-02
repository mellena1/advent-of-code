const std = @import("std");

/// Gets the input file from cmdline args.
/// Always just assumes that it's the first argument, which is kind of dumb
/// but probably good enough for advent of code purposes.
pub fn get_file_name_from_args(gpa: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    // skip program name
    _ = args.next();

    return args.next() orelse "input.txt";
}
