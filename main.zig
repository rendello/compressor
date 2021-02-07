const std = @import("std");
const print = std.debug.print;

const ArrayList = std.ArrayList;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var allocator = &arena.allocator;


// Tree construction ///////////////////////////////////////////////////////////

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

fn compare_nodes_desc(ctx: void, a: *Node, b: *Node) bool {
    return a.get_count() > b.get_count();
}

/// Build binary tree.
fn tree_build(text: []const u8) !*Node {

    // Build ArrayList of pointers to alloc'd leaf nodes.
    var nodes = std.ArrayList(*Node).init(allocator);

    outer: for (text) |byte| {
        for (nodes.items) |node| {
            if (byte == node.leaf.byte) {
                node.leaf.count += 1;
                continue :outer;
            }
        }
        // Reached if byte not in `nodes`.
        var node: *Node = try allocator.create(Node);
        node.* = Node { .leaf = .{ .byte = byte, .count = 1 } };
        try nodes.append(node);
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


// Table construction //////////////////////////////////////////////////////////

const Entry = struct {
    byte: u8,
    bit_count: u8
};

/// Sort by bit count, then by numerical precedence. Ascending.
fn compare_entries(ctx: void, a: Entry, b: Entry) bool {
    if (a.bit_count == b.bit_count) {
        return (a.byte < b.byte);
    } else {
        return (a.bit_count < b.bit_count);
    }
}

fn entry_list_build(node: *Node, bit_count: u8, entries: *ArrayList(Entry)) std.mem.Allocator.Error!void {
    if (node.* == .internal) {
        try entry_list_build(node.internal.left, bit_count+1, entries);
        try entry_list_build(node.internal.right, bit_count+1, entries);
    } else if (node.* == .leaf) {
        try entries.append(Entry{.byte = node.leaf.byte, .bit_count = bit_count});
    }
}

fn table_build(root_node: *Node) !void {

    // Build list of entries recursively.
    var entries = try allocator.create(ArrayList(Entry));
    entries.* = ArrayList(Entry).init(allocator);

    try entry_list_build(root_node, 0, entries);

    // Canonicalize the list.
    std.sort.sort(Entry, entries.items, {}, compare_entries);

    for (entries.items) |item| {
        print("{}\n", .{item});
    }
}


////////////////////////////////////////////////////////////////////////////////

pub fn main() !void {
    print("\n\n============\n----\n", .{});

    var root: *Node = try tree_build(@embedFile("main.zig"));
    try table_build(root);

    arena.deinit();
}
