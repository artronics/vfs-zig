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
            { // serialize pointer to the node
                var buf = [_]u8{0} ** @sizeOf(usize);
                const _node = @ptrToInt(node);
                std.mem.writeIntNative(usize, &buf, _node);
                try self.buf.appendSlice(&buf);
            }
            { // serialize length of the slice
                var buf = [_]u8{0} ** @sizeOf(usize);
                std.mem.writeIntNative(usize, &buf, slice.len);
                try self.buf.appendSlice(&buf);
            }

            try self.buf.appendSlice(slice);

            self.len += 1;
        }

        fn next(self: *Self) Entry {
            const node_ptr_offset = 0;
            const node_ptr = std.mem.readIntNative(usize, self.buf.items[node_ptr_offset..node_ptr_offset + @sizeOf(usize)]);

            const slice_len_offset = node_ptr_offset + @sizeOf(usize);
            const slice_len = std.mem.readIntNative(usize, self.buf.items[slice_len_offset..slice_len_offset + @sizeOf(usize)]);

            const slice_offset = node_ptr_offset + slice_len_offset + @sizeOf(usize);
            const slice = self.buf.items[slice_offset..slice_offset + slice_len];

            return .{
                .text = slice,
                .node = @intToPtr(*T, node_ptr),
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
    const node_ptr = next.node;
    try expect(node_ptr == v1);
}
