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
}

const Range = struct {
    start: u64,
    end: u64,

    pub fn is_in_range(self: Range, n: u64) bool {
        return n >= self.start and n <= self.end;
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
}
