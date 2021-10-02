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


inline fn vector_bool_to_int(comptime T: type, comptime size: usize, vector: Vector(size, bool)) Vector(size, T) {
    return @select(u8, vector, @splat(vec_size, @as(u8, 1)), @splat(vec_size, @as(u8, 0)));
}

inline fn vec_splat(byte: u8) Vector(16, u8) {
    return @splat(16, @as(u8, byte));
}

inline fn vec_AND(vec_1: Vector(16, bool), vec_2: Vector(16, bool)) Vector(16, u8) {
    const vec_1_int = @select(u8, vec_1, @splat(16, @as(u8, 1)), @splat(16, @as(u8, 0)));
    const vec_2_int = @select(u8, vec_2, @splat(16, @as(u8, 1)), @splat(16, @as(u8, 0)));
    return vec_1_int & vec_2_int;
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

    // (No need to compare first and last bytes, they've been checked.)
    if (std.mem.eql(u8, window[match_start+1..match_start+target_len-1], search_buff[1..target_len-1])) {
        target_len += 1;
        while (target_len < search_buff.len and window[match_start+target_len] == search_buff[target_len]) {
            target_len += 1;
        }
        return Match { .len = target_len, .distance = window.len - (index + mask_index) };
    } else {
        return null;
    }
}


fn find_best_match(window: []const u8, search_buff: []const u8) ?Match {
    var best_match_opt: ?Match = null;
    var target_len: usize = 3;

    const first_byte_mask = vec_splat(search_buff[0]);
    var last_byte_mask = vec_splat(search_buff[target_len]);

    var index: usize = (window.len - 16) - target_len;
    while (true) {
        const first_block: Vector(16, u8) = window[index..][0..16].*;
        const last_block:  Vector(16, u8) = window[index+target_len..][0..16].*;

        const eq_first = (first_byte_mask == first_block);
        const eq_last = (last_byte_mask == last_block);
        
        const mask = vec_AND(eq_first, eq_last);

        if (@reduce(.Add, mask) != 0) {
            var mask_index: usize = 16-1;
            while (mask_index > 0) : (mask_index -= 1) {
                if (mask[mask_index] != 0) {
                    var match_opt = check_potential_match(window, search_buff, index, mask_index, target_len);
                    if (match_opt) |match| {
                        if (match.len == search_buff.len) {
                            return match;
                        } else if (best_match_opt) |best_match| {
                            if (match.len > best_match.len) {
                                best_match_opt = match;
                            }
                        } else {
                            best_match_opt = match;
                        }
                    }
                }
            }
        }
        if (index > 16) {
            index -= 16;
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

test "find best match prefers last occurence" {
    {
        var best_match = find_best_match("Tea tea tea teatime tea teatime tea", "teatime");
        try expect(best_match.?.len == 7 and best_match.?.distance == 11);
    }
    {
        var best_match = find_best_match("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "AAAA");
        try expect(best_match.?.len == 4 and best_match.?.distance == 4);
    }
}

pub fn main() !void {
    //var best_match = find_best_match("It was the best of times, it was the blurst of times.", "blurst");
    //print("{}", .{best_match});
    var best_match = find_best_match(@embedFile("bible.txt"), "Jesus");
    print("{}", .{best_match});
}




