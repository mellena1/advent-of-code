const std = @import("std");
const zbench = @import("zbench");
const day02 = @import("day02");

// Global state to hold the test data (loaded once)
var test_ranges: []day02.IDRange = undefined;

fn benchPart1(allocator: std.mem.Allocator) void {
    _ = day02.sum_invalid_ids(allocator, test_ranges, day02.number_is_double_sequence) catch unreachable;
}

fn benchPart2(allocator: std.mem.Allocator) void {
    _ = day02.sum_invalid_ids(allocator, test_ranges, day02.number_is_any_number_of_repeats) catch unreachable;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    var ranges = try day02.read_file(allocator, "input.txt");
    defer ranges.deinit(allocator);

    test_ranges = ranges.items;

    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    try bench.add("Part 1", benchPart1, .{});
    try bench.add("Part 2", benchPart2, .{});

    var buf: [4096]u8 = undefined;
    const stdout = std.fs.File.stdout();
    var writer = stdout.writer(&buf);
    const writer_ptr = &writer.interface;
    try bench.run(writer_ptr);
    try writer_ptr.flush();
}
