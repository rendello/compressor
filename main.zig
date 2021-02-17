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

/// Build Huffman (binary) tree.
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

// BitList /////////////////////////////////////////////////////////////////////

/// An ArrayList of bytes that can have bits appended to it directly.
pub const BitList = struct {
    bytes: std.ArrayList(u8) = undefined,
    bit_index: u32 = 0,

    pub fn init(a: *std.mem.Allocator) !BitList {
        return BitList {.bytes = std.ArrayList(u8).init(a)};
    }
    /// Shift bits into list, left-to-right. Add bytes if needed.
    pub fn append_bit(self: *BitList, bit: u1) !void {
        if (self.bytes.items.len*8 < self.bit_index+1) {
            try self.bytes.append(0);
        }
        if (bit == 1) {
            self.bytes.items[self.bit_index/8] |= @as(u8, 128) >> self.get_trailing_bits();
        }
        self.bit_index += 1;
    }
    pub fn get_trailing_bits(self: *BitList) u3 {
        return @intCast(u3, self.bit_index-(self.bit_index/8*8));
    }
    pub fn append_code_word(self: BitList, cw: CodeWord) !void {
        var i: u8 = 0;
        while (i < cw.used) : (i += 1) {
            self.append_bit(cw.get_bit(i));
        }
    }
};

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

/// Fill `entries` list by walking the tree recursively.
fn entry_list_build(node: *Node, bit_count: u8, entries: *ArrayList(Entry)) std.mem.Allocator.Error!void {
    if (node.* == .internal) {
        try entry_list_build(node.internal.left, bit_count+1, entries);
        try entry_list_build(node.internal.right, bit_count+1, entries);
    } else if (node.* == .leaf) {
        try entries.append(Entry{.byte = node.leaf.byte, .bit_count = bit_count});
    }
}

/// The pattern of bits to map a byte to. Essentially just a big integer and
/// the number of bits that are used.
const CodeWord = struct {
    pattern: u64 = undefined,
    used: u8 = undefined,

    /// Get bit at index of pattern. Left to right.
    fn get_bit(self: CodeWord, index: u8) ?u1 {
        // (Subtract one from `.used` as indexing is zero-based.)
        return @intCast(u1, ((self.pattern) >> @intCast(u6, self.used-1-index)) & 1);
    }

    fn print_bits(self: CodeWord) void {
        var j: u8 = 0;
        while (j < self.used) : (j += 1) {
            print("{}", .{self.get_bit(j)});
        }
        print("\n", .{});
    }
};

/// Build and return canonical table from the Huffman tree.
// todo: use package-merge algorithm to ensure length-limited codes.
fn table_build(root_node: *Node) !*[256]?CodeWord {

    // Build and sort list of entries.
    var entries = ArrayList(Entry).init(allocator);
    try entry_list_build(root_node, 0, &entries);
    std.sort.sort(Entry, entries.items, {}, compare_entries);

    // Build canonical table from sorted entries.

    // First symbol:
    // - Pattern is the same length of its original, but all zeros.
    // 
    // Subsequent symbols:
    // - Pattern is incremented by one mathematically.
    // - If original pattern is longer than previous symbol's, everything is
    //   shifted over to the right by the difference. Right shift and update
    //   `used` bits.

    var map = try allocator.create([256]?CodeWord);
    map.* = [_]?CodeWord {null} ** 256;

    var used: u8 = entries.items[0].bit_count;
    var pattern: u64 = 0;
    map[entries.items[0].byte] = CodeWord{ .pattern=pattern, .used=used };

    for (entries.items[1..]) |entry| {
        pattern += 1;

        var bc_diff: u8 = entry.bit_count - used;
        if (bc_diff > 0) {
            pattern <<= @intCast(u6, bc_diff);
            used += bc_diff;
        }
        map[entry.byte] = CodeWord{.pattern=pattern, .used=used};
    }
    return map;
}

// Checksum ////////////////////////////////////////////////////////////////////

fn hash_FNV1a(data: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (data) |byte| {
        hash = (byte ^ hash) *% 16777619;
    }
    return hash;
}

////////////////////////////////////////////////////////////////////////////////

pub fn main() !void {
    print("\n\n============\n----\n", .{});

    var root: *Node = try tree_build(@embedFile("main.zig"));
    var t = try table_build(root);

    /////var i: u8 = 0;
    /////while (i < 255) : (i += 1) {
    /////    if (t[i] != null) {
    /////        print("{} {c} = ", .{i, i});
    /////        t[i].?.print_bits();
    /////    } else {
    /////        //print("{} {c} = n/a\n", .{i, i});
    /////    }
    /////}

    //// var b = try BitList.init(allocator);

    //// try b.append_bit(0);
    //// try b.append_bit(1);
    //// try b.append_bit(1);
    //// try b.append_bit(1);
    //// try b.append_bit(1);
    //// try b.append_bit(0);
    //// try b.append_bit(0);
    //// try b.append_bit(1);

    //// try b.append_bit(0);
    //// try b.append_bit(1);
    //// try b.append_bit(1);
    //// try b.append_bit(0);
    //// try b.append_bit(1);
    //// try b.append_bit(1);
    //// try b.append_bit(1);
    //// try b.append_bit(1);

    //// for (b.bytes.items) |item| {
    ////     print("{} ", .{ item });
    //// }

    arena.deinit();
}
