const std = @import("std");
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    const a = testing.allocator;
    const t = "hello";
    const tt = try a.alloc(u8, t.len);
    _ = tt;
    // defer a.free(tt);
    try testing.expect(add(3, 7) == 10);
}
