// Gaven Rendell, 2021.

//! Implementation of the Boyer–Moore–Horspool string-search algorithm.
//!
//! # Preprocess step:
//! The needle that will be searched for is first used to generate a table. Every byte of that
//! needle is mapped to (needle_len - byte_index - 1). If the byte occurs multiple times, the
//! last occurence is used. If the byte is the last in the needle, it is equal to the length of the
//! needle, unless it already has a value, in which case it's left as-is.
//!
//! # Search step:
//! The needle is lined up with the start of the haystack. The last byte of the needle is compared
//! with the corresponding byte in the haystack. If it matches, the next-to-last byte is compared
//! and et cetera. If, at any point, there is a mismatch, the needle is moved forward `n` bytes,
//! where `n` is the value calculated in the preprocess step for the first byte checked against in
//! the haystack. If there is no value for the key `n`, the character in the haystack is not
//! present in the needle, and the entire length of the needle is skipped.

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const expect = std.testing.expect;


fn generate_bad_bytes_table(allocator: *Allocator, pattern: []const u8) !AutoHashMap(u8, u8) {
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

test "generate_bad_bytes_table" {
    const allocator = std.heap.page_allocator;
    var map = try generate_bad_bytes_table(allocator, "TOOTH");
    try expect(map.get('T').? == 1);
    try expect(map.get('O').? == 2);
    try expect(map.get('H').? == 5);
}

const MatchResult = union(enum) {
    match,
    no_match,
    skip: usize
};

inline fn check_match(haystack: []const u8, needle: []const u8, bad_byte_table: AutoHashMap(u8, u8)) MatchResult {
    var i: usize = needle.len;
    if (needle.len > haystack.len) return .no_match;

    while (i > 0) : (i -= 1) {
        if (needle[i-1] != haystack[i-1]) {
            var skip_opt = bad_byte_table.get(haystack[needle.len-1]);
            if (skip_opt) |skip| {
                return MatchResult { .skip = skip };
            } else {
                return MatchResult { .skip = needle.len };
            }
        }
    }
    return .match;
}

pub fn search(allocator: *Allocator, haystack: []const u8, needle: []const u8) ![][]const u8 {
    var bad_byte_table = try generate_bad_bytes_table(allocator, needle);
    defer bad_byte_table.deinit();

    var matches = ArrayList([]const u8).init(allocator);

    if (haystack.len < needle.len) return matches.toOwnedSlice(); // Empty.

    var i: usize = 0;
    while (i < haystack.len) {
        var match_result = check_match(haystack[i..], needle, bad_byte_table);
        switch (match_result) {
            .no_match => break,
            .skip  => |skip| i += skip,
            .match => {
                try matches.append(haystack[i..i+needle.len]);
                i += needle.len;
            }
        }
    }
    return matches.toOwnedSlice();
}

test "Search." {
    const allocator = std.heap.page_allocator;
    {
        const res = try search(allocator, "Hello, world!", "!");
        defer allocator.free(res);
        try expect(res[0][0] == '!');
    }
    {
        const res = try search(allocator, "I am the very model of a modern major general.", "mo");
        defer allocator.free(res);
        try expect(res.len == 2);
        try std.testing.expectEqualSlices(u8, res[0], "mo");
        try std.testing.expectEqualSlices(u8, res[1], "mo");
        try expect(@ptrToInt(res[0].ptr) < @ptrToInt(res[1].ptr));
    }
    {
        const res = try search(allocator, "A haystack.", "A longer needle.");
        defer allocator.free(res);
        try expect(res.len == 0);
    }
    {
        const res = try search(allocator, "A haystack.", "A needle...");
        defer allocator.free(res);
        try expect(res.len == 0);
    }
    {
        const res = try search(allocator, "A haystack.", "A haystack.");
        defer allocator.free(res);
        try expect(res.len == 1);
    }
    {
        const res = try search(allocator, "A", "B");
        defer allocator.free(res);
        try expect(res.len == 0);
    }
    {
        const res = try search(allocator, "A", "A");
        defer allocator.free(res);
        try expect(res.len == 1);
    }
}
