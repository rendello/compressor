const std = @import("std");
const mem =td.mem;
const testing = std.testing;
const process = std.process;
const fs = std.fs;
const print = std.debug.print;
const ChildProcess = std.ChildProcess;


pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var arg_it = process.args();

    _ = arg_it.skip();

    if (arg_it.next(allocator)) |input_file| {

    }
    if (arg_it.next(allocator)) |output_file| {

    }
}


pub fn readFileByLine(allocator: *std.mem.Allocator, filename: []const u8) !void {

    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const reader = file.reader();
    var line_buffer = try std.ArrayList(u8).initCapacity(allocator, 300);
    defer line_buffer.deinit();

    while (true) {
        reader.readUntilDelimiterArrayList(&line_buffer, '\n', std.math.maxInt(usize)) catch |err| switch (err) {
            error.EndOfStream => { break; },
            else => |e| return e,
        };
        var line = line_buffer.items;

        // here's how to trim the line if you want
        line.len = std.mem.trimRight(u8, line, "\n\r").len;

        std.log.debug("TODO: add code to handle line '{s}'", .{line});

        try line_buffer.resize(0);
    }
}
