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
/// Caller must free `byte_map`, and the patterns in `byte_map`.
fn table_build(root_node: *Node) !*std.AutoHashMap(u8, []u1) {
    var pattern = try gpa.allocator.alloc(u1, 0);
    defer gpa.allocator.free(pattern);

    var byte_map = std.AutoHashMap(u8, []u1).init(&gpa.allocator);

    try table_build_internal(root_node, pattern, &byte_map);

    return &byte_map;
}

/// Build HashMap of character and their codes recursively.
/// Don't call directly, use the functional `table_build` wrapper.
fn table_build_internal(node: *Node, pattern: []u1,
        byte_map: *std.AutoHashMap(u8, []u1)) std.mem.Allocator.Error!void {

    if (node.* == .internal) {
        var l_pattern: []u1 = try gpa.allocator.alloc(u1, pattern.len+1);
        std.mem.copy(u1, l_pattern, pattern);
        l_pattern[l_pattern.len-1] = 0;
        try table_build_internal(node.internal.left, l_pattern, byte_map);

        var r_pattern: []u1 = try gpa.allocator.alloc(u1, pattern.len+1);
        std.mem.copy(u1, r_pattern, pattern);
        r_pattern[r_pattern.len-1] = 1;
        try table_build_internal(node.internal.right, r_pattern, byte_map);

        // => allocate slice of size pattern+1, append 0
        // => table_build_internal(node.left, l_pattern)

        // => allocate slice of size pattern+1, append 1
        // => table_build_internal(node.right, r_pattern)

        // => free(l_pattern)
        // => free(r_pattern)

    } else if (node.* == .leaf) {
        // => byte_map[byte] = pattern
        print("{c} {}\n", .{node.leaf.byte, pattern});
        try byte_map.put(node.leaf.byte, pattern);
    }
}

pub fn main() !void {
    print("\n\n============\n", .{});

    var root: *Node = try tree_build(@embedFile("main.zig"));

    var byte_map = try table_build(root);

    print("\n\n------------\n", .{});
    print("{}", .{ byte_map.get(' ') });
}
