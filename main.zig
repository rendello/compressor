const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const NodeTag = enum {
    internal,
    leaf
};
        //left: Node, // needs pointer
        //right: Node,

const Node = union(NodeTag) {
    internal: struct {
        count: u64
    },
    leaf: struct {
        byte: u8,
        count: u64
    }
};

fn build_table(text: []const u8) !void {
    var node_list = ArrayList(Node).init(&gpa.allocator);

    for (text) |byte, i| {
        for (node_list.items) |*node| {
            if (byte == node.leaf.byte) {
                node.leaf.count += 1;
            }
        }
    }
}

pub fn main() !void {
    print("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n============\n", .{});
    try build_table("Hello, world! It's-a-me, Marioooo!");
}

