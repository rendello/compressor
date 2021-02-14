const std = @import("std");
const bb = @import("bitlist.zig");

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

/// Sort first by bit count, then by numerical precedence. Ascending.
fn compare_entries(ctx: void, a: Entry, b: Entry) bool {
    if (a.bit_count == b.bit_count) {
        return (a.byte < b.byte);
    } else {
        return (a.bit_count < b.bit_count);
    }
}

/// Fill `entries` list by walking the tree recurively.
fn entry_list_build(node: *Node, bit_count: u8, entries: *ArrayList(Entry)) std.mem.Allocator.Error!void {
    if (node.* == .internal) {
        try entry_list_build(node.internal.left, bit_count+1, entries);
        try entry_list_build(node.internal.right, bit_count+1, entries);
    } else if (node.* == .leaf) {
        try entries.append(Entry{.byte = node.leaf.byte, .bit_count = bit_count});
    }
}

fn table_build(root_node: *Node) ![]Entry {

    // Build and sort list of entries.
    var entries = try allocator.create(ArrayList(Entry));
    entries.* = ArrayList(Entry).init(allocator);

    try entry_list_build(root_node, 0, entries);
    std.sort.sort(Entry, entries.items, {}, compare_entries);

    // Build canonical table from sorted entries.

    return entries.toOwnedSlice();
}

fn file_build() !void {
    bit_counts = ArrayList(u8).init(allocator);

    var current_bit_count: u8 = 1;
    for (entry) |e| {
        if (current_bit_count < e.bit_count) {
            bit_counts.append(current_bit_count);
            current_bit_count = bit_count;
        }
    }
}

// Use arraylist of u1:
    // Memory inefficient (almost certainly byte-aligned)
// Use arraylist of u8:
    // Requires custom function
    // Potentially slower? Extending arraylist for u1 version likely to be slower
// Either case, store the number of bits in case it's not byte-aligned at the end
// Look into PackedIntIo in:
// https://github.com/ziglang/zig/blob/master/lib/std/packed_int_array.zig

// Maybe use arraylist of u1s and chunk them into a packed array every thousand
// entries or so?
////fn encode(text: []u8, entries: []Entry) !void {
////    var map = std.AutoHashMap(u8, []u1).init(test_allocator);
////
////    for (entries) |e| {
////
////    }
////}


////////////////////////////////////////////////////////////////////////////////

pub fn main() !void {
////    print("\n\n============\n----\n", .{});
////
////    var root: *Node = try tree_build(@embedFile("main.zig"));
////    var t = try table_build(root);

    //for (t) |e| {
    //    print("{}\n", .{e});
    //}

    var b = try bb.BitList.init(allocator);
// 01111001 01101111
    try b.append_bit(0);
    try b.append_bit(1);
    try b.append_bit(1);
    try b.append_bit(1);
    try b.append_bit(1);
    try b.append_bit(0);
    try b.append_bit(0);
    try b.append_bit(1);

    try b.append_bit(0);
    try b.append_bit(1);
    try b.append_bit(1);
    try b.append_bit(0);
    try b.append_bit(1);
    try b.append_bit(1);
    try b.append_bit(1);
    try b.append_bit(1);

    for (b.bytes.items) |item| {
        print("{} ", .{ item });
    }

    arena.deinit();
}
