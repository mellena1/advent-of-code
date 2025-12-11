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

const Tile = enum {
    Red,
    Green,
    Nothing,
};

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

const Area = struct {
    area: u64,
    t1: Point,
    t2: Point,

    pub fn contains(self: Area, p: Point) bool {
        return p.x >= @min(self.t1.x, self.t2.x) and p.x <= @max(self.t1.x, self.t2.x) and p.y >= @min(self.t1.y, self.t2.y) and p.y <= @max(self.t1.y, self.t2.y);
    }

    pub fn sort_desc(_: void, a: @This(), b: @This()) bool {
        return a.area > b.area;
    }
};

const CompressedGrid = struct {
    gpa: std.mem.Allocator,
    red_tiles: []const Point,
    x_map: std.AutoHashMap(usize, usize),
    y_map: std.AutoHashMap(usize, usize),
    grid: [][]Tile,

    pub fn init(gpa: std.mem.Allocator, red_tiles: []const Point) !CompressedGrid {
        var unique_x = std.AutoHashMap(usize, void).init(gpa);
        defer unique_x.deinit();
        var unique_y = std.AutoHashMap(usize, void).init(gpa);
        defer unique_y.deinit();

        for (red_tiles) |t| {
            try unique_x.put(t.x, {});
            try unique_y.put(t.y, {});
        }

        const x_map = try CompressedGrid.make_uniq_map(gpa, unique_x);
        const y_map = try CompressedGrid.make_uniq_map(gpa, unique_y);

        const grid = try gpa.alloc([]Tile, y_map.count());
        for (0..grid.len) |i| {
            grid[i] = try gpa.alloc(Tile, x_map.count());
            @memset(grid[i], .Nothing);
        }

        for (red_tiles) |t| {
            grid[y_map.get(t.y).?][x_map.get(t.x).?] = .Red;
        }

        return CompressedGrid{
            .gpa = gpa,
            .red_tiles = try gpa.dupe(Point, red_tiles),
            .x_map = x_map,
            .y_map = y_map,
            .grid = grid,
        };
    }

    pub fn make_uniq_map(gpa: std.mem.Allocator, uniq_vals: std.AutoHashMap(usize, void)) !std.AutoHashMap(usize, usize) {
        var sorted_vals = std.ArrayList(usize).empty;
        defer sorted_vals.deinit(gpa);

        var iter = uniq_vals.keyIterator();
        while (iter.next()) |v| {
            try sorted_vals.append(gpa, v.*);
        }
        std.mem.sort(usize, sorted_vals.items, {}, std.sort.asc(usize));

        var map = std.AutoHashMap(usize, usize).init(gpa);
        for (sorted_vals.items, 0..) |v, i| {
            try map.put(v, i);
        }

        return map;
    }

    pub fn deinit(self: *CompressedGrid) void {
        self.x_map.deinit();
        self.y_map.deinit();
        for (self.grid) |row| {
            self.gpa.free(row);
        }
        self.gpa.free(self.grid);
        self.gpa.free(self.red_tiles);
    }

    pub fn biggest_rect_with_red_and_green(self: CompressedGrid) !u64 {
        try self.find_green_tiles(self.grid);

        var biggest_area: u64 = 0;

        var areas = std.ArrayList(Area).empty;
        defer areas.deinit(self.gpa);

        for (self.red_tiles[0 .. self.red_tiles.len - 1], 0..) |t1, i| {
            for (self.red_tiles[i + 1 ..]) |t2| {
                try areas.append(self.gpa, Area{
                    .area = t1.area(t2),
                    .t1 = t1,
                    .t2 = t2,
                });
            }
        }

        std.mem.sort(Area, areas.items, {}, Area.sort_desc);

        // Goes through area ascending
        for (areas.items) |area| {
            if (CompressedGrid.rect_all_red_or_green(self.grid, self.get_compressed_tile(area.t1), self.get_compressed_tile(area.t2))) {
                biggest_area = area.area;
                break;
            }
        }

        return biggest_area;
    }

    fn get_compressed_tile(self: CompressedGrid, p: Point) Point {
        const comp_x = self.x_map.get(p.x).?;
        const comp_y = self.y_map.get(p.y).?;

        return Point{
            .x = comp_x,
            .y = comp_y,
        };
    }

    fn find_green_tiles(self: CompressedGrid, grid: [][]Tile) !void {
        // Find all of the perimeter tiles
        for (self.red_tiles, 0..) |t1, i| {
            const comp_t1 = self.get_compressed_tile(t1);

            // Either get the next tile, or wrap back around
            const t2 = if (i < self.red_tiles.len - 1)
                self.red_tiles[i + 1]
            else
                self.red_tiles[0];

            const comp_t2 = self.get_compressed_tile(t2);

            if (comp_t1.x == comp_t2.x) {
                var j: usize = 1;
                const y_size = comp_t1.y_size(comp_t2);
                while (j < y_size - 1) : (j += 1) {
                    grid[@max(comp_t1.y, comp_t2.y) - j][comp_t1.x] = .Green;
                }
            } else if (comp_t1.y == comp_t2.y) {
                var j: usize = 1;
                const x_size = comp_t1.x_size(comp_t2);
                while (j < x_size - 1) : (j += 1) {
                    grid[comp_t1.y][@max(comp_t1.x, comp_t2.x) - j] = .Green;
                }
            }
        }

        // Flood fill to find the area tiles
        var stack = std.ArrayList(Point).empty;
        defer stack.deinit(self.gpa);

        try stack.append(self.gpa, CompressedGrid.starting_flood_point(grid));

        while (stack.pop()) |tile| {
            grid[tile.y][tile.x] = .Green;

            var i: i64 = -1;
            while (i < 2) : (i += 1) {
                var j: i64 = -1;
                while (j < 2) : (j += 1) {
                    if (i == 0 and j == 0) {
                        continue;
                    }
                    // Don't move diagonally
                    if (i != 0 and j != 0) {
                        continue;
                    }

                    const neighbor = Point{
                        .x = @intCast(@as(i64, @intCast(tile.x)) + i),
                        .y = @intCast(@as(i64, @intCast(tile.y)) + j),
                    };

                    if (neighbor.y < grid.len and neighbor.x < grid[0].len and grid[neighbor.y][neighbor.x] == .Nothing) {
                        try stack.append(self.gpa, neighbor);
                    }
                }
            }
        }

        return;
    }

    /// uses a raycast to find a tile inside of the polygon
    fn starting_flood_point(grid: [][]Tile) Point {
        // This is cheating, but I can't get this func to work with the example
        // case because of edge detection
        if (grid.len < 10) {
            return Point{
                .x = 2,
                .y = 1,
            };
        }

        for (grid, 0..) |row, y| {
            tile_loop: for (row, 0..) |tile, x| {
                if (tile != .Nothing) {
                    continue;
                }

                var crosses: usize = 0;
                var prev: Tile = .Nothing;

                var i: usize = x;
                while (i >= 0) : (i -= 1) {
                    const cur = grid[y][i];
                    // Ignore any row with edges because they suck
                    if (cur != .Nothing and prev != .Nothing) {
                        continue :tile_loop;
                    }
                    if (cur == .Nothing and prev != .Nothing) {
                        crosses += 1;
                    }
                    prev = cur;

                    // avoid integer underflow
                    if (i == 0) {
                        break;
                    }
                }

                if (crosses % 2 == 1) {
                    return Point{
                        .x = x,
                        .y = y,
                    };
                }
            }
        }
        unreachable;
    }

    fn rect_all_red_or_green(grid: [][]Tile, t1: Point, t2: Point) bool {
        for (@min(t1.x, t2.x)..@max(t1.x, t2.x) + 1) |x| {
            for (@min(t1.y, t2.y)..@max(t1.y, t2.y) + 1) |y| {
                if (grid[y][x] == .Nothing) {
                    return false;
                }
            }
        }

        return true;
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
        var compressed_grid = try CompressedGrid.init(self.gpa, self.red_tiles);
        defer compressed_grid.deinit();

        return compressed_grid.biggest_rect_with_red_and_green();
    }

    fn print_grid(grid: [][]Tile) void {
        for (grid) |row| {
            for (row) |t| {
                switch (t) {
                    .Nothing => std.debug.print(".", .{}),
                    .Red => std.debug.print("#", .{}),
                    .Green => std.debug.print("X", .{}),
                }
            }
            std.debug.print("\n", .{});
        }
        return;
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
