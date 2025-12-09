const std = @import("std");
const zbench = @import("zbench");
const day09 = @import("day09");

// Global state to hold the test data (loaded once)
var test_grid: day09.Grid = undefined;

fn benchPart1(_: std.mem.Allocator) void {
    _ = test_grid.biggest_rect_area() catch unreachable;
}

fn benchPart2(_: std.mem.Allocator) void {
    _ = test_grid.biggest_rect_with_red_and_green() catch unreachable;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    test_grid = try day09.read_file(allocator, "input.txt");
    defer test_grid.deinit();

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
