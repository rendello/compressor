// Gaven Rendell, 2021.

//! Implementation of the Boyer–Moore–Horspool string-search algorithm.
//!
//! # Preprocess step:
//! The needle that will be searched for is first used to generate a table. Every byte of that
//! needle will be mapped to (needle_len - byte_index - 1). If the byte occurs multiple times, the
//! last occurence is used. If the byte is the last in the needle, it is equal to the len of the
//! needle, unless it already has a value, in which case it's left as-is.
//!
//! # Search step:
//! The needle is lined up with the start of the haystack. The last byte of the needle is compared
//! with the corresponding byte in the haystack. If it matches, the next-to-last byte is compared
//! and et cetera. If, at any point, there is a mismatch, the needle will jump forward `n` bytes,
//! where `n` is the value calculated in the preprocess step for the first byte checked against in
//! the haystack.

const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const assert = std.debug.assert;


fn preprocess(allocator: *Allocator, pattern: []const u8) !AutoHashMap(u8, u8) {
    assert(pattern.len <= 256);

    var map = AutoHashMap(u8, u8).init(allocator);

    for (pattern[0..pattern.len-1]) |byte, index| {
        var value = @intCast(u8, pattern.len - index - 1);
        try map.put(byte, value);
    }

    if (map.get(pattern[pattern.len-1]) == null) {
        try map.put(pattern[pattern.len-1], @intCast(u8, pattern.len));
    }

    return map;
}

test "preprocess" {
    const allocator = std.heap.page_allocator;
    var map = try preprocess(allocator, "TOOTH");
    try expect(map.get('T').? == 1);
    try expect(map.get('O').? == 2);
    try expect(map.get('H').? == 5);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var map = try preprocess(allocator, "TOOTH");
    print("{}", .{map});
}

