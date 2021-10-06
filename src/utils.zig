// Gaven Rendell, 2021.

const std = @import("std");

pub fn get_SIMD_vector_size_in_bytes() u32 {
    comptime for (std.Target.current.cpu.arch.allFeaturesList()) |feature| {
        if (std.mem.eql(u8, feature.name, "prefer_128_bit")) {
            return 128/8;
        } else if (std.mem.eql(u8, feature.name, "prefer_256_bit")) {
            return 256/8;
        }
    } else { 
        return 64/8;
    };
}
