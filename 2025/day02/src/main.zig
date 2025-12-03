const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    var ranges = try read_file(allocator, filename);
    defer ranges.deinit(allocator);

    const part1_answer = try sum_invalid_ids(allocator, ranges.items, number_is_double_sequence);
    std.debug.print("Part 1: {d}\n", .{part1_answer});

    const part2_answer = try sum_invalid_ids(allocator, ranges.items, number_is_any_number_of_repeats);
    std.debug.print("Part 2: {d}\n", .{part2_answer});
}

fn sum_invalid_ids(gpa: std.mem.Allocator, ranges: []IDRange, is_invalid: fn (n: u64) anyerror!bool) !u64 {
    var answer: u64 = 0;

    for (ranges) |range| {
        const invalid_ids = try range.invalid_ids_in_range(gpa, is_invalid);
        defer gpa.free(invalid_ids);
        for (invalid_ids) |invalid_id| {
            answer += invalid_id;
        }
    }

    return answer;
}

const IDRange = struct {
    start: u64,
    end: u64,

    fn invalid_ids_in_range(self: IDRange, gpa: std.mem.Allocator, is_invalid: fn (n: u64) anyerror!bool) ![]u64 {
        var invalid_ids = try std.ArrayList(u64).initCapacity(gpa, 1024);
        defer invalid_ids.deinit(gpa);

        for (self.start..self.end + 1) |n| {
            if (try is_invalid(n)) {
                try invalid_ids.append(gpa, n);
            }
        }

        return invalid_ids.toOwnedSlice(gpa);
    }
};

const InvalidRange = error.InvalidRange;

fn read_file(gpa: std.mem.Allocator, filename: []const u8) !std.ArrayList(IDRange) {
    const Parser = struct {
        fn parse(_: std.mem.Allocator, str: []const u8) !IDRange {
            const trimmed = std.mem.trim(u8, str, " \t\n\r");
            var it = std.mem.splitAny(u8, trimmed, "-");

            const startStr = it.next() orelse return InvalidRange;
            const endStr = it.next() orelse return InvalidRange;

            const range = IDRange{
                .start = try std.fmt.parseInt(u64, startStr, 10),
                .end = try std.fmt.parseInt(u64, endStr, 10),
            };

            return range;
        }
    };

    const fileparser = utils.fileparse.DelimiterParser(IDRange, ',', Parser.parse).init(gpa);

    return fileparser.parse(filename);
}

fn number_is_double_sequence(n: u64) !bool {
    var buf: [100]u8 = undefined;
    const n_as_str = try std.fmt.bufPrint(&buf, "{}", .{n});

    if (n_as_str.len % 2 != 0) {
        return false;
    }

    const midpoint = n_as_str.len / 2;
    return std.mem.eql(u8, n_as_str[0..midpoint], n_as_str[midpoint..]);
}

test "number_is_double_sequence works" {
    try std.testing.expectEqual(try number_is_double_sequence(1010), true);
    try std.testing.expectEqual(try number_is_double_sequence(99), true);
    try std.testing.expectEqual(try number_is_double_sequence(101), false);
    try std.testing.expectEqual(try number_is_double_sequence(1122), false);
}

fn number_is_any_number_of_repeats(n: u64) !bool {
    var buf: [100]u8 = undefined;
    const n_as_str = try std.fmt.bufPrint(&buf, "{}", .{n});

    const len = n_as_str.len;
    const midpoint = len / 2;

    num_digit_loop: for (1..midpoint + 1) |num_digits| {
        if (len % num_digits != 0) {
            continue;
        }

        const expected = n_as_str[0..num_digits];

        var i = num_digits;
        while (i < len) : (i += num_digits) {
            if (!std.mem.eql(u8, expected, n_as_str[i .. i + num_digits])) {
                continue :num_digit_loop;
            }
        }

        return true;
    }

    return false;
}

test "number_is_any_number_of_repeats works" {
    try std.testing.expectEqual(try number_is_any_number_of_repeats(1010), true);
    try std.testing.expectEqual(try number_is_any_number_of_repeats(111), true);
    try std.testing.expectEqual(try number_is_any_number_of_repeats(2121212121), true);
    try std.testing.expectEqual(try number_is_any_number_of_repeats(11222), false);
}

test "AOC examples are right" {
    const allocator = std.heap.page_allocator;
    var ranges = try read_file(allocator, "example.txt");
    defer ranges.deinit(allocator);

    try std.testing.expectEqual(sum_invalid_ids(allocator, ranges.items, number_is_double_sequence), 1227775554);
    try std.testing.expectEqual(sum_invalid_ids(allocator, ranges.items, number_is_any_number_of_repeats), 4174379265);
}
