const std = @import("std");
const zbench = @import("zbench");
const day07 = @import("day07");

// Global state to hold the test data (loaded once)
var test_grid: day07.Grid = undefined;

fn benchPart1(allocator: std.mem.Allocator) void {
    _ = day07.Grid.count_splits(test_grid, allocator) catch unreachable;
}

fn benchPart2(allocator: std.mem.Allocator) void {
    _ = day07.Grid.count_timelines(test_grid, allocator) catch unreachable;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    const grid = try day07.read_file(allocator, "input.txt");
    defer grid.deinit(allocator);

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
