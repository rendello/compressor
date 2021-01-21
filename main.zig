const print = @import("std").debug.print;

const NodeVariant = enum {
    internal,
    leaf
};

var Node = union(NodeVariant) {
    internal: struct {
        left: Node,
        right: Node,
        count: u64
    },
    leaf: struct {
        bit: u1,
        count: u64
    }
};

fn build_tree(text: []const u8) !void {
    var byte_counts = [_]u8{0} ** 256;

    for (text) |byte, i| {
        byte_counts[byte] += 1;

        //print("{}\n", .{byte});
    }

    print("\n\n\n\n\nYOINK", .{});
    for (byte_counts) |bc, i| {
        print("{c} {}\n", .{@truncate(u8, i), bc});
    }
}

pub fn main() !void {
    try build_tree("Hellow world");
}

