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
                const buttons_pressed_dupe = try gpa.alloc(usize, cur_state.buttons_pressed_idxs.len + 1);
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
        return try self.lin_alg_fewest_button_presses_for_joltages();
    }

    fn lin_alg_fewest_button_presses_for_joltages(self: ManualLine) !u64 {
        var linear_system = try self.setup_linear_system();
        defer linear_system.deinit();

        var solution = try linear_system.gaussian_elimination();
        defer solution.deinit(self.gpa);

        switch (solution) {
            .unique => |*uniq| {
                return try float_array_to_int_sum(uniq.solution);
            },
            .infinite => |*infin| {
                return try infin.find_smallest_int_sum(self.gpa);
            },
        }
    }

    fn setup_linear_system(self: ManualLine) !LinearSystem {
        const button_matrix = try self.gpa.alloc([]f64, self.joltage_req.len);
        const result_vector = try self.gpa.alloc(f64, self.joltage_req.len);

        for (self.joltage_req, 0..) |joltage, i| {
            result_vector[i] = @floatFromInt(joltage);

            button_matrix[i] = try self.gpa.alloc(f64, self.buttons_for_joltages.len);
            @memset(button_matrix[i], 0.0);
            for (self.buttons_for_joltages, 0..) |btn, btn_idx| {
                for (btn) |joltage_idx| {
                    if (joltage_idx == i) {
                        button_matrix[i][btn_idx] = 1.0;
                    }
                }
            }
        }

        return LinearSystem{
            .gpa = self.gpa,
            .matrix = button_matrix,
            .result_vector = result_vector,
        };
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

const LinearSystem = struct {
    gpa: std.mem.Allocator,
    matrix: [][]f64,
    result_vector: []f64,

    pub fn deinit(self: *LinearSystem) void {
        for (self.matrix) |row| {
            self.gpa.free(row);
        }
        self.gpa.free(self.matrix);
        self.gpa.free(self.result_vector);
    }

    pub fn gaussian_elimination(self: LinearSystem) !MatrixSolution {
        const num_rows = self.matrix.len;
        const num_cols = self.matrix[0].len;

        const augmented = try self.get_augmented();
        defer {
            for (augmented) |row| {
                self.gpa.free(row);
            }
            self.gpa.free(augmented);
        }

        var pivot_cols = std.ArrayList(usize).empty;
        defer {
            pivot_cols.deinit(self.gpa);
        }

        var cur_row: usize = 0;

        for (0..num_cols) |col| {
            const pivot_row = self.find_pivot(augmented, cur_row, col, num_rows);

            if (pivot_row == null) {
                // no pivot in this column
                continue;
            }

            std.mem.swap([]f64, &augmented[cur_row], &augmented[pivot_row.?]);
            try pivot_cols.append(self.gpa, col);
            const pivot = augmented[cur_row][col];

            for (cur_row + 1..num_rows) |row| {
                const multiplier = augmented[row][col] / pivot;
                for (col..num_cols + 1) |k| {
                    augmented[row][k] -= multiplier * augmented[cur_row][k];
                }
            }

            cur_row += 1;
            if (cur_row >= num_rows) {
                break;
            }
        }

        const rank = pivot_cols.items.len;

        if (rank == num_cols) {
            return MatrixSolution{ .unique = .{
                .solution = try self.back_substitution(augmented, pivot_cols.items, num_cols),
            } };
        } else {
            return MatrixSolution{ .infinite = .{
                .particular_solution = try self.back_substitution(augmented, pivot_cols.items, num_cols),
                .null_space_basis = try self.find_null_space(augmented, pivot_cols.items, num_cols),
                .free_variables = num_cols - rank,
            } };
        }
    }

    /// Finds the row index with a non-zero entry in column 'col',
    /// starting from 'start_row'
    fn find_pivot(_: LinearSystem, augmented: [][]f64, start_row: usize, col: usize, num_rows: usize) ?usize {
        var best_row: ?usize = null;
        var best_value: f64 = 0.0;

        for (start_row..num_rows) |row| {
            if (@abs(augmented[row][col]) > best_value) {
                best_value = @abs(augmented[row][col]);
                best_row = row;
            }
        }

        if (best_value < 1e-10) {
            return null;
        }

        return best_row;
    }

    fn get_augmented(self: LinearSystem) ![][]f64 {
        const augmented = try self.gpa.alloc([]f64, self.matrix.len);
        for (self.matrix, 0..) |row, i| {
            augmented[i] = try self.gpa.alloc(f64, row.len + 1);
            for (row, 0..) |v, j| {
                augmented[i][j] = v;
            }
            augmented[i][row.len] = self.result_vector[i];
        }

        return augmented;
    }

    fn back_substitution(self: LinearSystem, augmented: [][]f64, pivot_cols: []usize, num_cols: usize) ![]f64 {
        const x = try self.gpa.alloc(f64, num_cols);
        @memset(x, 0.0);

        var i: usize = pivot_cols.len - 1;
        while (true) : (i -= 1) {
            const row = i;
            const col = pivot_cols[i];

            var sum = augmented[row][num_cols]; // RHS

            for (col + 1..num_cols) |j| {
                sum -= augmented[row][j] * x[j];
            }

            x[col] = sum / augmented[row][col];

            if (i == 0) {
                break;
            }
        }

        return x;
    }

    fn find_null_space(self: LinearSystem, augmented: [][]f64, pivot_cols: []usize, num_cols: usize) ![][]f64 {
        var free_vars = std.ArrayList(usize).empty;
        defer free_vars.deinit(self.gpa);

        outer: for (0..num_cols) |col| {
            // append to free_vars if not found in pivot_cols
            for (pivot_cols) |pivot_col| {
                if (col == pivot_col) {
                    continue :outer;
                }
            }
            try free_vars.append(self.gpa, col);
        }

        var null_basis = std.ArrayList([]f64).empty;
        defer null_basis.deinit(self.gpa);

        // Make a basis vector for each free var
        for (free_vars.items) |free_var| {
            const basis_vector = try self.gpa.alloc(f64, num_cols);
            @memset(basis_vector, 0.0);

            basis_vector[free_var] = 1.0;

            // Solve for pivot vars (back substitution with RHS = 0)
            var i: usize = pivot_cols.len - 1;
            while (true) : (i -= 1) {
                const row = i;
                const col = pivot_cols[i];

                var sum: f64 = 0.0;
                for (col + 1..num_cols) |j| {
                    sum -= augmented[row][j] * basis_vector[j];
                }

                basis_vector[col] = sum / augmented[row][col];

                if (i == 0) {
                    break;
                }
            }

            try null_basis.append(self.gpa, basis_vector);
        }

        return try null_basis.toOwnedSlice(self.gpa);
    }
};

const MatrixSolution = union(enum) {
    unique: UniqueMatrixSolution,
    infinite: InfiniteMatrixSolution,

    pub fn deinit(self: *MatrixSolution, gpa: std.mem.Allocator) void {
        switch (self.*) {
            .unique => |*uniq| uniq.deinit(gpa),
            .infinite => |*infin| infin.deinit(gpa),
        }
    }
};

const UniqueMatrixSolution = struct {
    solution: []f64,

    pub fn deinit(self: *UniqueMatrixSolution, gpa: std.mem.Allocator) void {
        gpa.free(self.solution);
    }
};

const InfiniteMatrixSolution = struct {
    particular_solution: []f64,
    null_space_basis: [][]f64,
    free_variables: usize,

    pub fn deinit(self: *InfiniteMatrixSolution, gpa: std.mem.Allocator) void {
        gpa.free(self.particular_solution);
        for (self.null_space_basis) |row| {
            gpa.free(row);
        }
        gpa.free(self.null_space_basis);
    }

    pub fn find_smallest_int_sum(self: InfiniteMatrixSolution, gpa: std.mem.Allocator) !u64 {
        var ans: anyerror!u64 = undefined;

        // start with a 50 search space, and double it every time we fail
        // to see if larger search spaces find us an answer
        var search_space: u64 = 50;
        while (search_space <= 500) : (search_space *= 2) {
            ans = self.search_null_space(gpa, search_space);
            if (ans) |_| {
                break;
            } else |_| {}
        }
        return ans;
    }

    fn search_null_space(self: InfiniteMatrixSolution, gpa: std.mem.Allocator, search_space: u64) !u64 {
        const StackEntry = struct {
            t_values: []i64,
            next_idx_to_increment: usize,
        };

        var stack = std.ArrayList(StackEntry).empty;
        defer {
            for (stack.items) |e| {
                gpa.free(e.t_values);
            }
            stack.deinit(gpa);
        }

        var lowest_sum = float_array_to_int_sum(self.particular_solution) catch std.math.maxInt(u64);

        const t_values = try gpa.alloc(i64, self.null_space_basis.len);
        @memset(t_values, -1 * @as(i64, @intCast(search_space)));
        try stack.append(gpa, StackEntry{
            .t_values = t_values,
            .next_idx_to_increment = 0,
        });

        while (stack.pop()) |entry| {
            defer gpa.free(entry.t_values);

            const solution = try gpa.dupe(f64, self.particular_solution);
            defer gpa.free(solution);

            for (0..solution.len) |i| {
                for (self.null_space_basis, 0..) |bas, j| {
                    solution[i] += bas[i] * @as(f64, @floatFromInt(entry.t_values[j]));
                }
            }

            if (float_array_to_int_sum(solution)) |sum| {
                if (sum < lowest_sum) {
                    lowest_sum = sum;
                }
            } else |_| {}

            for (entry.next_idx_to_increment..entry.t_values.len) |i| {
                if (entry.t_values[i] < @as(i64, @intCast(search_space))) {
                    const new_t = try gpa.dupe(i64, entry.t_values);
                    new_t[i] += 1;
                    try stack.append(gpa, .{
                        .t_values = new_t,
                        .next_idx_to_increment = i,
                    });
                }
            }
        }

        if (lowest_sum == std.math.maxInt(u64)) {
            return error.NoAnswerFound;
        }

        return lowest_sum;
    }
};

fn float_array_to_int_sum(a: []f64) !u64 {
    var sum: u64 = 0;
    for (a) |v| {
        if (@abs(v - @round(v)) > 1e-6) {
            return error.NotInteger;
        }

        // round to ignore floating point inprecision
        if (@round(v) < 0) {
            return error.Negative;
        }

        sum += @intFromFloat(@round(v));
    }
    return sum;
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
