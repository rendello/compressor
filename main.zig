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
            print("Leaf node:\n  Count: {}\n  Byte: {} « {c} »\n\n", .{ self.leaf.count, self.leaf.byte, self.leaf.byte});
        } else if (self == .internal) {
            print("Internal node:\n  Count: {}\n  Left: {}\n  Right: {}\n\n", .{self.internal.count, self.internal.left, self.internal.right});
        }
    }
    fn print_recursive(self: Node) void {
        //switch (*self) {
        //    .internal => |i| {
        //        print("=========\nInternal node:\n", .{});
        //        i.left.print_recursive();
        //        //i.right.print_recursive();
        //    },
        //    .leaf => |i| {
        //        print("-> Leaf node:\n", .{});
        //    }
        //}
        if (self == .leaf) {
            print("-> Leaf node:\n", .{});
        } else if (self == .internal) {
            print("=========\nInternal node:\n", .{});
            self.internal.right.print_recursive();
        }
    }
};


/// Compare nodes by count. Descending.
fn compare_nodes(ctx: void, a: Node, b: Node) bool {
    return a.get_count() > b.get_count();
}

fn build_tree(text: []const u8) !Node {

    // Build and sort array of leaf nodes.
    var nodes = std.ArrayList(Node).init(&gpa.allocator);
    defer nodes.deinit();

    outer: for (text) |byte, i| {
        var found: bool = false;

        for (nodes.items) |*node| {
            if (byte == node.leaf.byte) {
                node.leaf.count += 1;
                continue :outer;
            }
        }
        if (!found) {
            var node_ptr: *Node = try gpa.allocator.create(Node);
            node_ptr.* = Node { .leaf = .{ .byte = byte, .count = 1 } };
            try nodes.append(node_ptr.*);
        }
    }

    // Build tree.
    while (nodes.items.len > 1) {
        std.sort.sort(Node, nodes.items, {}, compare_nodes);
        var child_left = nodes.pop();
        var child_right = nodes.pop();

        var node_ptr: *Node = try gpa.allocator.create(Node);
        node_ptr.* = Node {
            .internal = .{
                .left = &child_left,
                .right = &child_right,
                .count = child_left.get_count() + child_right.get_count()
            }
        };
        try nodes.append(node_ptr.*);

        ////var count: u64 = 0;
        ////var num: u64 = 0;
        ////for (nodes.items) |item| {
        ////    print("{} ", .{ item.get_count() });
        ////    count += item.get_count();
        ////    num += 1;
        ////}
        ////print("= {} ({} elems) \n", .{count, num});

        print("========================\n========================\n", .{});
        for (nodes.items) |item| {
            item.print();
        }
        print("Count: {} ({} + {})\n", .{child_left.get_count() + child_right.get_count(), child_left.get_count(), child_right.get_count()});
    }

    //nodes.items[0].print_recursive();
    return nodes.pop();  // Tree root.
}

fn build_table(root: Node) !void {
    
}

pub fn main() !void {
    print("\n\n============\n", .{});

    var root: Node = try build_tree(@embedFile("main.zig"));
    try build_table(root);
}
