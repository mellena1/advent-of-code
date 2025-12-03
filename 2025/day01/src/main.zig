const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    var turns = try read_file(allocator, filename);
    defer turns.deinit(allocator);

    var dial = Dial{};
    dial.execute_turns(turns.items);

    std.debug.print("Part 1: {d}\n", .{dial.times_at_zero});
    std.debug.print("Part 2: {d}\n", .{dial.times_passing_zero});
}

const TurnDirection = enum {
    left,
    right,
};

const Turn = struct {
    direction: TurnDirection,
    amount: u32,
};

const ParseError = error{
    InvalidDirection,
};

fn read_file(gpa: std.mem.Allocator, filename: []const u8) !std.ArrayList(Turn) {
    const TurnParser = struct {
        fn parse(_: std.mem.Allocator, line: []const u8) !Turn {
            const dir = switch (line[0]) {
                'L' => TurnDirection.left,
                'R' => TurnDirection.right,
                else => return ParseError.InvalidDirection,
            };

            const amt = try std.fmt.parseInt(u32, line[1..], 10);

            return Turn{
                .direction = dir,
                .amount = amt,
            };
        }
    };

    const fileparser = utils.fileparse.PerLineParser(Turn, TurnParser.parse).init(gpa);

    return fileparser.parse(filename);
}

const Dial = struct {
    cur_pos: u8 = 50, // dial starts at 50
    times_at_zero: u32 = 0,
    times_passing_zero: u32 = 0,

    pub fn execute_turns(self: *Dial, turns: []Turn) void {
        for (turns) |turn| {
            switch (turn.direction) {
                .left => self.set_pos(-1 * @as(i32, @intCast(turn.amount))),
                .right => self.set_pos(@as(i32, @intCast(turn.amount))),
            }
        }
    }

    fn set_pos(self: *Dial, turn_amount: i32) void {
        const next_pos_unbounded = @as(i32, self.cur_pos) + turn_amount;

        if (turn_amount > 0) {
            self.times_passing_zero += @intCast(@divFloor(next_pos_unbounded, 100));
        } else if (next_pos_unbounded <= 0) {
            // account for case of already being at 0 and then going backwards
            if (self.cur_pos != 0) {
                self.times_passing_zero += 1;
            }

            self.times_passing_zero += @as(u32, @intCast(@divFloor(@abs(next_pos_unbounded), 100)));
        }

        self.cur_pos = @as(u8, @intCast(@mod(next_pos_unbounded, 100)));

        if (self.cur_pos == 0) {
            self.times_at_zero += 1;
        }
    }
};

test "AOC examples are right" {
    const allocator = std.heap.page_allocator;

    var turns = try read_file(allocator, "example.txt");
    defer turns.deinit(allocator);

    var dial = Dial{};
    dial.execute_turns(turns.items);

    try std.testing.expectEqual(dial.times_at_zero, 3);
    try std.testing.expectEqual(dial.times_passing_zero, 6);
}
