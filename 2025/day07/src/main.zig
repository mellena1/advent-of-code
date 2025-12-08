const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    const grid = try read_file(allocator, filename);
    defer grid.deinit(allocator);

    std.debug.print("Part 1: {d}\n", .{try grid.count_splits(allocator)});
    std.debug.print("Part 2: {d}\n", .{try grid.count_timelines(allocator)});
}

const GridSpot = enum {
    Start,
    Splitter,
    Nothing,
};

const PointError = error{
    OutOfBounds,
};

const Point = struct {
    x: usize,
    y: usize,

    pub fn down_one(self: Point) Point {
        return Point{
            .x = self.x,
            .y = self.y + 1,
        };
    }

    pub fn left_and_down(self: Point) PointError!Point {
        if (self.x == 0) {
            return PointError.OutOfBounds;
        }

        return Point{
            .x = self.x - 1,
            .y = self.y + 1,
        };
    }

    pub fn right_and_down(self: Point) Point {
        return Point{
            .x = self.x + 1,
            .y = self.y + 1,
        };
    }
};

pub const Grid = struct {
    grid: []const []const GridSpot,

    pub fn deinit(self: Grid, gpa: std.mem.Allocator) void {
        for (self.grid) |row| {
            gpa.free(row);
        }
        gpa.free(self.grid);
    }

    pub fn count_splits(self: Grid, gpa: std.mem.Allocator) !u64 {
        var active_beams = std.AutoHashMap(Point, void).init(gpa);

        try active_beams.put(self.find_start(), {});

        var splits: u64 = 0;

        while (active_beams.count() > 0) {
            const new_data = try self.get_next_beams(gpa, active_beams);
            active_beams.deinit();

            active_beams = new_data.@"0";
            splits += new_data.@"1";
        }

        active_beams.deinit();

        return splits;
    }

    pub fn count_timelines(self: Grid, gpa: std.mem.Allocator) !u64 {
        var cache = std.AutoHashMap(Point, u64).init(gpa);
        defer cache.deinit();

        return self.dfs_beam_timelines(self.find_start(), &cache);
    }

    fn dfs_beam_timelines(self: Grid, beam: Point, cache: *std.AutoHashMap(Point, u64)) !u64 {
        if (cache.get(beam)) |cached_timelines| {
            return cached_timelines;
        }

        if (beam.y == self.grid.len - 1) {
            return 1;
        }

        switch (self.grid[beam.y][beam.x]) {
            .Nothing, .Start => {
                const new_beam = beam.down_one();
                if (self.is_in_grid(new_beam)) {
                    const timelines = try self.dfs_beam_timelines(new_beam, cache);
                    try cache.put(beam, timelines);
                    return timelines;
                }
            },
            .Splitter => {
                var timelines: u64 = 0;

                const left: ?Point = beam.left_and_down() catch null;
                if (left != null and self.is_in_grid(left.?)) {
                    timelines += try self.dfs_beam_timelines(left.?, cache);
                }
                const right = beam.right_and_down();
                if (self.is_in_grid(right)) {
                    timelines += try self.dfs_beam_timelines(right, cache);
                }

                try cache.put(beam, timelines);

                return timelines;
            },
        }

        unreachable;
    }

    fn find_start(self: Grid) Point {
        for (self.grid[0], 0..) |v, x| {
            if (v == .Start) {
                return Point{ .x = x, .y = 0 };
            }
        }

        unreachable;
    }

    fn get_next_beams(self: Grid, gpa: std.mem.Allocator, cur_beams: std.AutoHashMap(Point, void)) !struct { std.AutoHashMap(Point, void), u64 } {
        var new_beams = std.AutoHashMap(Point, void).init(gpa);

        var splits: u64 = 0;
        var iter = cur_beams.iterator();
        while (iter.next()) |entry| {
            const beam = entry.key_ptr;
            switch (self.grid[beam.y][beam.x]) {
                .Nothing, .Start => {
                    const new_beam = beam.down_one();
                    if (self.is_in_grid(new_beam)) {
                        try new_beams.put(new_beam, {});
                    }
                },
                .Splitter => {
                    splits += 1;
                    const left: ?Point = beam.left_and_down() catch null;
                    if (left != null and self.is_in_grid(left.?)) {
                        try new_beams.put(left.?, {});
                    }
                    const right = beam.right_and_down();
                    if (self.is_in_grid(right)) {
                        try new_beams.put(right, {});
                    }
                },
            }
        }

        return .{ new_beams, splits };
    }

    fn is_in_grid(self: Grid, p: Point) bool {
        return p.y < self.grid.len and p.x < self.grid[0].len;
    }
};

pub fn read_file(gpa: std.mem.Allocator, filename: []const u8) !Grid {
    const Parser = struct {
        pub fn parse(_: std.mem.Allocator, c: u8) !GridSpot {
            return switch (c) {
                '.' => .Nothing,
                '^' => .Splitter,
                'S' => .Start,
                else => unreachable,
            };
        }
    };

    const fileparser = utils.fileparse.TwoDimensionalArrayParser(GridSpot, Parser.parse).init(gpa);

    var grid = try fileparser.parse(filename);

    const slice_grid = try utils.slices.two_dimensional_arraylists_to_slices(gpa, GridSpot, &grid);

    return Grid{
        .grid = slice_grid,
    };
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var grid = try read_file(allocator, "example.txt");
    defer grid.deinit(allocator);

    try std.testing.expectEqual(21, try grid.count_splits(allocator));
    try std.testing.expectEqual(40, try grid.count_timelines(allocator));
}
