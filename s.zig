const std = @import("std");
const Vector = std.meta.Vector;

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

fn find_best_match(window: []const u8, str: []const u8) ?Match {
    var best_match: ?Match = null;
    var target_len: usize = 3;

    const first_byte_mask = vec_splat(str[0]);
    var last_byte_mask = vec_splat(str[target_len-1]);

    var index: usize = window.len;
    while (index > 0) {
        const first_block: Vector(16, u8) = window[index..][0..16].*;
        const last_block:  Vector(16, u8) = window[index+target_len..][0..16].*;

        const eq_first = (first_byte_mask == first_block);
        const eq_last = (last_byte_mask == last_block);
        
        const mask = vec_AND(eq_first, eq_last);

        if (@reduce(.Add, mask) != 0) {
            const mask_as_array: [16]u8 = mask;
            for (mask_as_array) |value, sub_index| {
                if (value != 0) {
                    if (std.mem.eql(u8, window[index+sub_index+1..index+sub_index+target_len-1], str[1..target_len-1])) {
                        best_match = Match { .len = target_len, .distance = window.len - index + sub_index };
                        target_len += 1;
                        last_byte_mask = vec_splat(str[target_len-1]);
                    }
                }
            }
        }
    }
    return best_match;
}

pub fn main() !void {
    var best_match = find_best_match("A cAt purpl clpt   cet pink  purplecat and purple cat purplcot cat! prances pu about the yard...........", "purplecat");
    std.debug.print("{}", .{best_match});
}
