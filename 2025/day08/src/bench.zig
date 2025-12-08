const std = @import("std");
const zbench = @import("zbench");
const day08 = @import("day08");

// Global state to hold the test data (loaded once)
var test_boxes: []day08.JunctionBox = undefined;

fn benchPart1(allocator: std.mem.Allocator) void {
    _ = day08.part1(allocator, test_boxes, 10) catch unreachable;
}

fn benchPart2(allocator: std.mem.Allocator) void {
    _ = day08.part2(allocator, test_boxes) catch unreachable;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    var boxes = try day08.read_file(allocator, "input.txt");
    defer boxes.deinit(allocator);

    test_boxes = try allocator.dupe(day08.JunctionBox, boxes.items);
    defer allocator.free(test_boxes);

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
