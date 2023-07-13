const std = @import("std");
const ArrayList = std.ArrayList;
const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

fn StringStore(comptime T: type) type {
    return struct {
        const Self = @This();

        buf: ArrayList(u8),
        len: usize = 0,

        const Entry = struct {
            node: ?*T = null,
            text: []const u8,
        };

        fn initCapacity(allocator: Allocator, capacity: usize) !StringStore(T) {
            const buf = try ArrayList(u8).initCapacity(allocator, capacity);

            return .{ .buf = buf };
        }

        fn append(self: *Self, node: *const T, slice: []const u8) !void {
            const node_ptr = std.mem.asBytes(node);
            try self.buf.appendSlice(node_ptr);
            try self.buf.appendSlice(slice);

            self.len += 1;
        }

        fn next(self: *Self) Entry {
            // const node = @ptrCast(*T, self.buf.items[0..@sizeOf(usize)]);
            // _ = node;
            // const text = self.buf.items[@sizeOf(u32)..];
            const text = self.buf.items[@sizeOf(*T)..];
            return .{
                .text = text,
                // .node = node,
            };
        }
    };
}

const testing = std.testing;
const expect = testing.expect;

test "multi_string_buffer" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const MyStruct = struct { foo: u32 };
    var v1 = try a.create(MyStruct);
    v1.* = MyStruct{ .foo = 23 };

    var ms = try StringStore(MyStruct).initCapacity(a, 10);

    try expect(ms.len == 0);

    try ms.append(v1, "foo");
    try expect(ms.len == 1);

    const next = ms.next();
    try expect(std.mem.eql(u8, next.text, "foo"));
    // const node_ptr = next.node;
    // try expect(node_ptr == &v1);
}
