// Gaven Rendell, 2021.

// todo: use package-merge algorithm to ensure length-limited codes.

const std = @import("std");
const expect = std.testing.expect;

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
    fn print(self: Node) void {
        if (self == .leaf) {
            std.debug.print("Leaf node:\n  Count: {}\n  Byte: {} « {c} »\n\n",
            .{ self.leaf.count, self.leaf.byte, self.leaf.byte});
        } else if (self == .internal) {
            std.debug.print("Internal node:\n  Count: {}\n  Left: {}\n  Right: {}\n\n",
            .{self.internal.count, self.internal.left, self.internal.right});
        }
    }
    fn print_recursive(self: *Node) void {
        self.print();
        if (self.* == .internal) {
            self.internal.left.print_recursive();
            self.internal.right.print_recursive();
        }
    }
};

fn compare_nodes_desc(ctx: void, a: *Node, b: *Node) bool {
    _ = ctx;
    return a.get_count() > b.get_count();
}

/// Build Huffman (binary) tree.
/// Caller must free the tree.
// todo: read files through 4K / page-sized chunks.
fn tree_build(allocator: *std.mem.Allocator, text: []const u8) !*Node {

    // Build ArrayList of pointers to alloc'd leaf nodes.
    var nodes = std.ArrayList(*Node).init(allocator);
    defer nodes.deinit();

    outer: for (text) |byte| {
        for (nodes.items) |node| {
            if (byte == node.leaf.byte) {
                node.leaf.count += 1;
                continue :outer;
            }
        }

        // Reached only if byte not in `nodes`.
        var node: *Node = try allocator.create(Node);
        node.* = Node { .leaf = .{ .byte = byte, .count = 1 } };
        try nodes.append(node);
    }

    for (nodes.items) |n| {
        if (n.* == .leaf) {
            std.debug.print("{X} {c} = {}\n", .{n.leaf.byte, n.leaf.byte, n.get_count()});
        }
    }

    // Build tree.
    while (nodes.items.len > 1) {
        std.sort.sort(*Node, nodes.items, {}, compare_nodes_desc);
        var child_left: *Node = nodes.pop();
        var child_right: *Node = nodes.pop();

        var node: *Node = try allocator.create(Node);
        node.* = Node {
            .internal = .{
                .left = child_left,
                .right = child_right,
                .count = child_left.get_count() + child_right.get_count()
            }
        };
        try nodes.append(node);
    }
    return nodes.pop();  // Tree root.
}


pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const tree = tree_build(allocator, "Hello, world!");
    //std.debug.print("{}", tree);
    _ = try tree;
}
