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
    const allocator = std.heap.page_allocator;

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
    const allocator = std.heap.page_allocator;

    const Parser = struct {
        fn parse(_: std.mem.Allocator, c: u8) !u8 {
            return c - '0';
        }
    };

    const fileparser = TwoDimensionalArrayParser(u8, Parser.parse).init(allocator);
    var result = try fileparser.parse("test_data/grid_of_nums.txt");
    defer result.deinit(allocator);

    const items = result.items;

    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 4, 5 }, items[0].items);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 5, 4, 3, 2, 1 }, items[1].items);
}
