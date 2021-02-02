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
    fn print(self: Node) void {
        if (self == .leaf) {
            print("Leaf node:\n  Count: {}\n  Byte: {} « {c} »\n\n",
            .{ self.leaf.count, self.leaf.byte, self.leaf.byte});
        } else if (self == .internal) {
            print("Internal node:\n  Count: {}\n  Left: {}\n  Right: {}\n\n",
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

/// Compare nodes by count. Descending.
fn compare_nodes(ctx: void, a: *Node, b: *Node) bool {
    return a.*.get_count() > b.*.get_count();
}

/// Build binary tree.
/// Caller must deallocate tree nodes.
fn tree_build(text: []const u8) !*Node {

    // Build ArrayList of pointers to alloc'd leaf nodes.
    var nodes = std.ArrayList(*Node).init(&gpa.allocator);
    defer nodes.deinit();

    outer: for (text) |byte| {
        for (nodes.items) |node| {
            if (byte == node.leaf.byte) {
                node.leaf.count += 1;
                continue :outer;
            }
        }
        // Reached if byte not in `nodes`.
        var node: *Node = try gpa.allocator.create(Node);
        node.* = Node { .leaf = .{ .byte = byte, .count = 1 } };
        try nodes.append(node);
    }

    // Build tree.
    while (nodes.items.len > 1) {
        std.sort.sort(*Node, nodes.items, {}, compare_nodes);
        var child_left: *Node = nodes.pop();
        var child_right: *Node = nodes.pop();

        var node: *Node = try gpa.allocator.create(Node);
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

/// Return HashMap of characters and their codes.
/// Essentially a functional wrapper for `table_build_internal`.
fn table_build(root_node: *Node) !void {
    var prefix = try gpa.allocator.alloc(u1, 0);
    var char_map = std.AutoHashMap(u8, []u1).init(&gpa.allocator);

    //table_build_internal(root_node, prefix, *char_map);
}

// todo don't pass arraylist, pass slice. Args are immutable, so pass slice + bit to next call.
fn table_build_internal(node: *Node, prefix: []u1, char_map: *std.AutoHashMap(u8, []u1)) !void {

}

pub fn main() !void {
    print("\n\n============\n", .{});

    var root: *Node = try tree_build(@embedFile("main.zig"));

    try table_build(root);
}
