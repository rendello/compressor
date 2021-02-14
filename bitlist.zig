const std = @import("std");

pub const BitList = struct {
    bytes: std.ArrayList(u8) = undefined,
    bit_index: u32 = 0,

    pub fn init(allocator: *std.mem.Allocator) !BitList {
        return BitList {.bytes = std.ArrayList(u8).init(allocator)};
    }
    pub fn append_bit(self: *BitList, bit: u1) !void {
        if (self.bytes.items.len*8 < self.bit_index+1) {
            try self.bytes.append(0);
        }
        
        if (bit == 1) {
            var byte_index: u32 = self.bit_index/8;
            self.bytes.items[byte_index] |= @as(u8, 128) >> @intCast(u3, self.bit_index-(byte_index*8));
        }
        self.bit_index += 1;
    }
};

pub fn main() !void {
}
