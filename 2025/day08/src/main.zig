const std = @import("std");
const utils = @import("advent_of_code_utils");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const filename = try utils.args.get_file_name_from_args(allocator);

    var boxes = try read_file(allocator, filename);
    defer boxes.deinit(allocator);

    std.debug.print("Part 1: {d}\n", .{try part1(allocator, boxes.items, 1000)});
}

fn part1(gpa: std.mem.Allocator, boxes: []JunctionBox, num_connections_needed: u64) !u64 {
    const dists = try get_sorted_list_of_distances(gpa, boxes);
    defer gpa.free(dists);

    var nodes = std.AutoHashMap(JunctionBox, *Node).init(gpa);
    defer {
        var iter = nodes.valueIterator();
        while (iter.next()) |n| {
            n.*.deinit(gpa);
        }
        nodes.deinit();
    }

    // init nodes
    for (boxes) |box| {
        var n = Node{
            .box = box,
            .connections = std.ArrayList(*Node).empty,
        };
        try nodes.put(box, &n);
    }

    var connections_made: u64 = 0;

    var i: u64 = 0;
    while (connections_made < num_connections_needed) : (i += 1) {
        const next_pair = dists[i];

        const n1 = nodes.get(next_pair.box1).?;
        const n2 = nodes.get(next_pair.box2).?;

        if (n1.is_connected(n2.*)) {
            std.debug.print("{any}\n", .{next_pair});
            continue;
        }

        try n1.connect(gpa, n2);
        connections_made += 1;
    }

    return 0;
}

const Node = struct {
    box: JunctionBox,
    connections: std.ArrayList(*Node),

    pub fn deinit(self: *Node, gpa: std.mem.Allocator) void {
        self.connections.deinit(gpa);
    }

    pub fn is_connected(self: Node, other: Node) bool {
        for (self.connections.items) |n| {
            if (n.equals(other) or n.is_connected(other)) {
                return true;
            }
        }

        return false;
    }

    pub fn connect(self: *Node, gpa: std.mem.Allocator, other: *Node) !void {
        try self.connections.append(gpa, other);
        try other.connections.append(gpa, self);
        return;
    }

    pub fn equals(self: Node, other: Node) bool {
        return self.box.equals(other.box);
    }
};

const DistancePairs = struct {
    box1: JunctionBox,
    box2: JunctionBox,
    distance: f64,

    fn less_than(_: void, a: DistancePairs, b: DistancePairs) bool {
        return a.distance < b.distance;
    }
};

fn get_sorted_list_of_distances(gpa: std.mem.Allocator, boxes: []JunctionBox) ![]DistancePairs {
    var pairs = std.ArrayList(DistancePairs).empty;
    defer pairs.deinit(gpa);

    for (boxes, 0..) |b1, i| {
        if (i == boxes.len - 1) {
            break;
        }
        for (boxes[i + 1 ..]) |b2| {
            try pairs.append(gpa, DistancePairs{
                .box1 = b1,
                .box2 = b2,
                .distance = b1.dist(b2),
            });
        }
    }

    const pairs_slice = try pairs.toOwnedSlice(gpa);
    std.mem.sort(DistancePairs, pairs_slice, {}, DistancePairs.less_than);

    return pairs_slice;
}

const JunctionBox = struct {
    x: usize,
    y: usize,
    z: usize,

    pub fn equals(self: JunctionBox, other: JunctionBox) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub fn dist(self: JunctionBox, other: JunctionBox) f64 {
        return @sqrt(difference_squared(self.x, other.x) +
            difference_squared(self.y, other.y) +
            difference_squared(self.z, other.z));
    }
};

fn difference_squared(n1: usize, n2: usize) f64 {
    return std.math.pow(f64, @as(f64, @floatFromInt(n1)) - @as(f64, @floatFromInt(n2)), 2.0);
}

fn read_file(gpa: std.mem.Allocator, filename: []const u8) !std.ArrayList(JunctionBox) {
    const Parser = struct {
        pub fn parse(_: std.mem.Allocator, line: []const u8) !JunctionBox {
            var split = std.mem.splitAny(u8, line, ",");
            return JunctionBox{
                .x = try std.fmt.parseInt(usize, split.next() orelse unreachable, 10),
                .y = try std.fmt.parseInt(usize, split.next() orelse unreachable, 10),
                .z = try std.fmt.parseInt(usize, split.next() orelse unreachable, 10),
            };
        }
    };

    const fileparser = utils.fileparse.PerLineParser(JunctionBox, Parser.parse).init(gpa);

    return fileparser.parse(filename);
}

test "AOC examples are right" {
    const allocator = std.testing.allocator;
    var boxes = try read_file(allocator, "example.txt");
    defer boxes.deinit(allocator);

    try std.testing.expectEqual(40, try part1(allocator, boxes.items, 10));
}
