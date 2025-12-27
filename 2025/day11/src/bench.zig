const std = @import("std");
const zbench = @import("zbench");
const day11 = @import("day11");

// Global state to hold the test data (loaded once)
var test_server_rack: day11.ServerRack = undefined;

fn benchPart1(_: std.mem.Allocator) void {
    _ = day11.part1(test_server_rack) catch unreachable;
}

fn benchPart2(_: std.mem.Allocator) void {
    _ = day11.part2(test_server_rack) catch unreachable;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    test_server_rack = try day11.read_file(allocator, "input.txt");
    defer test_server_rack.deinit();

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
