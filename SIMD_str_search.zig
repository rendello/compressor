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


pub fn find_best_match(window: []const u8, search_buff: []const u8) ?Match {
    var best_match = Match { .len = 3, .distance = null };

    const f = @splat(vec_size, @as(u8, search_buff[0]));
    var l = @splat(vec_size, @as(u8, search_buff[best_match.len-1]));

    var index: usize = 0;
    if (window.len > vec_size) {
        while (index + vec_size + best_match.len < window.len) : (index += vec_size) {
            const a: Vector(vec_size, u8) = window[index..][0..vec_size].*;
            const b: Vector(vec_size, u8) = window[index+best_match.len-1..][0..vec_size].*;

            const af = vector_bool_to_int(u8, vec_size, (a == f));
            const bl = vector_bool_to_int(u8, vec_size, (b == l));

            var afbl = af&bl;
            if (@reduce(.Add, afbl) != 0) {
                var j: usize = 0;
                while (j < vec_size) : (j += 1) {
                    if (afbl[j] != 0 and std.mem.eql(u8, window[index+j+1..index+j+best_match.len-1], search_buff[1..best_match.len-1])) {
                        print("Yes: {}\n", .{index+j});

                        best_match.len = search_buff.len;
                        best_match.distance = @intCast(u16, window.len) - @intCast(u16, index+j);
                        l = @splat(vec_size, @as(u8, search_buff[best_match.len-1]));
                    }
                }
            }
        }
    }
    return if (best_match.distance != null) best_match else null;
}


pub fn main() !void {
    var best_match = find_best_match("A cAt pur clpt purplecat cet pink and purple cat purplcot cat! prances about the yard.", "purplecat");
    print("{}", .{best_match});
}


