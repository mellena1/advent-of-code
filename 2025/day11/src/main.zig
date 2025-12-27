const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    var server_rack = try read_file(allocator, filename);
    defer server_rack.deinit();

    std.debug.print("Part 1: {d}\n", .{try part1(server_rack)});
    std.debug.print("Part 2: {d}\n", .{try part2(server_rack)});
}

pub fn part1(server_rack: ServerRack) !u64 {
    return try server_rack.num_paths_between("you", "out");
}

pub fn part2(server_rack: ServerRack) !u64 {
    return try server_rack.num_paths_between_that_contain("svr", "out", &[_][]const u8{ "dac", "fft" });
}

pub const ServerRack = struct {
    gpa: std.mem.Allocator,
    connections: std.StringArrayHashMap([][]const u8),

    pub fn deinit(self: *ServerRack) void {
        var iter = self.connections.iterator();
        while (iter.next()) |entry| {
            self.gpa.free(entry.key_ptr.*);
            const dests = entry.value_ptr.*;
            for (dests) |v| {
                self.gpa.free(v);
            }
            self.gpa.free(dests);
        }
        self.connections.deinit();
    }

    pub fn num_paths_between(self: ServerRack, from: []const u8, to: []const u8) !u64 {
        var start_path = std.ArrayList([]const u8).empty;
        var memo = std.StringArrayHashMap(u64).init(self.gpa);
        defer memo.deinit();

        return try self.dfs_count_paths(from, &start_path, to, &memo);
    }

    pub fn num_paths_between_that_contain(self: ServerRack, from: []const u8, to: []const u8, must_contain: []const []const u8) !u64 {
        const paths = try self.path_options(from, to, must_contain);
        defer {
            for (paths) |path| {
                self.gpa.free(path);
            }
            self.gpa.free(paths);
        }

        var total_paths: u64 = 0;

        paths_loop: for (paths) |path| {
            var ways_for_this_path: u64 = 1;

            for (path[0 .. path.len - 1], 0..) |start, i| {
                const end = path[i + 1];

                const num_ways_between = try self.num_paths_between(start, end);

                if (num_ways_between == 0) {
                    continue :paths_loop;
                }

                ways_for_this_path *= num_ways_between;
            }

            total_paths += ways_for_this_path;
        }

        return total_paths;
    }

    fn path_options(self: ServerRack, from: []const u8, to: []const u8, must_contain: []const []const u8) ![][][]const u8 {
        var options = std.ArrayList([][]const u8).empty;
        defer options.deinit(self.gpa);

        var start_path = std.ArrayList([]const u8).empty;
        try self.dfs_options(must_contain, &start_path, &options);

        for (options.items, 0..) |item, idx| {
            const path_with_start_and_end = try self.gpa.alloc([]const u8, item.len + 2);
            path_with_start_and_end[0] = from;
            path_with_start_and_end[path_with_start_and_end.len - 1] = to;
            @memcpy(path_with_start_and_end[1 .. path_with_start_and_end.len - 1], item);
            options.items[idx] = path_with_start_and_end;
            self.gpa.free(item);
        }

        return try options.toOwnedSlice(self.gpa);
    }

    fn dfs_options(self: ServerRack, options: []const []const u8, cur_path: *std.ArrayList([]const u8), options_list: *std.ArrayList([][]const u8)) !void {
        defer cur_path.deinit(self.gpa);

        if (cur_path.items.len == options.len) {
            try options_list.append(self.gpa, try cur_path.toOwnedSlice(self.gpa));
            return;
        }

        options_loop: for (options) |opt| {
            // skip any options already in the path
            for (cur_path.items) |cur| {
                if (std.mem.eql(u8, cur, opt)) {
                    continue :options_loop;
                }
            }

            var new_path = try cur_path.clone(self.gpa);
            errdefer new_path.deinit(self.gpa);

            try new_path.append(self.gpa, opt);
            try self.dfs_options(options, &new_path, options_list);
        }
    }

    fn dfs_count_paths(self: ServerRack, at: []const u8, cur_path: *std.ArrayList([]const u8), dest: []const u8, memo: *std.StringArrayHashMap(u64)) !u64 {
        defer cur_path.deinit(self.gpa);

        if (memo.get(at)) |num_paths| {
            return num_paths;
        }

        try cur_path.append(self.gpa, at);

        if (std.mem.eql(u8, at, dest)) {
            return 1;
        }

        var num_paths: u64 = 0;

        const neighbors = self.connections.get(at) orelse return 0;
        neighbor_loop: for (neighbors) |neighbor| {
            for (cur_path.items) |prev_visited| {
                if (std.mem.eql(u8, neighbor, prev_visited)) {
                    continue :neighbor_loop;
                }
            }

            var cloned_path = try cur_path.clone(self.gpa);
            num_paths += try self.dfs_count_paths(neighbor, &cloned_path, dest, memo);
        }

        try memo.put(at, num_paths);

        return num_paths;
    }
};

pub fn read_file(gpa: std.mem.Allocator, filename: []const u8) !ServerRack {
    var connections = std.StringArrayHashMap([][]const u8).init(gpa);

    const Parser = struct {
        pub fn parse(allocator: std.mem.Allocator, line: []const u8, acc: *std.StringArrayHashMap([][]const u8)) !void {
            var iter = std.mem.tokenizeAny(u8, line, " :");

            const src = iter.next() orelse return error.NoSrcInLine;

            var dest_list = std.ArrayList([]const u8).empty;
            defer dest_list.deinit(allocator);

            while (iter.next()) |dest| {
                try dest_list.append(allocator, try allocator.dupe(u8, dest));
            }

            try acc.put(try allocator.dupe(u8, src), try dest_list.toOwnedSlice(allocator));
        }
    };

    const fileparser = utils.fileparse.AccumulatorPerLineParser(std.StringArrayHashMap([][]const u8), Parser.parse).init(gpa);
    try fileparser.parse(filename, &connections);

    return ServerRack{
        .gpa = gpa,
        .connections = connections,
    };
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var server_rack = try read_file(allocator, "example.txt");
    defer server_rack.deinit();

    try std.testing.expectEqual(5, try part1(server_rack));

    var server_rack_2 = try read_file(allocator, "example2.txt");
    defer server_rack_2.deinit();

    try std.testing.expectEqual(2, try part2(server_rack_2));
}
