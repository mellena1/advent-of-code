const std = @import("std");
const zbench = @import("zbench");
const day04 = @import("day04");

// Global state to hold the test data (loaded once)
var test_grid: day04.Grid = undefined;

fn benchPart1(allocator: std.mem.Allocator) void {
    _ = allocator;
    _ = test_grid.accessible_rolls();
}

fn benchPart2(allocator: std.mem.Allocator) void {
    _ = allocator;
    _ = test_grid.accessible_rolls_if_removing() catch unreachable;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    var grid = try day04.read_file(allocator, "input.txt");
    defer grid.deinit();

    test_grid = grid;

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
