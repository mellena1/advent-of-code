const std = @import("std");

/// Generic parser that reads in a file, splits by delimiter, and runs handler on every chunk to map to a list of type T
pub fn DelimiterParser(comptime T: type, comptime delimiter: u8, comptime handler: fn (allocator: std.mem.Allocator, str: []const u8) anyerror!T) type {
    return struct {
        gpa: std.mem.Allocator,

        pub fn init(gpa: std.mem.Allocator) @This() {
            return .{ .gpa = gpa };
        }

        pub fn parse(self: @This(), file_name: []const u8) !std.ArrayList(T) {
            const file = try std.fs.cwd().openFile(file_name, .{ .mode = .read_only });
            defer file.close();

            var buffer: [4096]u8 = undefined;
            var reader = file.reader(&buffer);

            var list = try std.ArrayList(T).initCapacity(self.gpa, 1024);
            errdefer list.deinit(self.gpa);

            while (reader.interface.takeDelimiter(delimiter)) |opt_line| {
                if (opt_line == null) {
                    break;
                }

                const line = opt_line.?;

                // skip empty lines
                if (line.len == 0) {
                    continue;
                }

                const new_item = try handler(self.gpa, line);

                try list.append(self.gpa, new_item);
            } else |err| if (err != error.EndOfStream) return err;

            return list;
        }
    };
}

/// Returns a struct that can read a file per line and call a generic function on the line
/// to generate an ArrayList of the values
pub fn PerLineParser(comptime T: type, comptime handle_line: fn (allocator: std.mem.Allocator, line: []const u8) anyerror!T) type {
    return DelimiterParser(T, '\n', handle_line);
}

test "basic u8 parsing per line" {
    const allocator = std.testing.allocator;

    const Parser = struct {
        fn parse(_: std.mem.Allocator, line: []const u8) !u8 {
            return try std.fmt.parseInt(u8, line, 10);
        }
    };

    const fileparser = PerLineParser(u8, Parser.parse).init(allocator);
    var result = try fileparser.parse("test_data/lines_of_nums.txt");
    defer result.deinit(allocator);

    const items = result.items;

    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 5 }, items);
}

pub fn TwoDimensionalArrayParser(comptime T: type, comptime handle_char: fn (allocator: std.mem.Allocator, c: u8) anyerror!T) type {
    return struct {
        gpa: std.mem.Allocator,

        pub fn init(gpa: std.mem.Allocator) @This() {
            return .{
                .gpa = gpa,
            };
        }

        pub fn parse(self: @This(), file_name: []const u8) !std.ArrayList(std.ArrayList(T)) {
            const file = try std.fs.cwd().openFile(file_name, .{ .mode = .read_only });
            defer file.close();

            var buffer: [4096]u8 = undefined;
            var reader = file.reader(&buffer);

            var grid = try std.ArrayList(std.ArrayList(T)).initCapacity(self.gpa, 1024);
            errdefer grid.deinit(self.gpa);

            while (reader.interface.takeDelimiter('\n')) |opt_line| {
                if (opt_line == null) {
                    break;
                }

                const line = opt_line.?;

                // skip empty lines
                if (line.len == 0) {
                    continue;
                }

                var row = try std.ArrayList(T).initCapacity(self.gpa, 1024);
                errdefer row.deinit(self.gpa);
                for (line) |c| {
                    try row.append(self.gpa, try handle_char(self.gpa, c));
                }

                try grid.append(self.gpa, row);
            } else |err| if (err != error.EndOfStream) return err;

            return grid;
        }
    };
}

test "Can parse 2D grid" {
    const allocator = std.testing.allocator;

    const Parser = struct {
        fn parse(_: std.mem.Allocator, c: u8) !u8 {
            return c - '0';
        }
    };

    const fileparser = TwoDimensionalArrayParser(u8, Parser.parse).init(allocator);
    var result = try fileparser.parse("test_data/grid_of_nums.txt");
    defer {
        for (result.items) |*row| {
            row.deinit(allocator);
        }
        result.deinit(allocator);
    }

    const items = result.items;

    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 5 }, items[0].items);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 5, 4, 3, 2, 1 }, items[1].items);
}

pub fn TwoSectionParser(
    comptime T1: type,
    comptime T2: type,
    comptime handle_t1_line: fn (allocator: std.mem.Allocator, line: []const u8) anyerror!T1,
    comptime handle_t2_line: fn (allocator: std.mem.Allocator, line: []const u8) anyerror!T2,
) type {
    return struct {
        gpa: std.mem.Allocator,

        pub fn init(gpa: std.mem.Allocator) @This() {
            return .{ .gpa = gpa };
        }

        pub fn parse(self: @This(), file_name: []const u8) !struct { std.ArrayList(T1), std.ArrayList(T2) } {
            const file = try std.fs.cwd().openFile(file_name, .{ .mode = .read_only });
            defer file.close();

            var buffer: [4096]u8 = undefined;
            var reader = file.reader(&buffer);

            var list1 = try std.ArrayList(T1).initCapacity(self.gpa, 1024);
            errdefer list1.deinit(self.gpa);

            var list2 = try std.ArrayList(T2).initCapacity(self.gpa, 1024);
            errdefer list2.deinit(self.gpa);

            var in_first_section: bool = true;

            while (reader.interface.takeDelimiter('\n')) |opt_line| {
                if (opt_line == null) {
                    break;
                }

                const line = opt_line.?;

                // skip empty lines
                if (line.len == 0) {
                    in_first_section = false;
                    continue;
                }

                if (in_first_section) {
                    const new_item = try handle_t1_line(self.gpa, line);

                    try list1.append(self.gpa, new_item);
                } else {
                    const new_item = try handle_t2_line(self.gpa, line);
                    try list2.append(self.gpa, new_item);
                }
            } else |err| if (err != error.EndOfStream) return err;

            return .{ list1, list2 };
        }
    };
}

