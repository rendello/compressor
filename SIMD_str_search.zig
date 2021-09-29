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

pub fn search(haystack: []const u8, needle: []const u8) void {
    const f = @splat(vec_size, @as(u8, needle[0]));
    const l = @splat(vec_size, @as(u8, needle[needle.len-1]));

    if (haystack.len > vec_size) {
        var i: usize = 0;
        while (i + vec_size + needle.len < haystack.len) : (i += vec_size) {
            const a: Vector(vec_size, u8) = haystack[i..][0..vec_size].*;
            const b: Vector(vec_size, u8) = haystack[i+needle.len-1..][0..vec_size].*;

            const af = vector_bool_to_int(u8, vec_size, (a == f));
            const bl = vector_bool_to_int(u8, vec_size, (b == l));

            var afbl = af&bl;
            if (@reduce(.Add, afbl) != 0) {
                var j: usize = 0;
                while (j < vec_size) : (j += 1) {
                    if (afbl[j] != 0) {
                        var r = std.mem.eql(u8, haystack[i+j+1..i+j+needle.len-1], needle[1..needle.len-1]);
                        print("{}", .{r});
                    }
                }
            }
        }
    }
}


pub fn main() !void {
    search("A cAt clpt cat cet pink and purple cat cot cat! prances about the yard.", "cat");
}


