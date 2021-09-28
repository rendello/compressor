// Gaven Rendell, 2021.

//! Reference: "SIMD-friendly algorithms for substring searching" by Wojciech Muła

const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const expect = std.testing.expect;
const print = std.debug.print;
const Vector = std.meta.Vector;

const utils = @import("utils.zig");


const vec_size = utils.get_SIMD_vector_size_in_bytes();


fn search(haystack: []const u8, needle: []const u8) void {
    const f = @splat(vec_size, @as(u8, needle[0]));
    const l = @splat(vec_size, @as(u8, needle[needle.len-1]));

    if (haystack.len > vec_size) {
        var i: usize = 0;
        while (i + vec_size + needle.len < haystack.len) : (i += vec_size) {
            const a: Vector(vec_size, u8) = haystack[i..][0..vec_size].*;
            const b: Vector(vec_size, u8) = haystack[i+needle.len-1..][0..vec_size].*;

            const af = (a == f);
            const bl = (b == l);

            // Hack: used to convert the bools to ints for a SIMD `and` operation. No other way
            // to do this in Zig currently.
            const x = @select(u8, af, @splat(vec_size, @as(u8, 1)), @splat(vec_size, @as(u8, 0)));
            const y = @select(u8, bl, @splat(vec_size, @as(u8, 1)), @splat(vec_size, @as(u8, 0)));

            var res = x&y;
            if (@reduce(.Add, res) > 0) {

                var j: usize = 0;
                while (j < std.mem.len(res)) : (j += 1) {
                    if (res[j] > 0) {
                        print("{}", .{std.mem.eql(u8, haystack[i+j+1..i+j+needle.len-2], needle[1..needle.len-2])});
                    }
                }
            }

            print("{}:\n", .{i});
            print("{}\n===\n", .{af});
            print("{}\n===\n", .{bl});
            print("{}\n===\n", .{x});
            print("{}\n===\n", .{y});
            print("{}\n===\n\n", .{x&y});
        }
    }
}

pub fn main() !void {
    search("A pink and purple cat prances about the yard.", "cat");
}


