const std = @import("std");
const zbench = @import("zbench");
const day01 = @import("day01");

// Global state to hold the test data (loaded once)
var test_turns: []day01.Turn = undefined;

fn benchPart1(allocator: std.mem.Allocator) void {
    _ = allocator;
    var dial = day01.Dial{};
    dial.execute_turns(test_turns);
    _ = dial.times_at_zero;
}

fn benchPart2(allocator: std.mem.Allocator) void {
    _ = allocator;
    var dial = day01.Dial{};
    dial.execute_turns(test_turns);
    _ = dial.times_passing_zero;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    var turns = try day01.read_file(allocator, "input.txt");
    defer turns.deinit(allocator);

    test_turns = turns.items;

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
