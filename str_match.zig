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

inline fn vec_splat(byte: u8) Vector(vec_size, u8) {
    return @splat(vec_size, @as(u8, byte));
}

inline fn vec_AND(vec_1: Vector(vec_size, bool), vec_2: Vector(vec_size, bool)) Vector(vec_size, u8) {
    const vec_1_int = @select(u8, vec_1, @splat(vec_size, @as(u8, 1)), @splat(vec_size, @as(u8, 0)));
    const vec_2_int = @select(u8, vec_2, @splat(vec_size, @as(u8, 1)), @splat(vec_size, @as(u8, 0)));
    return vec_1_int & vec_2_int;
}

inline fn quick_eql(a: []const u8, b: []const u8) bool {
    print("CHARS: ", .{});
    defer print("\n\n", .{});
    for (a) |item, index| {
        print("{c}", .{item});
        if (b[index] != item) {
            print("(BROKEN)", .{});
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

    // (No need to compare first and last bytes, they've been checked.)
    print(">>> {s}[{s}]{s}\n", .{ window[match_start-10..match_start], window[match_start..match_start+target_len], window[match_start+target_len..match_start+target_len+10] });
    print("TARGET: {}\n", .{target_len});
    //print("{}..{}\n", .{match_start+1, match_start+target_len-1});
    //print("{}..{}\n", .{1, target_len-1});
    //print(">>> {s}\n--> {s}\n\n", .{ window[match_start+1..match_start+target_len], search_buff[1..target_len] });

    if (quick_eql(window[match_start+1..match_start+target_len], search_buff[1..target_len])) {
        print("NEW CHARS:\n", .{});
        while (target_len < search_buff.len and window[match_start+target_len] == search_buff[target_len]) {
            print("{c} : {c}\n", .{window[match_start+target_len], search_buff[target_len]});
            target_len += 1;
        }
        print("\n", .{});
        return Match { .len = target_len, .distance = window.len - (index + mask_index) };
    } else {
        return null;
    }
}

fn find_best_match_vector(window: []const u8, search_buff: []const u8) ?Match {
    var best_match_opt: ?Match = null;
    var target_len: usize = 3;

    const first_byte_mask = vec_splat(search_buff[0]);

    var index: usize = (window.len - vec_size) - target_len;
    outer: while (true) {
        const last_byte_mask = vec_splat(search_buff[target_len-1]);

        const first_block: Vector(vec_size, u8) = window[index..][0..vec_size].*;
        const last_block:  Vector(vec_size, u8) = window[index+target_len-1..][0..vec_size].*;

        const eq_first = (first_byte_mask == first_block);
        const eq_last = (last_byte_mask == last_block);
        
        const mask = vec_AND(eq_first, eq_last);

        if (@reduce(.Add, mask) != 0) {
            var mask_index: usize = vec_size-1;
            while (true) {
                if (mask[mask_index] != 0) {
                    var match_opt = check_potential_match(window, search_buff, index, mask_index, target_len);
                    if (match_opt) |match| {
                        print("\nMATCH: <<<<<<<<<<<<<<<<<\n{c}\n{c}\n{}\n\n", .{first_block, last_block, match});
                        if (match.len == search_buff.len) {
                            return match;
                        }
                        if (best_match_opt == null or best_match_opt.?.len < match.len) {
                            best_match_opt = match;
                            target_len = best_match_opt.?.len + 1;
                            continue :outer;
                        }
                    } else {
                        print("\n{c}\n{c}\n\n", .{first_block, last_block});
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

fn find_best_match_linear(window: []const u8, search_buff: []const u8) ?Match {
    var index: usize = 0;
    while (true) {
        if (window[index] == search_buff[0]) {
            
        }
    }
}

pub fn find_best_match(window: []const u8, search_buff: []const u8) ?Match {
    if (search_buff.len < 3) return null;
    
    if (window.len < vec_size + 3) {
        return find_best_match_linear(window, search_buff);
    } else {
        return find_best_match_vector(window, search_buff);
    }
}


test "find best match" {
    {
        var best_match = find_best_match("It was the best of times, it was the blurst of times.", "blurst");
        try expect(best_match.?.len == 6 and best_match.?.distance == vec_size);
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

pub fn main() !void {
    const bible = @embedFile("bible.txt");

    const stdin = std.io.getStdIn().reader();
    var buf: [100]u8 = undefined;
    if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        const best_match = find_best_match(bible, user_input);
        print("\nBEST: {}", .{best_match});
        _ = best_match;
    }
}
