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
    std.debug.print("Part 2: {d}\n", .{try part2(allocator, boxes.items)});
}

pub fn part1(gpa: std.mem.Allocator, boxes: []JunctionBox, num_connections_needed: u64) !u64 {
    const dists = try get_sorted_list_of_distances(gpa, boxes);
    defer gpa.free(dists);

    var nodes = try std.ArrayList(Node).initCapacity(gpa, boxes.len);
    defer {
        for (nodes.items) |*n| {
            n.deinit(gpa);
        }
        nodes.deinit(gpa);
    }

    var nodes_map = std.AutoHashMap(JunctionBox, *Node).init(gpa);
    defer nodes_map.deinit();

    // init nodes
    for (boxes, 0..) |box, i| {
        const n = Node{
            .box = box,
            .connections = std.ArrayList(*Node).empty,
        };

        nodes.appendAssumeCapacity(n);

        try nodes_map.put(box, &nodes.items[i]);
    }

    for (0..num_connections_needed) |i| {
        const next_pair = dists[i];

        const n1 = nodes_map.get(next_pair.box1).?;
        const n2 = nodes_map.get(next_pair.box2).?;

        if (try n1.is_connected(gpa, n2.*)) {
            continue;
        }

        try n1.connect(gpa, n2);
    }

    const circuits = try get_circuits(gpa, nodes.items);
    defer {
        for (circuits) |circuit| {
            gpa.free(circuit);
        }
        gpa.free(circuits);
    }
    std.mem.sort([]JunctionBox, circuits, {}, desc_by_len(JunctionBox));

    var answer: u64 = 1;

    for (circuits[0..3]) |circuit| {
        answer *= circuit.len;
    }

    return answer;
}

pub fn part2(gpa: std.mem.Allocator, boxes: []JunctionBox) !u64 {
    const dists = try get_sorted_list_of_distances(gpa, boxes);
    defer gpa.free(dists);

    var nodes = try std.ArrayList(Node).initCapacity(gpa, boxes.len);
    defer {
        for (nodes.items) |*n| {
            n.deinit(gpa);
        }
        nodes.deinit(gpa);
    }

    var nodes_map = std.AutoHashMap(JunctionBox, *Node).init(gpa);
    defer nodes_map.deinit();

    // init nodes
    for (boxes, 0..) |box, i| {
        const n = Node{
            .box = box,
            .connections = std.ArrayList(*Node).empty,
        };

        nodes.appendAssumeCapacity(n);

        try nodes_map.put(box, &nodes.items[i]);
    }

    var connections_made: u64 = 0;
    var i: u64 = 0;
    while (connections_made < boxes.len - 1) : (i += 1) {
        const next_pair = dists[i];

        const n1 = nodes_map.get(next_pair.box1).?;
        const n2 = nodes_map.get(next_pair.box2).?;

        if (try n1.is_connected(gpa, n2.*)) {
            continue;
        }

        try n1.connect(gpa, n2);
        connections_made += 1;
    }

    return dists[i - 1].box1.x * dists[i - 1].box2.x;
}

fn desc_by_len(comptime T: type) fn (void, []T, []T) bool {
    const Sorter = struct {
        fn less_than(_: void, a: []T, b: []T) bool {
            return a.len > b.len;
        }
    };
    return Sorter.less_than;
}

fn get_circuits(gpa: std.mem.Allocator, nodes: []Node) ![][]JunctionBox {
    var visited = std.ArrayList(JunctionBox).empty;
    defer visited.deinit(gpa);

    var circuits = std.ArrayList([]JunctionBox).empty;
    defer circuits.deinit(gpa);

    for (nodes) |n| {
        if (circuit_contains(visited.items, n.box)) {
            continue;
        }
        const new_circuit = try n.get_circuit(gpa);
        try circuits.append(gpa, new_circuit);
        for (new_circuit) |box| {
            try visited.append(gpa, box);
        }
    }

    return circuits.toOwnedSlice(gpa);
}

const Node = struct {
    box: JunctionBox,
    connections: std.ArrayList(*Node),

    pub fn deinit(self: *Node, gpa: std.mem.Allocator) void {
        self.connections.deinit(gpa);
    }

    pub fn is_connected(self: Node, gpa: std.mem.Allocator, other: Node) !bool {
        var visited = std.ArrayList(JunctionBox).empty;
        defer visited.deinit(gpa);

        return self.check_is_connected(gpa, other, &visited);
    }

    fn check_is_connected(self: Node, gpa: std.mem.Allocator, other: Node, visited: *std.ArrayList(JunctionBox)) !bool {
        if (self.equals(other)) {
            return true;
        }

        if (circuit_contains(visited.items, self.box)) {
            return false;
        }

        try visited.append(gpa, self.box);

        for (self.connections.items) |n| {
            if (try n.check_is_connected(gpa, other, visited)) {
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

    pub fn get_circuit(self: Node, gpa: std.mem.Allocator) ![]JunctionBox {
        var circuit = std.ArrayList(JunctionBox).empty;
        defer circuit.deinit(gpa);

        try self.add_connections_to_circuit(gpa, &circuit);

        return circuit.toOwnedSlice(gpa);
    }

    fn add_connections_to_circuit(self: Node, gpa: std.mem.Allocator, circuit: *std.ArrayList(JunctionBox)) !void {
        try circuit.append(gpa, self.box);
        for (self.connections.items) |n| {
            if (!circuit_contains(circuit.items, n.box)) {
                try n.add_connections_to_circuit(gpa, circuit);
            }
        }
        return;
    }
};

fn circuit_contains(circuit: []JunctionBox, box: JunctionBox) bool {
    for (circuit) |other_box| {
        if (box.equals(other_box)) {
            return true;
        }
    }
    return false;
}

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

pub const JunctionBox = struct {
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

pub fn read_file(gpa: std.mem.Allocator, filename: []const u8) !std.ArrayList(JunctionBox) {
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
    try std.testing.expectEqual(25272, try part2(allocator, boxes.items));
}
