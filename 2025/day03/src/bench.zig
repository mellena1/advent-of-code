const std = @import("std");
const zbench = @import("zbench");
const day03 = @import("day03");

// Global state to hold the test data (loaded once)
var test_battery_banks: []day03.BatteryBank = undefined;

fn benchPart1(allocator: std.mem.Allocator) void {
    _ = allocator;
    _ = day03.find_sum_of_joltages(test_battery_banks, 2);
}

fn benchPart2(allocator: std.mem.Allocator) void {
    _ = allocator;
    _ = day03.find_sum_of_joltages(test_battery_banks, 12);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    var battery_banks = try day03.read_file(allocator, "input.txt");
    defer day03.deinit_banks(allocator, &battery_banks);

    test_battery_banks = battery_banks.items;

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
