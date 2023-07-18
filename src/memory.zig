const std = @import("std");
const ArrayList = std.ArrayList;
const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

fn StringStore(comptime T: type) type {
    return struct {
        const Self = @This();

        buf: ArrayList(u8),
        len: usize = 0,

        fn initCapacity(allocator: Allocator, capacity: usize) !StringStore(T) {
            const buf = try ArrayList(u8).initCapacity(allocator, capacity);

            return .{ .buf = buf };
        }

        fn append(self: *Self, node: *const T, slice: []const u8) !void {
            { // serialize pointer to the node
                var buf = [_]u8{0} ** @sizeOf(usize);
                const _node = @intFromPtr(node);
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

        fn iterator(self: Self) Iterator {
            return .{
                .len = self.len,
                .items = self.buf.items,
            };
        }

        const Entry = struct {
            node: ?*T = null,
            text: []const u8,
        };

        const Iterator = struct {
            // index refers to the item's index not memory location. For example index=2 may start at loc=100
            index: usize = 0,
            len: usize,
            loc: usize = 0,

            items: []const u8,

            fn next(it: *Iterator) ?Entry {
                if (it.index >= it.len) return null;
                var buf = [_]u8{0} ** @sizeOf(usize);

                const node_ptr_offset = it.loc;
                const node_ptr_slice = it.items[node_ptr_offset .. node_ptr_offset + @sizeOf(usize)];
                @memcpy(&buf, node_ptr_slice);
                const node_ptr_int = std.mem.readIntNative(usize, &buf);

                const slice_len_offset = node_ptr_offset + @sizeOf(usize);
                const slice_len_slice = it.items[slice_len_offset .. slice_len_offset + @sizeOf(usize)];
                @memcpy(&buf, slice_len_slice);
                const slice_len = std.mem.readIntNative(usize, &buf);

                const slice_offset = slice_len_offset + @sizeOf(usize);
                const slice = it.items[slice_offset .. slice_offset + slice_len];

                it.loc = slice_offset + slice_len;
                it.index += 1;

                return .{
                    .text = slice,
                    .node = @as(*T, @ptrFromInt(node_ptr_int)),
                };
            }

            fn reset(it: *Iterator) void {
                it.index = 0;
                it.loc = 0;
            }
        };
    };
}

const testing = std.testing;
const expect = testing.expect;

test "multi_string_buffer" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const MyStruct = struct { a: u32 };

    var ms = try StringStore(MyStruct).initCapacity(a, 10);
    try expect(ms.len == 0);

    const v1 = blk: {
        var v1 = try a.create(MyStruct);
        v1.* = MyStruct{ .a = 23 };
        try ms.append(v1, "foo");
        try expect(ms.len == 1);
        break :blk v1;
    };
    const v2 = blk: {
        var v2 = try a.create(MyStruct);
        v2.* = MyStruct{ .a = 42 };
        try ms.append(v2, "bar");
        try expect(ms.len == 2);
        break :blk v2;
    };

    var it = ms.iterator();

    {
        const foo = it.next().?;
        try expect(std.mem.eql(u8, foo.text, "foo"));
        const node_ptr = foo.node;
        try expect(node_ptr == v1);
    }

    {
        it.reset();
        const foo = it.next().?;
        try expect(std.mem.eql(u8, foo.text, "foo"));
    }

    {
        const bar = it.next().?;
        try expect(std.mem.eql(u8, bar.text, "bar"));
        const node_ptr = bar.node;
        try expect(node_ptr == v2);
    }
}
