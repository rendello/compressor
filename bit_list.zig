// Gaven Rendell, 2021.

// Todo: the order of the bits in the deflate format is different.

const std = @import("std");
const expect = std.testing.expect;

/// Appendable list of individual bits.
pub const BitList = struct {
    bytes: std.ArrayList(u8) = undefined,
    bit_index: u32 = 0,

    pub fn init(a: *std.mem.Allocator) !BitList {
        return BitList {.bytes = std.ArrayList(u8).init(a)};
    }

    pub fn deinit(self: *BitList) void {
        self.bytes.deinit();
    }

    /// Shift bits into list, left-to-right. Extend if needed.
    pub fn append_bit(self: *BitList, bit: u1) !void {
        if (self.bytes.items.len*8 < self.bit_index+1) {
            try self.bytes.append(0);
        }
        if (bit == 1) {
            self.bytes.items[self.bit_index/8] |= @as(u8, 128) >> @intCast(u3, self.bit_index%8);
        }
        self.bit_index += 1;
    }

    /// Append from a slice of bytes up to `max_bit_count` bits.
    pub fn append_bytes(self: *BitList, bytes: []u8, max_bit_count: u32) !void {
        std.debug.assert(max_bit_count<=bytes.len*8);

        for (bytes) |byte, byte_index| {
            var i: u8 = 0;
            while (i < 8) : (i += 1) {
                if ((byte_index)*8+i < max_bit_count) {
                    try self.append_bit(@intCast(u1, (byte >> @intCast(u3, 7 - i)) & 1));
                } else break;
            }
        }
    }

    /// Can be safely @intCast to u3.
    pub fn get_trailing_bit_count(self: *BitList) u32 {
        return 8-(self.bit_index%8);
    }
};

test "BitList initializes" {
    const allocator = std.heap.page_allocator;

    var bit_list = try BitList.init(allocator);
    defer bit_list.deinit();

    try expect(bit_list.bytes.items.len == 0);
}

test "BitList appends bits" {
    const allocator = std.heap.page_allocator;

    var bit_list = try BitList.init(allocator);
    defer bit_list.deinit();

    try bit_list.append_bit(1);
    try expect(bit_list.bytes.items.len == 1);

    try bit_list.append_bit(1);
    try bit_list.append_bit(1);
    try bit_list.append_bit(1);
    try bit_list.append_bit(0);
    try bit_list.append_bit(0);
    try bit_list.append_bit(0);
    try bit_list.append_bit(1);
    try expect(bit_list.bytes.items.len == 1);

    try bit_list.append_bit(1);
    try expect(bit_list.bytes.items.len == 2);

    try expect(bit_list.bytes.items[0] == 0b1111_0001);
    try expect(bit_list.bytes.items[1] == 0b1000_0000);
}

test "BitList appends byte slices with bit counts" {
    const allocator = std.heap.page_allocator;

    var bit_list = try BitList.init(allocator);
    defer bit_list.deinit();

    var array = [_]u8{0b1110_1110, 0b1101_1010, 0b1011_1100, 0b1001_0000};
    try bit_list.append_bytes(array[0..3], 19);

    try expect(bit_list.bytes.items.len == 3);
    try expect(bit_list.get_trailing_bit_count() == 5);
    try expect(bit_list.bytes.items[0] == 0b1110_1110);
    try expect(bit_list.bytes.items[1] == 0b1101_1010);
    try expect(bit_list.bytes.items[2] == 0b1010_0000);

    try bit_list.append_bytes(array[0..1], 6);

    try expect(bit_list.bytes.items.len == 4);
    try expect(bit_list.get_trailing_bit_count() == 7);
    try expect(bit_list.bytes.items[2] == 0b1011_1101);
    try expect(bit_list.bytes.items[3] == 0b1000_0000);
}
