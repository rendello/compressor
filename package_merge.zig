// Gaven Rendell, 2021.

//! See:
//! - Prefix/Huffman coding,
//! - Canonical Huffman,
//! - Package-merge algorithm.

const std = @import("std");
const math = std.math;
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;


inline fn bits_needed_to_represent_int(x: usize) usize {
    return if (x == 0) 0 else math.log2_int(usize, x) + 1;
}

test "bits needed to represent int" {
    try expect(bits_needed_to_represent_int(0) == 0);
    try expect(bits_needed_to_represent_int(1) == 1);
    try expect(bits_needed_to_represent_int(2) == 2);
    try expect(bits_needed_to_represent_int(7) == 3);
    try expect(bits_needed_to_represent_int(8) == 4);
    try expect(bits_needed_to_represent_int(10) == 4);
    try expect(bits_needed_to_represent_int(16) == 5);
    try expect(bits_needed_to_represent_int(math.maxInt(u8)) == 8);
    try expect(bits_needed_to_represent_int(math.maxInt(u16)) == 16);
    try expect(bits_needed_to_represent_int(math.maxInt(u16)+1) == 17);
}

const Item = struct {
    count: u32,
    token: ?u16
};

fn package(allocator: *Allocator, items: ArrayList) []Item {
    var packaged = std.ArrayList(Item).init(allocator);

    var i: usize = 0;
    while (i+2 <= items.len) : (i+=2) {
        const pairwise_sum = items[i].count + items[i+1].count;
        const p = Item {.count = pairwise_sum, .token = null};
        packaged.append(p);
    }
    return packaged.toOwnedSlice();
}

fn merge(allocator: *Allocator, items: []Item, packages: []Item) []Items {
    var merged = std.ArrayList(Item).init(allocator);

    for (packages) |p| {
        for (items) |item, i| {
            if (item.count >= p.count or i == items.len) {
                try list.insert(allocator, i, item);
            }
        }
    }
    return merged.toOwnedSlice();
}


const PMError = error { NotEnoughBits, NoItemsToEncode };

///// Given a slice of symbols, sorted by ascending frequency, with unused symbols removed,
///// return the canonical representation, which the caller must free.
//fn package_merge(allocator: *Allocator, symbols: []const Item, max_len: usize) !void {
//    _ = allocator;
//
//    if (bits_needed_to_represent_int(symbols.len) > max_len)
//        return PMError.NotEnoughBits;
//
//    if (symbols.len == 0)
//        return PMError.NoItemsToEncode;
//
//    {
//        var i: usize = 0;
//        while (i+2 <= symbols.len) {
//            var pairwise_sum = symbols[i].count + symbols[i+1].count;
//            try merge(allocator,
//            i += 2;
//        }
//    }
//}
//
//test "package merge fails on 0 symbols" {
//    const allocator = std.heap.page_allocator;
//    const symbols = [0]Item{};
//    try expectError(PMError.NoItemsToEncode, package_merge(allocator, symbols[0..], 10));
//}
//
//test "package merge" {
//    const allocator = std.heap.page_allocator;
//
//    const symbols = [_]Item{
//        Item{
//            .token = 'A',
//            .count = 10
//        }
//    };
//
//    try package_merge(allocator, symbols[0..], 10);
//}
//


//fn package_merge(allocator: *Allocator, text: []const u8, max_len: u32) !*Node {
    // if (bits_needed_to_represent_int(symbols.len) < max_len)

//    // Build ArrayList of pointers to alloc'd leaf nodes.
//    var symbols = std.ArrayList(*Item).init(allocator);
//    defer symbols.deinit();
//
//    outer: for (text) |byte| {
//        for (symbols.items) |symbol| {
//            if (byte == symbol.token) {
//                symbol.count += 1;
//                continue :outer;
//            }
//        }
//
//        // Reached only if byte not yet found.
//        var symbol: *Item = try allocator.create(Item);
//        symbol.* = Item { .leaf = .{ .byte = byte, .count = 1 } };
//        try symbols.append(symbol);
//    }
//}


///// The symbols in lexicographic order, along with the count of symbols for each bit-length.
///// Eg. A value of {1,1,2} means the first symbol in `symbols` has a
///// bit-length of 1, the next 1 has length 2, and the next two have length 3.
//const CanonicalRepresentation = struct {
//    symbols: []const u8,
//    count_per_bit_length: []const u32,
//};
