const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    var manuals = try read_file(allocator, filename);
    defer {
        for (manuals.items) |*m| {
            m.deinit();
        }
        manuals.deinit(allocator);
    }

    std.debug.print("Part 1: {d}\n", .{try part1(manuals.items)});
}

pub fn part1(manuals: []ManualLine) !u64 {
    var answer: u64 = 0;
    for (manuals) |m| {
        answer += try m.fewest_presses();
    }
    return answer;
}

pub const ManualLine = struct {
    gpa: std.mem.Allocator,
    /// [.##.] will be 0110
    light_diagram: u64,
    /// (3) will be 0003, (1, 3) will be 0101 etc
    buttons: []u64,
    joltage_req: []u64,

    pub fn deinit(self: *ManualLine) void {
        self.gpa.free(self.buttons);
        self.gpa.free(self.joltage_req);
    }

    pub fn fewest_presses(self: ManualLine) !u64 {
        return try self.bfs_fewest_button_presses();
    }

    fn bfs_fewest_button_presses(self: ManualLine) !u64 {
        const State = struct {
            cur_lights: u64,
            buttons_pressed_idxs: []usize,

            fn deinit(cur_state: @This(), gpa: std.mem.Allocator) void {
                gpa.free(cur_state.buttons_pressed_idxs);
            }

            fn less_than(_: void, a: @This(), b: @This()) std.math.Order {
                if (a.buttons_pressed_idxs.len == b.buttons_pressed_idxs.len) {
                    return .eq;
                } else if (a.buttons_pressed_idxs.len < b.buttons_pressed_idxs.len) {
                    return .lt;
                } else {
                    return .gt;
                }
            }

            fn has_pressed_btn(cur_state: @This(), button_idx: usize) bool {
                for (cur_state.buttons_pressed_idxs) |i| {
                    if (i == button_idx) {
                        return true;
                    }
                }
                return false;
            }

            fn press_button(cur_state: @This(), gpa: std.mem.Allocator, button_idx: usize, btn: u64) !@This() {
                const buttons_pressed_dupe = try gpa.alloc(u64, cur_state.buttons_pressed_idxs.len + 1);
                @memcpy(buttons_pressed_dupe[0 .. buttons_pressed_dupe.len - 1], cur_state.buttons_pressed_idxs);
                buttons_pressed_dupe[buttons_pressed_dupe.len - 1] = button_idx;

                return @This(){
                    .cur_lights = cur_state.cur_lights ^ btn,
                    .buttons_pressed_idxs = buttons_pressed_dupe,
                };
            }
        };

        var queue = std.PriorityQueue(State, void, State.less_than).init(self.gpa, {});
        defer {
            while (queue.removeOrNull()) |state| {
                state.deinit(self.gpa);
            }
            queue.deinit();
        }

        try queue.add(State{
            .cur_lights = 0,
            .buttons_pressed_idxs = try self.gpa.alloc(usize, 0),
        });

        while (queue.removeOrNull()) |state| {
            defer state.deinit(self.gpa);
            for (self.buttons, 0..) |btn, btn_idx| {
                if (state.has_pressed_btn(btn_idx)) {
                    continue;
                }

                const new_state = try state.press_button(self.gpa, btn_idx, btn);
                if (new_state.cur_lights == self.light_diagram) {
                    defer new_state.deinit(self.gpa);
                    return new_state.buttons_pressed_idxs.len;
                }
                try queue.add(new_state);
            }
        }

        unreachable;
    }
};

pub fn read_file(gpa: std.mem.Allocator, filename: []const u8) !std.ArrayList(ManualLine) {
    const Parser = struct {
        pub fn parse(allocator: std.mem.Allocator, line: []const u8) !ManualLine {
            var split = std.mem.tokenizeAny(u8, line, " ");

            const light_diagram_str = split.next().?;
            var light_diagram: u64 = 0;
            // ignore [] in len
            const light_diagram_len: u64 = light_diagram_str.len - 2;
            // slice it to ignore []
            for (light_diagram_str[1 .. light_diagram_str.len - 1]) |light| {
                light_diagram <<= 1;
                if (light == '#') {
                    light_diagram |= 1;
                }
            }

            var buttons_list = std.ArrayList(u64).empty;
            defer buttons_list.deinit(allocator);

            var s: []const u8 = split.next().?;

            while (s[0] == '(') {
                // ignore ()
                const button_str = s[1 .. s.len - 1];
                var button_nums = std.mem.tokenizeAny(u8, button_str, ",");
                var button: u64 = 0;
                while (button_nums.next()) |n_str| {
                    const n = try std.fmt.parseInt(u64, n_str, 10);
                    button |= std.math.pow(u64, 2, light_diagram_len - 1 - n);
                }
                try buttons_list.append(allocator, button);

                s = split.next().?;
            }

            var joltage_list = std.ArrayList(u64).empty;
            defer joltage_list.deinit(allocator);

            // ignore {}
            const joltage_str = s[1 .. s.len - 1];
            var joltage_nums = std.mem.tokenizeAny(u8, joltage_str, ",");
            while (joltage_nums.next()) |n| {
                try joltage_list.append(allocator, try std.fmt.parseInt(u64, n, 10));
            }

            return ManualLine{
                .gpa = allocator,
                .light_diagram = light_diagram,
                .buttons = try buttons_list.toOwnedSlice(allocator),
                .joltage_req = try joltage_list.toOwnedSlice(allocator),
            };
        }
    };

    const fileparser = utils.fileparse.PerLineParser(ManualLine, Parser.parse).init(gpa);
    return try fileparser.parse(filename);
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var manuals = try read_file(allocator, "example.txt");
    defer {
        for (manuals.items) |*m| {
            m.deinit();
        }
        manuals.deinit(allocator);
    }

    try std.testing.expectEqual(7, try part1(manuals.items));
}
