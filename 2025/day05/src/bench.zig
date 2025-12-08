const std = @import("std");
const zbench = @import("zbench");
const day05 = @import("day05");

// Global state to hold the test data (loaded once)
var test_ingredients_list: day05.IngredientsList = undefined;

fn benchPart1(allocator: std.mem.Allocator) void {
    _ = allocator;
    _ = test_ingredients_list.num_fresh_ingredients();
}

fn benchPart2(allocator: std.mem.Allocator) void {
    _ = test_ingredients_list.total_num_ids_in_ranges(allocator) catch unreachable;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load data once for benchmarks (without file I/O in benchmark loop)
    const ingredients_list = try day05.read_file(allocator, "input.txt");
    defer ingredients_list.deinit(allocator);

    test_ingredients_list = ingredients_list;

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
