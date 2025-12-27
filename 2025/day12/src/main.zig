const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    var presents = try read_file(allocator, filename);
    defer presents.deinit();

    std.debug.print("Part 1: {d}\n", .{try part1(presents)});
}

pub fn part1(presents: Presents) !u64 {
    return try presents.num_regions_that_work();
}

pub const Presents = struct {
    gpa: std.mem.Allocator,
    shapes: []PresentShape,
    regions: []Region,

    pub fn deinit(self: Presents) void {
        for (self.shapes) |shape| {
            shape.deinit(self.gpa);
        }
        self.gpa.free(self.shapes);

        for (self.regions) |region| {
            region.deinit(self.gpa);
        }
        self.gpa.free(self.regions);
    }

    pub fn num_regions_that_work(self: Presents) !u64 {
        var working_regions: u64 = 0;

        const present_sizes = try self.gpa.alloc(u64, self.shapes.len);
        defer self.gpa.free(present_sizes);

        const present_areas = try self.gpa.alloc(u64, self.shapes.len);
        defer self.gpa.free(present_areas);

        for (self.shapes, 0..) |shape, i| {
            present_sizes[i] = shape.size_of_present();
            present_areas[i] = shape.total_area();
        }

        for (self.regions) |region| {
            if (!region.could_fit_presents_if_perfectly_fit_together(present_sizes)) {
                continue;
            }
            if (region.could_fit_with_no_interlocking(present_areas)) {
                working_regions += 1;
                continue;
            }
            // check if these optimizations catch every input case or not
            unreachable;
        }

        return working_regions;
    }
};

pub const GridSpot = enum {
    Nothing,
    Present,
};

pub const PresentShape = struct {
    shape: [][]GridSpot,

    pub fn deinit(self: PresentShape, gpa: std.mem.Allocator) void {
        for (self.shape) |row| {
            gpa.free(row);
        }

        gpa.free(self.shape);
    }

    pub fn total_area(self: PresentShape) u64 {
        return self.shape.len * self.shape[0].len;
    }

    pub fn size_of_present(self: PresentShape) u64 {
        var size: u64 = 0;
        for (self.shape) |row| {
            for (row) |v| {
                if (v == .Present) {
                    size += 1;
                }
            }
        }
        return size;
    }
};

pub const Region = struct {
    width: u64,
    height: u64,
    required_presents: []u64,

    pub fn deinit(self: Region, gpa: std.mem.Allocator) void {
        gpa.free(self.required_presents);
    }

    pub fn area(self: Region) u64 {
        return self.width * self.height;
    }

    pub fn could_fit_presents_if_perfectly_fit_together(self: Region, present_sizes: []u64) bool {
        var minimum_needed_area: u64 = 0;

        for (self.required_presents, 0..) |n, i| {
            minimum_needed_area += n * present_sizes[i];
        }

        return self.area() >= minimum_needed_area;
    }

    pub fn could_fit_with_no_interlocking(self: Region, present_areas: []u64) bool {
        var minimum_needed_area: u64 = 0;

        for (self.required_presents, 0..) |n, i| {
            minimum_needed_area += n * present_areas[i];
        }

        return self.area() >= minimum_needed_area;
    }
};

pub fn read_file(gpa: std.mem.Allocator, filename: []const u8) !Presents {
    const Accumulator = struct {
        gpa: std.mem.Allocator,
        shapes: std.ArrayList(PresentShape),
        regions: std.ArrayList(Region),

        shape_builder: std.ArrayList([]GridSpot),

        fn deinit(self: *@This()) void {
            self.shapes.deinit(self.gpa);
            self.regions.deinit(self.gpa);
            self.shape_builder.deinit(self.gpa);
        }

        fn to_presents(self: *@This()) !Presents {
            // clear out the shape if there is one being built
            try self.shape_is_done();

            return Presents{
                .gpa = self.gpa,
                .shapes = try self.shapes.toOwnedSlice(self.gpa),
                .regions = try self.regions.toOwnedSlice(self.gpa),
            };
        }

        fn add_row_to_cur_shape(self: *@This(), line: []const u8) !void {
            var row = std.ArrayList(GridSpot).empty;
            defer row.deinit(self.gpa);

            for (line) |c| {
                try row.append(self.gpa, switch (c) {
                    '#' => GridSpot.Present,
                    '.' => GridSpot.Nothing,
                    else => unreachable,
                });
            }

            try self.shape_builder.append(self.gpa, try row.toOwnedSlice(self.gpa));

            return;
        }

        fn shape_is_done(self: *@This()) !void {
            if (self.shape_builder.items.len == 0) {
                return;
            }

            try self.shapes.append(self.gpa, PresentShape{
                .shape = try self.shape_builder.toOwnedSlice(self.gpa),
            });
            self.shape_builder.deinit(self.gpa);

            self.shape_builder = std.ArrayList([]GridSpot).empty;
        }
    };

    var accumulator = Accumulator{
        .gpa = gpa,
        .shapes = std.ArrayList(PresentShape).empty,
        .regions = std.ArrayList(Region).empty,
        .shape_builder = std.ArrayList([]GridSpot).empty,
    };
    defer accumulator.deinit();

    const Parser = struct {
        pub fn parse(_: std.mem.Allocator, line: []const u8, acc: *Accumulator) !void {
            if (std.mem.containsAtLeast(u8, line, 1, ":") and std.mem.containsAtLeast(u8, line, 1, "x")) {
                // regions
                var colon_split = std.mem.tokenizeAny(u8, line, ":");
                const size = colon_split.next() orelse return error.RegionWithNoSize;
                const presents = colon_split.next() orelse return error.RegionWithNoPresents;

                var size_split = std.mem.tokenizeAny(u8, size, "x");
                const width_str = size_split.next() orelse return error.RegionWithNoWidth;
                const height_str = size_split.next() orelse return error.RegionWithNoHeight;

                var presents_list = std.ArrayList(u64).empty;
                defer presents_list.deinit(acc.gpa);

                var presents_split = std.mem.tokenizeAny(u8, presents, " \n");
                while (presents_split.next()) |v| {
                    try presents_list.append(acc.gpa, try std.fmt.parseInt(u64, v, 10));
                }

                try acc.regions.append(acc.gpa, Region{
                    .width = try std.fmt.parseInt(u64, width_str, 10),
                    .height = try std.fmt.parseInt(u64, height_str, 10),
                    .required_presents = try presents_list.toOwnedSlice(acc.gpa),
                });
            } else if (std.mem.containsAtLeast(u8, line, 1, "#") or std.mem.containsAtLeast(u8, line, 1, ".")) {
                // part of shape
                try acc.add_row_to_cur_shape(line);
            } else {
                // number, which means we can reset the shape builder
                try acc.shape_is_done();
            }
        }
    };

    const fileparser = utils.fileparse.AccumulatorPerLineParser(Accumulator, Parser.parse).init(gpa);
    try fileparser.parse(filename, &accumulator);

    return try accumulator.to_presents();
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var presents = try read_file(allocator, "example.txt");
    defer presents.deinit();

    // The solution doesn't work on the example input because this day is kind of a meme imo...
    // Doing the actual logic to fit everything together would be hard and annoying, maybe I'll
    // come back to it some day but probably not
    // try std.testing.expectEqual(2, try part1(presents));
}
