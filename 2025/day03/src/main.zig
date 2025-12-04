const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    const battery_banks = try read_file(allocator, filename);
    defer deinit_banks(allocator, &battery_banks);
    std.debug.print("Part 1: {d}\n", .{find_sum_of_joltages(battery_banks.items, 2)});
    std.debug.print("Part 2: {d}\n", .{find_sum_of_joltages(battery_banks.items, 12)});
}

fn find_sum_of_joltages(battery_banks: []BatteryBank, num_batteries: u8) u64 {
    var sum: u64 = 0;

    for (battery_banks) |bank| {
        sum += bank.find_highest_joltage(num_batteries);
    }

    return sum;
}

const BatteryBank = struct {
    batteries: []u8,

    pub fn deinit(self: BatteryBank, gpa: std.mem.Allocator) void {
        gpa.free(self.batteries);
    }

    pub fn find_highest_joltage(self: BatteryBank, digits: u8) u64 {
        var digits_found: u8 = 0;
        var cur_idx: u64 = 0;
        var answer: u64 = 0;

        while (digits_found < digits) {
            var highest_digit: u8 = 0;

            for (self.batteries[cur_idx..], cur_idx..) |n, i| {
                // need enough digits for remaining amount
                if (i == self.batteries.len - (digits - digits_found - 1)) {
                    break;
                }

                if (n > highest_digit) {
                    highest_digit = n;
                    cur_idx = i + 1;
                }
            }

            digits_found += 1;
            answer += highest_digit * std.math.pow(u64, 10, @as(u64, digits - digits_found));
        }

        return answer;
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

fn deinit_banks(gpa: std.mem.Allocator, battery_banks: *std.ArrayList(BatteryBank)) void {
    for (battery_banks.items) |*bank| {
        bank.deinit(gpa);
    }
    battery_banks.deinit(gpa);
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var battery_banks = try read_file(allocator, "example.txt");
    defer deinit_banks(allocator, &battery_banks);

    try std.testing.expectEqual(find_sum_of_joltages(battery_banks.items, 2), 357);
    try std.testing.expectEqual(find_sum_of_joltages(battery_banks.items, 12), 3121910778619);
}
