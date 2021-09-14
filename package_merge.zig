// Gaven Rendell, 2021.

//! See:
//! - Prefix/Huffman coding,
//! - Canonical Huffman,
//! - Package-merge algorithm.

const std = @import("std");
const math = std.math;
const expect = std.testing.expect;
const expectError = std.testing.expectError;


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

const Symbol = struct {
    /// 0-287.
    token: u8,
    count: u32
};

const PMError = error { NotEnoughBits, NoSymbolsToEncode };

/// Given a slice of symbols, sorted by ascending frequency, with unused symbols removed,
/// return the canonical representation of these symbols as a tuple of owned slices, with:
/// - The symbols in lexicographic order,
/// - The number of symbols for each bit-length.
fn package_merge(allocator: *std.mem.Allocator, symbols: []const Symbol, max_len: usize) !void {
    if (bits_needed_to_represent_int(symbols.len) > max_len)
        return PMError.NotEnoughBits;

    if (symbols.len == 0)
        return PMError.NoSymbolsToEncode;

    _ = allocator;

}

test "package merge fails on 0 symbols" {
    const allocator = std.heap.page_allocator;
    const symbols = [0]Symbol{};
    try expectError(PMError.NoSymbolsToEncode, package_merge(allocator, symbols[0..], 10));
}

test "package merge" {
    const allocator = std.heap.page_allocator;

    const symbols = [_]Symbol{
        Symbol{
            .token = 'A',
            .count = 10
        }
    };

    try package_merge(allocator, symbols[0..], 10);
}



//fn package_merge(allocator: *std.mem.Allocator, text: []const u8, max_len: u32) !*Node {
    // if (bits_needed_to_represent_int(symbols.len) < max_len)

//    // Build ArrayList of pointers to alloc'd leaf nodes.
//    var symbols = std.ArrayList(*Symbol).init(allocator);
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
//        var symbol: *Symbol = try allocator.create(Symbol);
//        symbol.* = Symbol { .leaf = .{ .byte = byte, .count = 1 } };
//        try symbols.append(symbol);
//    }
//}

