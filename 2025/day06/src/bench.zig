const std = @import("std");
const zbench = @import("zbench");
const day06 = @import("day06");

// Global state to hold the test data (loaded once)
var test_formulas_p1: []day06.Formula = undefined;
var test_formulas_p2: []day06.Formula = undefined;

fn benchPart1(allocator: std.mem.Allocator) void {
    _ = allocator;
    _ = day06.sum_formulas(test_formulas_p1);
}

fn benchPart2(allocator: std.mem.Allocator) void {
    _ = allocator;
    _ = day06.sum_formulas(test_formulas_p2);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    var formulas_p1 = try day06.read_file_part_1(allocator, "input.txt");
    defer day06.deinit_formulas(allocator, &formulas_p1);

    var formulas_p2 = try day06.read_file_part_2(allocator, "input.txt");
    defer day06.deinit_formulas(allocator, &formulas_p2);

    test_formulas_p1 = formulas_p1.items;
    test_formulas_p2 = formulas_p2.items;

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
