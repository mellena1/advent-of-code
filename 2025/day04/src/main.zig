const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    var grid = try read_file(allocator, filename);
    defer grid.deinit();

    std.debug.print("Part 1: {d}\n", .{grid.accessible_rolls()});
    std.debug.print("Part 2: {d}\n", .{try grid.accessible_rolls_if_removing()});
}

const GridSpot = enum {
    Nothing,
    RollOfPaper,
};

const Grid = struct {
    gpa: std.mem.Allocator,
    grid: []const []const GridSpot,

    pub fn deinit(self: *Grid) void {
        for (self.grid) |row| {
            self.gpa.free(row);
        }
        self.gpa.free(self.grid);
    }

    pub fn accessible_rolls(self: Grid) u64 {
        var rolls: u64 = 0;

        for (self.grid, 0..) |row, y| {
            for (row, 0..) |spot, x| {
                if (spot == GridSpot.RollOfPaper and self.number_of_adjacent_rolls(x, y) < 4) {
                    rolls += 1;
                }
            }
        }

        return rolls;
    }

    pub fn accessible_rolls_if_removing(self: Grid) !u64 {
        var rolls: u64 = 0;
        var grid: Grid = self;

        var i: u64 = 0;
        while (true) : (i += 1) {
            const new_vals = try grid.remove_accessible_rolls();
            // don't want to deinit the parent grid
            if (i > 0) {
                grid.deinit();
            }

            rolls += new_vals.num_removed;
            grid = new_vals.new_grid;

            if (new_vals.num_removed == 0) {
                break;
            }
        }

        // last clean up
        if (i > 0) {
            grid.deinit();
        }

        return rolls;
    }

    fn remove_accessible_rolls(self: Grid) !struct { new_grid: Grid, num_removed: u64 } {
        var rolls: u64 = 0;

        const new_grid = try self.clone_grid();

        for (self.grid, 0..) |row, y| {
            for (row, 0..) |spot, x| {
                if (spot == GridSpot.RollOfPaper and self.number_of_adjacent_rolls(x, y) < 4) {
                    new_grid[y][x] = GridSpot.Nothing;
                    rolls += 1;
                }
            }
        }

        return .{
            .new_grid = Grid{
                .gpa = self.gpa,
                .grid = new_grid,
            },
            .num_removed = rolls,
        };
    }

    fn clone_grid(self: Grid) ![][]GridSpot {
        const new_grid = try self.gpa.alloc([]GridSpot, self.grid.len);
        errdefer self.gpa.free(new_grid);

        for (self.grid, 0..) |row, i| {
            new_grid[i] = try self.gpa.alloc(GridSpot, row.len);
            errdefer self.gpa.free(new_grid[i]);

            for (row, 0..) |v, j| {
                new_grid[i][j] = v;
            }
        }

        return new_grid;
    }

    /// Helper to get what is at a given tile,
    /// if out of bounds it will just return GridSpot.Nothing
    fn get(self: Grid, x: i64, y: i64) GridSpot {
        if (x < 0 or x >= self.grid[0].len or y < 0 or y >= self.grid.len) {
            return GridSpot.Nothing;
        }

        return self.grid[@intCast(y)][@intCast(x)];
    }

    fn number_of_adjacent_rolls(self: Grid, x: u64, y: u64) u64 {
        var num: u64 = 0;

        var i: i64 = -1;
        while (i <= 1) : (i += 1) {
            var j: i64 = -1;
            while (j <= 1) : (j += 1) {
                if (i == 0 and j == 0) {
                    continue;
                }
                if (self.get(@as(i64, @intCast(x)) + i, @as(i64, @intCast(y)) + j) == GridSpot.RollOfPaper) {
                    num += 1;
                }
            }
        }

        return num;
    }
};

fn read_file(gpa: std.mem.Allocator, filename: []const u8) !Grid {
    const Parser = struct {
        fn parse(_: std.mem.Allocator, c: u8) !GridSpot {
            return switch (c) {
                '.' => GridSpot.Nothing,
                '@' => GridSpot.RollOfPaper,
                else => error.UnknownChar,
            };
        }
    };

    const fileparser = utils.fileparse.TwoDimensionalArrayParser(GridSpot, Parser.parse).init(gpa);

    var grid_as_lists = try fileparser.parse(filename);

    return Grid{
        .gpa = gpa,
        .grid = try utils.slices.two_dimensional_arraylists_to_slices(gpa, GridSpot, &grid_as_lists),
    };
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var grid = try read_file(allocator, "example.txt");
    defer grid.deinit();

    try std.testing.expectEqual(13, grid.accessible_rolls());
    try std.testing.expectEqual(43, try grid.accessible_rolls_if_removing());
}
