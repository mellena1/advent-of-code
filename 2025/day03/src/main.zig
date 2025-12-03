const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    const battery_banks = try read_file(allocator, filename);
    std.debug.print("Part 1: {d}\n", .{part1(battery_banks.items)});
}

fn part1(battery_banks: []BatteryBank) u64 {
    var sum: u64 = 0;

    for (battery_banks) |bank| {
        sum += bank.find_highest_joltage();
    }

    return sum;
}

const BatteryBank = struct {
    batteries: []u8,

    pub fn find_highest_joltage(self: BatteryBank) u64 {
        var highest_first_digit: u8 = 0;
        var first_digit_idx: u64 = 0;
        for (self.batteries, 0..) |n, i| {
            // highest first digit can't be the last battery
            if (i == self.batteries.len - 1) {
                break;
            }

            if (n > highest_first_digit) {
                highest_first_digit = n;
                first_digit_idx = i;
            }
        }

        var highest_second_digit: u8 = 0;
        for (self.batteries[first_digit_idx + 1 ..]) |n| {
            if (n > highest_second_digit) {
                highest_second_digit = n;
            }
        }

        return @as(u64, (highest_first_digit * 10) + highest_second_digit);
    }
};

fn read_file(gpa: std.mem.Allocator, filename: []const u8) !std.ArrayList(BatteryBank) {
    const Parser = struct {
        fn parse(allocator: std.mem.Allocator, line: []const u8) !BatteryBank {
            var list = try std.ArrayList(u8).initCapacity(allocator, line.len);
            defer list.deinit(allocator);

            for (line) |c| {
                try list.append(allocator, c - '0');
            }

            return BatteryBank{
                .batteries = try list.toOwnedSlice(allocator),
            };
        }
    };

    const fileparser = utils.fileparse.PerLineParser(BatteryBank, Parser.parse).init(gpa);

    return fileparser.parse(filename);
}

test "AOC examples are right" {
    const allocator = std.heap.page_allocator;
    var battery_banks = try read_file(allocator, "example.txt");
    defer battery_banks.deinit(allocator);

    try std.testing.expectEqual(part1(battery_banks.items), 357);
}
