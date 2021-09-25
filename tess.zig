const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;


pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var merged = std.ArrayList(u8).init(allocator);
    try merged.insert(0, 0xff);
    try merged.insert(1, 0xff);
}
