const std = @import("std");
const print = std.debug.print;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const NodeTag = enum {
    internal,
    leaf
};

const Node = union(NodeTag) {
    internal: struct {
        //left: Node, // needs pointer
        //right: Node,
        count: u64
    },
    leaf: struct {
        byte: u8,
        count: u64
    }
};

/// Compare nodes by count. Descending.
fn compare_nodes(ctx: void, a: Node, b: Node) bool {
    return a.leaf.count < b.leaf.count;
}

fn build_table(text: []const u8) !void {
    var nodes = std.ArrayList(Node).init(&gpa.allocator);

    outer: for (text) |byte, i| {
        var found: bool = false;

        for (nodes.items) |*node| {
            if (byte == node.leaf.byte) {
                node.leaf.count += 1;
                continue :outer;
            }
        }
        if (!found) {
            var node = Node { .leaf = .{ .byte = byte, .count = 1 } };
            try nodes.append(node);
        }
    }
    std.sort.sort(Node, nodes.items, {}, compare_nodes);
    for (nodes.items) |node| {
        print("{c} {}\n", .{node.leaf.byte, node.leaf.count});
    }
}

pub fn main() !void {
    print("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n============\n", .{});
    try build_table("Hello, world! It's-a-me, Marioooo! I listen to ZZ Top!");
}

