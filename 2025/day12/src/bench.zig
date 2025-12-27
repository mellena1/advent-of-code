const std = @import("std");
const zbench = @import("zbench");
const day12 = @import("day12");

// Global state to hold the test data (loaded once)
var test_presents: day12.Presents = undefined;

fn benchPart1(_: std.mem.Allocator) void {
    _ = day12.part1(test_presents) catch unreachable;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    test_presents = try day12.read_file(allocator, "input.txt");
    defer test_presents.deinit();

    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    try bench.add("Part 1", benchPart1, .{});

    var buf: [4096]u8 = undefined;
    const stdout = std.fs.File.stdout();
    var writer = stdout.writer(&buf);
    const writer_ptr = &writer.interface;
    try bench.run(writer_ptr);
    try writer_ptr.flush();
}
