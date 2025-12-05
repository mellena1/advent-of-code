const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    const ingredients_list = try read_file(allocator, filename);
    defer ingredients_list.deinit(allocator);

    std.debug.print("Part 1: {d}\n", .{ingredients_list.num_fresh_ingredients()});
    std.debug.print("Part 2: {d}\n", .{try ingredients_list.total_num_ids_in_ranges(allocator)});
}

const RangeError = error{CannotCombine};

const Range = struct {
    start: u64,
    end: u64,

    pub fn is_in_range(self: Range, n: u64) bool {
        return n >= self.start and n <= self.end;
    }

    pub fn size(self: Range) u64 {
        return self.end - self.start + 1;
    }

    pub fn combine(self: Range, r2: Range) RangeError!Range {
        if (r2.start >= self.start and r2.start <= self.end) {
            return Range{
                .start = self.start,
                .end = @max(self.end, r2.end),
            };
        } else if (self.start >= r2.start and self.start <= r2.end) {
            return Range{
                .start = r2.start,
                .end = @max(self.end, r2.end),
            };
        } else {
            return RangeError.CannotCombine;
        }
    }
};

const IngredientsList = struct {
    fresh_database: []Range,
    ingredient_ids: []u64,

    pub fn deinit(self: IngredientsList, gpa: std.mem.Allocator) void {
        gpa.free(self.fresh_database);
        gpa.free(self.ingredient_ids);
    }

    pub fn num_fresh_ingredients(self: IngredientsList) u64 {
        var num: u64 = 0;

        ingredients_loop: for (self.ingredient_ids) |id| {
            for (self.fresh_database) |range| {
                if (range.is_in_range(id)) {
                    num += 1;
                    continue :ingredients_loop;
                }
            }
        }

        return num;
    }

    pub fn total_num_ids_in_ranges(self: IngredientsList, gpa: std.mem.Allocator) !u64 {
        const simplified_ranges = try self.simplify_ranges(gpa);
        defer gpa.free(simplified_ranges);

        var total: u64 = 0;
        for (simplified_ranges) |range| {
            total += range.size();
        }

        return total;
    }

    fn simplify_ranges(self: IngredientsList, gpa: std.mem.Allocator) ![]Range {
        var list = try std.ArrayList(Range).initCapacity(gpa, self.fresh_database.len);
        defer list.deinit(gpa);

        for (self.fresh_database) |range| {
            try list.append(gpa, range);
        }

        var i: usize = 0;
        outer_loop: while (i < list.items.len) : (i += 1) {
            var r1 = list.items[i];
            var j: usize = i + 1;
            while (j < list.items.len) : (j += 1) {
                const r2 = list.items[j];

                r1 = r1.combine(r2) catch {
                    continue;
                };

                // Set the new combined one as the i pos,
                // delete r2 since we just merged it in
                // then just start back at the beginning since
                // there might be new merges that we can do.
                // There might be a better way to do this but eh.
                list.items[i] = r1;
                _ = list.swapRemove(j);
                i = 0;
                continue :outer_loop;
            }
        }

        return try list.toOwnedSlice(gpa);
    }
};

fn read_file(gpa: std.mem.Allocator, filename: []const u8) !IngredientsList {
    const RangeParser = struct {
        fn parse(_: std.mem.Allocator, line: []const u8) !Range {
            var split = std.mem.splitAny(u8, line, "-");

            return Range{
                .start = try std.fmt.parseInt(u64, split.next().?, 10),
                .end = try std.fmt.parseInt(u64, split.next().?, 10),
            };
        }
    };

    const NumParser = struct {
        fn parse(_: std.mem.Allocator, line: []const u8) !u64 {
            return std.fmt.parseInt(u64, line, 10);
        }
    };

    const fileparser = utils.fileparse.TwoSectionParser(Range, u64, RangeParser.parse, NumParser.parse).init(gpa);

    var lists = try fileparser.parse(filename);
    defer lists.@"0".deinit(gpa);
    defer lists.@"1".deinit(gpa);

    return IngredientsList{
        .fresh_database = try lists.@"0".toOwnedSlice(gpa),
        .ingredient_ids = try lists.@"1".toOwnedSlice(gpa),
    };
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var ingredients_list = try read_file(allocator, "example.txt");
    defer ingredients_list.deinit(allocator);

    try std.testing.expectEqual(3, ingredients_list.num_fresh_ingredients());
    try std.testing.expectEqual(14, try ingredients_list.total_num_ids_in_ranges(allocator));
}
