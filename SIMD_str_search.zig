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

const Match = struct {
    len: usize,
    distance: ?u16
};


/// Given a `window` of no larger than 32KiB (as per the DEFLATE spec), and
/// given a `search_buff` of no smaller than 3 bytes,
/// return the longest match's length and distance from the end of the window.
/// If two matches have the same distance, the one closer to the end wins.
/// If no match > 3 if found, none is returned.
pub fn find_best_match(window: []const u8, search_buff: []const u8) ?Match {
    var best_match: ?Match = null;

    var target_len: usize = 3;

    const f = @splat(vec_size, @as(u8, search_buff[0]));
    var l = @splat(vec_size, @as(u8, search_buff[target_len-1]));

    var index: usize = 0;
    while (index + vec_size + target_len < window.len) {
        const a: Vector(vec_size, u8) = window[index..][0..vec_size].*;
        const b: Vector(vec_size, u8) = window[index+target_len-1..][0..vec_size].*;

        const af = vector_bool_to_int(u8, vec_size, (a == f));
        const bl = vector_bool_to_int(u8, vec_size, (b == l));

        const afbl = af&bl;
        if (@reduce(.Add, afbl) != 0) {
            var j: usize = 0;
            while (j < vec_size) : (j += 1) {
                if (afbl[j] != 0 and std.mem.eql(u8, window[index+j+1..index+j+target_len-1], search_buff[1..target_len-1])) {
                    print("Yes: {} Target: {}\n", .{index+j, target_len});

                    best_match = Match { .len = target_len, .distance = @intCast(u16, window.len) - @intCast(u16, index+j) };
                    if (target_len < search_buff.len) {
                        target_len += 1;
                        l = @splat(vec_size, @as(u8, search_buff[target_len-1]));
                    } else {
                        return best_match;
                    }
                }
            }
        } else {
            index += vec_size;
        }
    }
    //while (window.len - index > best_match.len) : (index+=1) {
    //    if (window[index] == search_buff[0]) {
    //        if (std.mem.eql(u8, window[index..index+best_match.len-1], search_buff))

    //        }
    //    }
    //}
    return best_match;
}


pub fn main() !void {
    var best_match = find_best_match("A cAt purpl clpt   cet pink  purplect and purple cat purplcot cat! prances pu about the yard...........", "purplecat");
    print("{}", .{best_match});
}


