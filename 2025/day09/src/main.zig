const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    const grid = try read_file(allocator, filename);
    defer grid.deinit();

    std.debug.print("Part 1: {d}\n", .{try grid.biggest_rect_area()});
    std.debug.print("Part 2: {d}\n", .{try grid.biggest_rect_with_red_and_green()});
}

const Point = struct {
    x: usize,
    y: usize,

    pub fn area(self: Point, p2: Point) u64 {
        return self.x_size(p2) * self.y_size(p2);
    }

    pub fn x_size(self: Point, p2: Point) u64 {
        // +1 size the 0 case is really still 1 wide
        return if (self.x > p2.x)
            self.x - p2.x + 1
        else
            p2.x - self.x + 1;
    }

    pub fn y_size(self: Point, p2: Point) u64 {
        // +1 size the 0 case is really still 1 wide
        return if (self.y > p2.y)
            self.y - p2.y + 1
        else
            p2.y - self.y + 1;
    }
};

pub const Grid = struct {
    gpa: std.mem.Allocator,
    red_tiles: []const Point,

    pub fn deinit(self: Grid) void {
        self.gpa.free(self.red_tiles);
    }

    pub fn biggest_rect_area(self: Grid) !u64 {
        var biggest_area: u64 = 0;

        for (self.red_tiles[0 .. self.red_tiles.len - 1], 0..) |t1, i| {
            for (self.red_tiles[i + 1 ..]) |t2| {
                const area = t1.area(t2);
                if (area > biggest_area) {
                    biggest_area = area;
                }
            }
        }

        return biggest_area;
    }

    pub fn biggest_rect_with_red_and_green(self: Grid) !u64 {
        const green_tiles = try self.find_green_tiles();
        defer self.gpa.free(green_tiles);

        var red_tiles_set = try self.tile_set(self.red_tiles);
        defer red_tiles_set.deinit();

        var green_tiles_set = try self.tile_set(green_tiles);
        defer green_tiles_set.deinit();

        var biggest_area: u64 = 0;

        for (self.red_tiles[0 .. self.red_tiles.len - 1], 0..) |t1, i| {
            for (self.red_tiles[i + 1 ..]) |t2| {
                if (Grid.rect_all_red_or_green(red_tiles_set, green_tiles_set, t1, t2)) {
                    const area = t1.area(t2);
                    if (area > biggest_area) {
                        biggest_area = area;
                    }
                }
            }
        }

        return biggest_area;
    }

    fn rect_all_red_or_green(red_tiles_set: std.AutoHashMap(Point, void), green_tiles_set: std.AutoHashMap(Point, void), t1: Point, t2: Point) bool {
        // If a line, then we already know they definitely are all red and green
        if (t1.x == t2.x or t1.y == t2.y) {
            return true;
        }

        // Otherwise we can just check all the perimeter tiles
        for (@min(t1.x, t2.x)..@max(t1.x, t2.x)) |x| {
            const p1 = Point{
                .x = x,
                .y = @min(t1.y, t2.y),
            };
            if (!red_tiles_set.contains(p1) and !green_tiles_set.contains(p1)) {
                return false;
            }

            const p2 = Point{
                .x = x,
                .y = @max(t1.y, t2.y),
            };
            if (!red_tiles_set.contains(p2) and !green_tiles_set.contains(p2)) {
                return false;
            }
        }
        for (@min(t1.y, t2.y)..@max(t1.y, t2.y)) |y| {
            const p1 = Point{
                .x = @min(t1.x, t2.x),
                .y = y,
            };
            if (!red_tiles_set.contains(p1) and !green_tiles_set.contains(p1)) {
                return false;
            }

            const p2 = Point{
                .x = @max(t1.x, t2.x),
                .y = y,
            };
            if (!red_tiles_set.contains(p2) and !green_tiles_set.contains(p2)) {
                return false;
            }
        }

        return true;
    }

    fn find_green_tiles(self: Grid) ![]Point {
        var green_tiles = std.ArrayList(Point).empty;
        defer green_tiles.deinit(self.gpa);

        // Find all of the perimeter tiles
        for (self.red_tiles, 0..) |t1, i| {
            // Either get the next tile, or wrap back around
            const t2 = if (i < self.red_tiles.len - 1)
                self.red_tiles[i + 1]
            else
                self.red_tiles[0];

            if (t1.x == t2.x) {
                var j: usize = 1;
                const y_size = t1.y_size(t2);
                while (j < y_size - 1) : (j += 1) {
                    try green_tiles.append(self.gpa, Point{
                        .x = t1.x,
                        .y = @max(t1.y, t2.y) - j,
                    });
                }
            } else if (t1.y == t2.y) {
                var j: usize = 1;
                const x_size = t1.x_size(t2);
                while (j < x_size - 1) : (j += 1) {
                    try green_tiles.append(self.gpa, Point{
                        .x = @max(t1.x, t2.x) - j,
                        .y = t1.y,
                    });
                }
            }
        }

        // Flood fill to find the area tiles
        var red_tile_set = try self.tile_set(self.red_tiles);
        defer red_tile_set.deinit();

        var green_tile_set = try self.tile_set(green_tiles.items);
        defer green_tile_set.deinit();

        var stack = std.ArrayList(Point).empty;
        defer stack.deinit(self.gpa);

        try stack.append(self.gpa, self.starting_flood_point());

        std.debug.print("starting flood\n", .{});
        std.debug.print("first point {any}\n", .{self.starting_flood_point()});

        while (stack.pop()) |tile| {
            if (tile.x > 100000 or tile.y > 100000) {
                std.debug.print("{any}\n", .{tile});
                return error.FloodFileOutOfBounds;
            }

            try green_tiles.append(self.gpa, tile);
            try green_tile_set.put(tile, {});

            if (green_tiles.items.len % 10000 == 0) {
                std.debug.print("{d}\n", .{green_tiles.items.len});
            }

            var i: i64 = -1;
            while (i < 2) : (i += 1) {
                var j: i64 = -1;
                while (j < 2) : (j += 1) {
                    if (i == 0 and j == 0) {
                        continue;
                    }

                    const neighbor = Point{
                        .x = @intCast(@as(i64, @intCast(tile.x)) + i),
                        .y = @intCast(@as(i64, @intCast(tile.y)) + j),
                    };

                    if (!red_tile_set.contains(neighbor) and !green_tile_set.contains(neighbor)) {
                        try stack.append(self.gpa, neighbor);
                    }
                }
            }
        }

        std.debug.print("flood done\n", .{});

        return green_tiles.toOwnedSlice(self.gpa);
    }

    fn starting_flood_point(self: Grid) Point {
        const Direction = enum {
            Up,
            Down,
            Left,
            Right,

            fn get_dir(p1: Point, p2: Point) @This() {
                if (p1.x == p2.x) {
                    if (p1.y > p2.y) {
                        return .Up;
                    } else {
                        return .Down;
                    }
                } else {
                    if (p1.x > p2.x) {
                        return .Left;
                    } else {
                        return .Right;
                    }
                }
            }

            fn add_to_point(dir: @This(), p: Point) Point {
                return switch (dir) {
                    .Up => Point{ .x = p.x, .y = p.y - 1 },
                    .Down => Point{ .x = p.x, .y = p.y + 1 },
                    .Left => Point{ .x = p.x - 1, .y = p.y },
                    .Right => Point{ .x = p.x + 1, .y = p.y },
                };
            }

            fn opposite(dir: @This()) @This() {
                return switch (dir) {
                    .Up => .Down,
                    .Down => .Up,
                    .Left => .Right,
                    .Right => .Left,
                };
            }
        };

        // TODO: this definitely isn't foolproof, we don't know if the corner is pointing in or out

        const first_dir = Direction.get_dir(self.red_tiles[0], self.red_tiles[1]);
        const second_dir = Direction.get_dir(self.red_tiles[1], self.red_tiles[2]);

        return second_dir.add_to_point(first_dir.add_to_point(self.red_tiles[1]));
    }

    fn tile_set(self: Grid, tiles: []const Point) !std.AutoHashMap(Point, void) {
        var map = std.AutoHashMap(Point, void).init(self.gpa);

        for (tiles) |t| {
            try map.put(t, {});
        }

        return map;
    }
};

pub fn read_file(gpa: std.mem.Allocator, filename: []const u8) !Grid {
    const Parser = struct {
        pub fn parse(_: std.mem.Allocator, line: []const u8) !Point {
            var split = std.mem.splitAny(u8, line, ",");
            return Point{
                .x = try std.fmt.parseInt(usize, split.next().?, 10),
                .y = try std.fmt.parseInt(usize, split.next().?, 10),
            };
        }
    };

    const fileparser = utils.fileparse.PerLineParser(Point, Parser.parse).init(gpa);

    var points = try fileparser.parse(filename);
    defer points.deinit(gpa);

    return Grid{
        .gpa = gpa,
        .red_tiles = try points.toOwnedSlice(gpa),
    };
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var grid = try read_file(allocator, "example.txt");
    defer grid.deinit();

    try std.testing.expectEqual(50, try grid.biggest_rect_area());
    try std.testing.expectEqual(24, try grid.biggest_rect_with_red_and_green());
}
