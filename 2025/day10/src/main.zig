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
    std.debug.print("Part 2: {d}\n", .{try part2(manuals.items)});
}

pub fn part1(manuals: []ManualLine) !u64 {
    var answer: u64 = 0;
    for (manuals) |m| {
        answer += try m.fewest_presses_for_lights();
    }
    return answer;
}

pub fn part2(manuals: []ManualLine) !u64 {
    var answer: u64 = 0;
    for (manuals) |m| {
        answer += try m.fewest_presses_for_joltage();
    }
    return answer;
}

pub const ManualLine = struct {
    gpa: std.mem.Allocator,
    /// [.##.] will be 0110
    light_diagram: u64,
    /// (3) will be 0003, (1, 3) will be 0101 etc
    buttons: []u64,

    /// just the raw numbers (i.e. 3 will be 3)
    buttons_for_joltages: [][]u64,
    joltage_req: []u64,

    pub fn deinit(self: *ManualLine) void {
        self.gpa.free(self.buttons);
        self.gpa.free(self.joltage_req);
        for (self.buttons_for_joltages) |l| {
            self.gpa.free(l);
        }
        self.gpa.free(self.buttons_for_joltages);
    }

    pub fn fewest_presses_for_lights(self: ManualLine) !u64 {
        return try self.bfs_fewest_button_presses_for_lights();
    }

    fn bfs_fewest_button_presses_for_lights(self: ManualLine) !u64 {
        const State = struct {
            cur_lights: u64,
            buttons_pressed_idxs: []usize,

            fn deinit(cur_state: @This(), gpa: std.mem.Allocator) void {
                gpa.free(cur_state.buttons_pressed_idxs);
            }

            fn less_than(_: void, a: @This(), b: @This()) std.math.Order {
                return std.math.order(a.buttons_pressed_idxs.len, b.buttons_pressed_idxs.len);
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

    pub fn fewest_presses_for_joltage(self: ManualLine) !u64 {
        return try self.bfs_fewest_button_presses_for_joltages();
    }

    fn bfs_fewest_button_presses_for_joltages(self: ManualLine) !u64 {
        const State = struct {
            cur_joltages: []u64,
            cur_joltages_sum: u64,
            btn_presses: u64,
            wanted_joltages_sum: u64,

            fn deinit(cur_state: @This(), gpa: std.mem.Allocator) void {
                gpa.free(cur_state.cur_joltages);
            }

            fn any_joltage_too_high(cur_state: @This(), wanted: []u64) bool {
                for (cur_state.cur_joltages, 0..) |jolt, i| {
                    if (jolt > wanted[i]) {
                        return true;
                    }
                }
                return false;
            }

            fn joltages_are_equal_to(cur_state: @This(), wanted: []u64) bool {
                for (cur_state.cur_joltages, 0..) |jolt, i| {
                    if (jolt != wanted[i]) {
                        return false;
                    }
                }
                return true;
            }

            fn joltage_sum_diff(cur_state: @This()) u64 {
                return cur_state.wanted_joltages_sum - cur_state.cur_joltages_sum;
            }

            /// Sorts priority queue by whatever state is closest to completion.
            /// This should prioritize moving forward the states that click
            /// buttons that get us closer to the overall goal instead of endlessly
            /// clicking buttons that don't do much.
            fn less_than(_: void, a: @This(), b: @This()) std.math.Order {
                return std.math.order(a.joltage_sum_diff(), b.joltage_sum_diff());
                //return std.math.order(a.btn_presses, b.btn_presses);
            }

            fn press_button(cur_state: @This(), gpa: std.mem.Allocator, btn: []u64) !@This() {
                const joltages_dupe = try gpa.dupe(u64, cur_state.cur_joltages);
                var new_joltages_sum = cur_state.cur_joltages_sum;

                for (btn) |i| {
                    joltages_dupe[i] += 1;
                    new_joltages_sum += 1;
                }

                return @This(){
                    .cur_joltages = joltages_dupe,
                    .cur_joltages_sum = new_joltages_sum,
                    .btn_presses = cur_state.btn_presses + 1,
                    .wanted_joltages_sum = cur_state.wanted_joltages_sum,
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

        const zero_joltages = try self.gpa.dupe(u64, self.joltage_req);
        @memset(zero_joltages, 0);

        var wanted_joltage_sum: u64 = 0;
        for (self.joltage_req) |j| {
            wanted_joltage_sum += j;
        }

        try queue.add(State{
            .cur_joltages = zero_joltages,
            .cur_joltages_sum = 0,
            .btn_presses = 0,
            .wanted_joltages_sum = wanted_joltage_sum,
        });

        while (queue.removeOrNull()) |state| {
            defer state.deinit(self.gpa);
            for (self.buttons_for_joltages) |btn| {
                const new_state = try state.press_button(self.gpa, btn);

                if (new_state.joltages_are_equal_to(self.joltage_req)) {
                    defer new_state.deinit(self.gpa);
                    return new_state.btn_presses;
                }

                if (!new_state.any_joltage_too_high(self.joltage_req)) {
                    try queue.add(new_state);
                } else {
                    new_state.deinit(self.gpa);
                }
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

            var joltage_buttons_list = std.ArrayList([]u64).empty;
            defer joltage_buttons_list.deinit(allocator);

            var s: []const u8 = split.next().?;

            while (s[0] == '(') {
                // ignore ()
                const button_str = s[1 .. s.len - 1];
                var button_nums = std.mem.tokenizeAny(u8, button_str, ",");
                var button: u64 = 0;

                var joltage_buttons = std.ArrayList(u64).empty;
                defer joltage_buttons.deinit(allocator);

                while (button_nums.next()) |n_str| {
                    const n = try std.fmt.parseInt(u64, n_str, 10);
                    try joltage_buttons.append(allocator, n);
                    button |= std.math.pow(u64, 2, light_diagram_len - 1 - n);
                }
                try joltage_buttons_list.append(allocator, try joltage_buttons.toOwnedSlice(allocator));
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
                .buttons_for_joltages = try joltage_buttons_list.toOwnedSlice(allocator),
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
    try std.testing.expectEqual(33, try part2(manuals.items));
}
