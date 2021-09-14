// SPDX-License-Identifier: BSD-2-Clause

// https://news.ycombinator.com/item?id=12334270

const std = @import("std");

const print = std.debug.print;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var allocator = &arena.allocator;


// Tree construction ===========================================================

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
// todo: read files through 4K / page-sized chunks.
//       Would this matter? Buffer size for the compressed file would still be
//       large. Can't chunk compressed buffer easily since header data at the
//       start of the file changes at end of processing.
// todo: use package-merge algorithm to ensure length-limited codes.
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

    for (nodes.items) |n| {
        if (n.* == .leaf) {
            print("{X} {c} = {}\n", .{n.leaf.byte, n.leaf.byte, n.get_count()});
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

// BitList =====================================================================

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
            self.bytes.items[self.bit_index/8] |= @as(u8, 128) >> self.get_trailing_bit_count();
        }
        self.bit_index += 1;
    }

    pub fn get_trailing_bit_count(self: *BitList) u3 {
        return @intCast(u3, self.bit_index-(self.bit_index/8*8));
    }

    pub fn append_code_word(self: *BitList, cw: CodeWord) !void {
        var i: u8 = 0;
        while (i < cw.used) : (i += 1) {
            try self.append_bit(cw.get_bit(i));
        }
    }

    pub fn append_bytes(self: *BitList, bytes: []u8) !void {
        for (bytes) |byte| {
            var i: u8 = 0;
            while (i < 8) : (i += 1) {
                try self.append_bit(@intCast(u1, (byte >> @intCast(u3, 7 - i)) & 1));
            }
        }
    }

   // pub fn append(self: *BitList, comptime T: type, data: T) !void {
   //     var i: u32 = 0;
   //     while (i < @sizeOf(T)) : (i += 1) {
   //         try self.append_bit(@intCast(u1, (data >> (@sizeOf(T)-1) - i) & 1));
   //     }
   // }

    pub fn append_byte(self: *BitList, byte: u8) !void {
        var i: u8 = 0;
        while (i < 8) : (i += 1) {
            try self.append_bit(@intCast(u1, (byte >> @intCast(u3, 7 - i)) & 1));
        }
    }

    pub fn append_padding(self: *BitList, count: u32) !void {
        var i: i32 = 0;
        while (i < count) : (i += 1) {
            try self.append_bit(0);
        }
    }
};

// Table construction ==========================================================

const Entry = struct {
    byte: u8,
    bit_count: u6
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
fn entry_list_build(node: *Node, bit_count: u6, entries: *std.ArrayList(Entry)) std.mem.Allocator.Error!void {
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
    fn get_bit(self: CodeWord, index: u8) u1 {
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

/// Although `map` is all that is needed to encode the data, `entries` provides
/// the orer for the bytes, which is required to build the canonical header.
const Table = struct {
    map: [256]?CodeWord,
    entries: std.ArrayList(Entry)
};

/// Build and return canonical table from the Huffman tree.
// todo: also return sorted entries and bit-length counts so table can be
//       canonically encoded in the file.
fn table_build(root_node: *Node) !*Table {

    // Build and sort list of entries.
    var entries = std.ArrayList(Entry).init(allocator);
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

    var map = [_]?CodeWord {null} ** 256;

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
    var t = try allocator.create(Table);
    t.* = Table { .map=map, .entries=entries };

    return t;
}

// Checksum ====================================================================

fn hash_FNV1a(data: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (data) |byte| {
        hash = (byte ^ hash) *% 16777619;
    }
    return hash;
}

// =============================================================================

/// Encode entire file / stream.
fn encode(text: []const u8) !void {
    var table = try table_build(try tree_build(text));

    var i: u8 = 0;
    while (i < 255) : (i += 1) {
        if (table.map[i]) |element| {
            print("{} {c} = ", .{i, i});
            element.print_bits();
        }
    }

    var data = try BitList.init(allocator);

    // Write signature and make room for header fields.
    var signature = [_]u8{'R','Z'};
    try data.append_bytes(signature[0..]);
    try data.append_padding(49);

//    // => Add count of bit count values.
//    // => Add bit count values.
//
//    var bc_counts = [_]u6 {0} ** 256;
//    var highest_bit_count: u6 = 0;
//
//    for (table.entries.items) |e| {
//        bc_counts[e.bit_count] += 1;
//        if (e.bit_count > highest_bit_count) {
//            highest_bit_count = e.bit_count;
//        }
//    }
//    try data.append(u6, highest_bit_count);
//    for (bc_counts[0..highest_bit_count]) |bc_count| {
//        data.append(u6, bc_count);
//    }
//
//
//    // Append present bytes in order.
//    for (table.entries.items) |e| {
//        try data.append_byte(e.byte);
//    }
//
//    // Encode and append data.
//    for (text) |byte| {
//        try data.append_code_word(table.map[byte].?);
//    }
//
//    // Calculate header fields, add to header.
//    const trailing_bit_count: u3 = data.get_trailing_bit_count();
//
    for (data.bytes.items) |item| {
        print("{X:0>2}", .{ item });
    }
    print("\n", .{});
}

/// Decode entire file / stream.
fn decode(data: []const u8) !void {
    // todo: decode using u64 and bitmasks.
    // iterate through "table" (array) from most to least likely, ie lowest
    // numerical value to highest.
    // No need for hash table, all values will be numerically unique.

    // Bitmasked values will have to be shifted?
    // Could bitshift values in table instead.
}


pub fn main() !void {
    print("\n\n============\n----\n", .{});

    try encode(@embedFile("main.zig"));

    arena.deinit();
}