test "can parse multi-section file" {
    const allocator = std.testing.allocator;

    const Parser1 = struct {
        fn parse(_: std.mem.Allocator, line: []const u8) !u64 {
            return try std.fmt.parseInt(u64, line, 10);
        }
    };

    const Parser2 = struct {
        fn parse(gpa: std.mem.Allocator, line: []const u8) ![]const u8 {
            return gpa.dupe(u8, line);
        }
    };

    const parser = TwoSectionParser(u64, []const u8, Parser1.parse, Parser2.parse).init(allocator);
    var actual = try parser.parse("test_data/two_section.txt");
    defer actual.@"0".deinit(allocator);
    defer {
        for (actual.@"1".items) |s| {
            allocator.free(s);
        }
        actual.@"1".deinit(allocator);
    }

    try std.testing.expectEqualSlices(u64, &[_]u64{ 1, 2, 3, 4, 5 }, actual.@"0".items);
    try std.testing.expectEqualDeep(&[_][]const u8{ "abcd", "efgh" }, actual.@"1".items);
}

pub fn ColumnParser(comptime T: type, comptime handle_new_val: fn (gpa: std.mem.Allocator, cur: ?T, str: []const u8) anyerror!T, comptime deinit_T: fn (gpa: std.mem.Allocator, v: *T) void) type {
    return struct {
        gpa: std.mem.Allocator,

        pub fn init(gpa: std.mem.Allocator) @This() {
            return .{ .gpa = gpa };
        }

        pub fn parse(self: @This(), file_name: []const u8) !std.ArrayList(T) {
            const file = try std.fs.cwd().openFile(file_name, .{ .mode = .read_only });
            defer file.close();

            var buffer: [4096]u8 = undefined;
            var reader = file.reader(&buffer);

            var columns = try std.ArrayList(T).initCapacity(self.gpa, 1024);
            errdefer {
                for (columns.items) |*v| {
                    deinit_T(self.gpa, v);
                }
                columns.deinit(self.gpa);
            }

            while (reader.interface.takeDelimiter('\n')) |opt_line| {
                if (opt_line == null) {
                    break;
                }

                const line = opt_line.?;

                // skip empty lines
                if (line.len == 0) {
                    continue;
                }

                var split = std.mem.tokenizeSequence(u8, line, " ");
                var i: usize = 0;
                while (split.next()) |v| : (i += 1) {
                    if (i < columns.items.len) {
                        const new_val = try handle_new_val(self.gpa, columns.items[i], v);
                        columns.items[i] = new_val;
                    } else {
                        const new_val = try handle_new_val(self.gpa, null, v);
                        try columns.append(self.gpa, new_val);
                    }
                }
            } else |err| if (err != error.EndOfStream) return err;

            return columns;
        }
    };
}

test "can parse columns" {
    const allocator = std.testing.allocator;

    const Parser = struct {
        pub fn parse(gpa: std.mem.Allocator, cur: ?std.ArrayList(u64), str: []const u8) !std.ArrayList(u64) {
            var list: std.ArrayList(u64) = if (cur == null)
                std.ArrayList(u64).empty
            else
                cur.?;

            const n = try std.fmt.parseInt(u64, str, 10);

            try list.append(gpa, n);

            return list;
        }

        pub fn deinit_T(gpa: std.mem.Allocator, v: *std.ArrayList(u64)) void {
            v.deinit(gpa);
        }
    };

    const parser = ColumnParser(std.ArrayList(u64), Parser.parse, Parser.deinit_T).init(allocator);

    var actual = try parser.parse("test_data/columns.txt");
    defer {
        for (actual.items) |*l| {
            l.deinit(allocator);
        }
        actual.deinit(allocator);
    }

    try std.testing.expectEqualSlices(u64, &.{ 1, 6 }, actual.items[0].items);
    try std.testing.expectEqualSlices(u64, &.{ 2, 7 }, actual.items[1].items);
    try std.testing.expectEqualSlices(u64, &.{ 3, 8 }, actual.items[2].items);
    try std.testing.expectEqualSlices(u64, &.{ 4, 9 }, actual.items[3].items);
    try std.testing.expectEqualSlices(u64, &.{ 5, 10 }, actual.items[4].items);
}
