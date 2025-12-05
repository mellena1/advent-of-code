const std = @import("std");

pub fn two_dimensional_arraylists_to_slices(gpa: std.mem.Allocator, comptime T: type, grid: *std.ArrayList(std.ArrayList(T))) ![]const []const T {
    var outer_slice = try gpa.alloc([]T, grid.items.len);
    defer grid.deinit(gpa);

    for (grid.items, 0..) |*row, i| {
        outer_slice[i] = try row.toOwnedSlice(gpa);
        defer row.deinit(gpa);
    }

    return outer_slice;
}

test "arraylists to slices works" {
    const allocator = std.testing.allocator;

    var grid = std.ArrayList(std.ArrayList(u8)).empty;
    errdefer grid.deinit(allocator);

    var row1 = std.ArrayList(u8).empty;
    try row1.appendSlice(allocator, &[_]u8{ 1, 2, 3, 4, 5 });
    var row2 = std.ArrayList(u8).empty;
    try row2.appendSlice(allocator, &[_]u8{ 5, 4, 3, 2, 1 });

    try grid.append(allocator, row1);
    try grid.append(allocator, row2);

    const actual = try two_dimensional_arraylists_to_slices(allocator, u8, &grid);
    defer {
        for (actual) |row| {
            allocator.free(row);
        }
        allocator.free(actual);
    }

    const expected: []const []const u8 = &.{
        &.{ 1, 2, 3, 4, 5 },
        &.{ 5, 4, 3, 2, 1 },
    };
    try std.testing.expectEqualDeep(expected, actual);
}
