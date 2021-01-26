const std = @import("std");
const print = std.debug.print;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const NodeTag = enum {
    internal,
    leaf
};

const Node = union(NodeTag) {
    internal: struct {
        left: *Node,
        right: *Node,
        count: u64
    },
    leaf: struct {
        byte: u8,
        count: u64
    },
    fn get_count(self: Node) u64 {
        return switch (self) {
            .leaf => self.leaf.count,
            .internal => self.internal.count
        };
    }
};


/// Compare nodes by count. Descending.
fn compare_nodes(ctx: void, a: Node, b: Node) bool {
    return a.get_count() > b.get_count();
}

fn build_table(text: []const u8) !void {

    // Build and sort array of leaf nodes.
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

    // Build tree.
    while (nodes.items.len > 1) {
        std.sort.sort(Node, nodes.items, {}, compare_nodes);
        var child_left = nodes.pop();
        var child_right = nodes.pop();

        var node = Node {
            .internal = .{
                .left = &child_left,
                .right = &child_right,
                .count = child_left.get_count() + child_right.get_count()
            }
        };
        try nodes.append(node);
    }

    var root: Node = nodes.pop();

    print("{}", .{ root.get_count() } );
}

pub fn main() !void {
    print("\n\n============\n", .{});
    //try build_table("Hello, world! It's-a-me, Marioooo! I listen to ZZ Top!");

    try build_table(@embedFile("main.zig"));
}
