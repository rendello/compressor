// Gaven Rendell, 2021.

//! Reference: "SIMD-friendly algorithms for substring searching" by Wojciech Muła.

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const expect = std.testing.expect;
const print = std.debug.print;
const Vector = std.meta.Vector;

const utils = @import("utils.zig");

const vec_size = utils.get_SIMD_vector_size_in_bytes();
const min_match_size = 3;

inline fn vec_splat(byte: u8) Vector(vec_size, u8) {
    return @splat(vec_size, @as(u8, byte));
}

inline fn vec_AND(vec_1: Vector(vec_size, bool), vec_2: Vector(vec_size, bool)) Vector(vec_size, u8) {
    const vec_1_int = @select(u8, vec_1, @splat(vec_size, @as(u8, 1)), @splat(vec_size, @as(u8, 0)));
    const vec_2_int = @select(u8, vec_2, @splat(vec_size, @as(u8, 1)), @splat(vec_size, @as(u8, 0)));
    return vec_1_int & vec_2_int;
}

inline fn quick_eql(a: []const u8, b: []const u8) bool {
    for (a) |item, index| {
        if (b[index] != item) {
            return false;
        }
    }
    return true;
}

const Match = struct {
    len: usize,
    distance: usize,
};

inline fn check_potential_match(
    window: []const u8,
    search_buff: []const u8,
    index: usize,
    mask_index: usize,
    outer_target_len: usize
) ?Match {
    const match_start = index + mask_index;
    var target_len = outer_target_len;

    // (Don't compare first or last byte, they've been verified.)
    if (quick_eql(window[match_start+1..match_start+target_len], search_buff[1..target_len])) {
        while (target_len < search_buff.len and window[match_start+target_len] == search_buff[target_len]) {
            target_len += 1;
        }
        return Match { .len = target_len, .distance = window.len - (index + mask_index) };
    } else {
        return null;
    }
}

pub fn find_best_match(window: []const u8, search_buff: []const u8) ?Match {
    if (window.len < vec_size + min_match_size) return null;

    var best_match_opt: ?Match = null;
    var target_len: usize = min_match_size;

    const first_byte_mask = vec_splat(search_buff[0]);

    var index: usize = (window.len - vec_size) - target_len;
    outer: while (true) {
        const last_byte_mask = vec_splat(search_buff[target_len-1]);

        const first_block: Vector(vec_size, u8) = window[index..][0..vec_size].*;
        const last_block:  Vector(vec_size, u8) = window[index+target_len-1..][0..vec_size].*;

        const first_eq = (first_byte_mask == first_block);
        const last_eq = (last_byte_mask == last_block);
        
        const mask = vec_AND(first_eq, last_eq);

        if (@reduce(.Add, mask) != 0) {
            var mask_index: usize = vec_size-1;
            while (true) {
                if (mask[mask_index] != 0) {
                    var match_opt = check_potential_match(window, search_buff, index, mask_index, target_len);
                    if (match_opt) |match| {
                        if (match.len == search_buff.len) {
                            return match;
                        }
                        if (best_match_opt == null or best_match_opt.?.len < match.len) {
                            best_match_opt = match;
                            target_len = best_match_opt.?.len + 1;
                            continue :outer;
                        }
                    }
                }
                if (mask_index > 0) {
                    mask_index -= 1;
                } else {
                    break;
                }
            }
        }
        if (index > vec_size) {
            index -= vec_size;
        } else if (index == 0) {
            break;
        } else {
            index = 0;
        }
    }
    return best_match_opt;
}

test "find best match" {
    {
        var best_match = find_best_match("It was the best of times, it was the blurst of times.", "blurst");
        try expect(best_match.?.len == 6 and best_match.?.distance == 16);
    }
    {
        var best_match = find_best_match("It is tea time, teatime, time for teas.", "teather");
        try expect(best_match.?.len == 4 and best_match.?.distance == 23);
    }
}

test "find best match prefers rightmost occurence" {
    {
        var best_match = find_best_match("Tea tea tea teatime tea teatime tea", "teatime");
        try expect(best_match.?.len == 7 and best_match.?.distance == 11);
    }
    {
        var best_match = find_best_match("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "AAAA");
        try expect(best_match.?.len == 4 and best_match.?.distance == 4);
    }
}

test "find best match at beginning" {
    var best_match = find_best_match("Hello, is there anybody in there?", "Hello?");
    try expect(best_match.?.len == 5 and best_match.?.distance == 33);
}

// Idealy this case would be handled like any other, however, it's not a priority.
test "find best match ignores small window buffer." {
    var best_match = find_best_match("Small buff", "Hello?");
    try expect(best_match == null);
}
