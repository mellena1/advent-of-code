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
}

pub fn part1(server_rack: ServerRack) !u64 {
    return try server_rack.num_paths_between("you", "out");
}

pub fn part2(server_rack: ServerRack) !u64 {
    _ = server_rack;
    const answer: u64 = 0;
    return answer;
}

const ServerRack = struct {
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
        return try self.dfs_count_paths(from, &start_path, to);
    }

    fn dfs_count_paths(self: ServerRack, at: []const u8, cur_path: *std.ArrayList([]const u8), dest: []const u8) !u64 {
        defer cur_path.deinit(self.gpa);

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
            num_paths += try self.dfs_count_paths(neighbor, &cloned_path, dest);
        }

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
    //try std.testing.expectEqual(33, try part2(manuals.items));
}
