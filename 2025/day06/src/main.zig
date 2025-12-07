const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    var formulas_p1 = try read_file_part_1(allocator, filename);
    defer deinit_formulas(allocator, &formulas_p1);

    std.debug.print("Part 1: {d}\n", .{sum_formulas(formulas_p1.items)});

    var formulas_p2 = try read_file_part_2(allocator, filename);
    defer deinit_formulas(allocator, &formulas_p2);

    std.debug.print("Part 2: {d}\n", .{sum_formulas(formulas_p2.items)});
}

fn sum_formulas(formulas: []Formula) u64 {
    var answer: u64 = 0;
    for (formulas) |f| {
        answer += f.solve();
    }
    return answer;
}

fn deinit_formulas(gpa: std.mem.Allocator, formulas: *std.ArrayList(Formula)) void {
    for (formulas.items) |*f| {
        f.deinit(gpa);
    }
    formulas.deinit(gpa);
}

const Operator = enum {
    Add,
    Multiply,
    Unknown,

    pub fn execute(self: Operator, n1: u64, n2: u64) u64 {
        return switch (self) {
            .Add => n1 + n2,
            .Multiply => n1 * n2,
            .Unknown => unreachable,
        };
    }
};

const Formula = struct {
    nums: std.ArrayList(u64),
    operator: Operator,

    pub fn init(gpa: std.mem.Allocator) !Formula {
        return Formula{
            .nums = try std.ArrayList(u64).initCapacity(gpa, 1024),
            .operator = .Unknown,
        };
    }

    pub fn init_with_size(gpa: std.mem.Allocator, size: usize) !Formula {
        var list = try std.ArrayList(u64).initCapacity(gpa, size);
        for (0..size) |_| {
            list.appendAssumeCapacity(0);
        }

        return Formula{
            .nums = list,
            .operator = .Unknown,
        };
    }

    pub fn deinit(self: *Formula, gpa: std.mem.Allocator) void {
        self.nums.deinit(gpa);
    }

    pub fn solve(self: Formula) u64 {
        var answer = self.nums.items[0];

        for (self.nums.items[1..]) |n| {
            answer = self.operator.execute(answer, n);
        }

        return answer;
    }
};

fn read_file_part_1(gpa: std.mem.Allocator, filename: []const u8) !std.ArrayList(Formula) {
    const Parser = struct {
        pub fn parse(allocator: std.mem.Allocator, cur: ?Formula, str: []const u8) !Formula {
            var formula: Formula = if (cur == null)
                try Formula.init(allocator)
            else
                cur.?;

            switch (str[0]) {
                '*' => {
                    return Formula{
                        .nums = formula.nums,
                        .operator = .Multiply,
                    };
                },
                '+' => {
                    return Formula{
                        .nums = formula.nums,
                        .operator = .Add,
                    };
                },
                else => {
                    const n: u64 = try std.fmt.parseInt(u64, str, 10);
                    try formula.nums.append(allocator, n);

                    return formula;
                },
            }
        }

        pub fn deinit_T(allocator: std.mem.Allocator, v: *Formula) void {
            v.deinit(allocator);
        }
    };

    const fileparser = utils.fileparse.ColumnParser(Formula, Parser.parse, Parser.deinit_T).init(gpa);

    return try fileparser.parse(filename);
}

fn read_file_part_2(gpa: std.mem.Allocator, filename: []const u8) !std.ArrayList(Formula) {
    const Parser = struct {
        pub fn parse(allocator: std.mem.Allocator, line: []const u8) ![]const u8 {
            return allocator.dupe(u8, line);
        }
    };

    const parser = utils.fileparse.PerLineParser([]const u8, Parser.parse).init(gpa);
    var full_file_lines = try parser.parse(filename);
    defer {
        for (full_file_lines.items) |line| {
            gpa.free(line);
        }
        full_file_lines.deinit(gpa);
    }

    const col_lens = try find_col_lens(gpa, full_file_lines.items);
    defer gpa.free(col_lens);

    var formulas = try std.ArrayList(Formula).initCapacity(gpa, col_lens.len);
    for (0..col_lens.len) |i| {
        formulas.appendAssumeCapacity(try Formula.init_with_size(gpa, col_lens[i]));
    }

    // Parse through the numbers
    for (full_file_lines.items[0 .. full_file_lines.items.len - 1]) |line| {
        var line_idx: usize = 0;
        for (col_lens, 0..) |col_len, col_idx| {
            const start: usize = line_idx;
            const end: usize = line_idx + col_len;
            while (line_idx < end) : (line_idx += 1) {
                const c: u8 = line[line_idx];

                if (c == ' ') {
                    continue;
                }

                const new_digit: u64 = @intCast(c - '0');
                const digit_idx = line_idx - start;

                // Move existing digits left 1
                formulas.items[col_idx].nums.items[digit_idx] *= 10;
                // Add new digit as the ones place
                formulas.items[col_idx].nums.items[digit_idx] += new_digit;
            }

            // skip empty char delimiter
            line_idx += 1;
        }
    }

    // Assign operators
    var operators = std.mem.tokenizeSequence(u8, full_file_lines.items[full_file_lines.items.len - 1], " ");
    var i: usize = 0;
    while (operators.next()) |str| : (i += 1) {
        formulas.items[i].operator = switch (str[0]) {
            '+' => .Add,
            '*' => .Multiply,
            else => unreachable,
        };
    }

    return formulas;
}

fn find_col_lens(gpa: std.mem.Allocator, lines: [][]const u8) ![]usize {
    var col_lens = std.ArrayList(usize).empty;
    defer col_lens.deinit(gpa);

    for (lines) |line| {
        var split = std.mem.tokenizeSequence(u8, line, " ");
        var i: usize = 0;
        while (split.next()) |n_as_str| : (i += 1) {
            if (i < col_lens.items.len) {
                if (n_as_str.len > col_lens.items[i]) {
                    col_lens.items[i] = n_as_str.len;
                }
            } else {
                try col_lens.append(gpa, n_as_str.len);
            }
        }
    }

    return col_lens.toOwnedSlice(gpa);
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var formulas = try read_file_part_1(allocator, "example.txt");
    defer deinit_formulas(allocator, &formulas);

    try std.testing.expectEqual(4277556, sum_formulas(formulas.items));

    var formulas_p2 = try read_file_part_2(allocator, "example.txt");
    defer deinit_formulas(allocator, &formulas_p2);

    try std.testing.expectEqual(3263827, sum_formulas(formulas_p2.items));
}
