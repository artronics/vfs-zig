const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringBuilder = @import("string_builder.zig").StringBuilder;
const fs = std.fs;
const log = std.log;

pub const FsNode = struct {
    const Self = @This();

    allocator: Allocator,
    name: []const u8,
    children: ArrayList(*FsNode),
    parent: ?*FsNode,
    kind: fs.File.Kind,

    fn init(allocator: Allocator, name: []const u8, kind: fs.File.Kind) !Self {
        // var n = try allocator.alloc(u8, name.len);
        // @memcpy(n, name);
        const n = try std.fmt.allocPrint(allocator, "{s}", .{name});

        const children = ArrayList(*FsNode).init(allocator);

        return Self{
            .allocator = allocator,
            .name = n,
            .children = children,
            .parent = null,
            .kind = kind,
        };
    }

    fn deinit(self: Self) void {
        self.allocator.free(self.name);
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit();
    }

    fn addChild(self: *Self, node: *FsNode) !void {
        node.parent = self;
        try self.children.append(node);
    }

    fn print(self: Self, sb: *StringBuilder) !void {
        var parent = self.parent;
        var indent: u8 = 0;
        while (parent != null) : (parent = parent.?.parent) {
            indent += 1;
        }

        for (0..indent) |_| {
            try sb.append("  ", .{});
        }
        if (self.kind == fs.File.Kind.Directory) {
            try sb.append("+ {s}", .{self.name});
        } else {
            try sb.append("| {s}", .{self.name});
        }
        try sb.append("\n", .{});

        for (self.children.items) |child| {
            try child.print(sb);
        }
    }
};

pub const Filesystem = struct {
    const Self = @This();

    allocator: Allocator,
    root: *FsNode,

    pub fn init(allocator: Allocator, path: []const u8) !Self {
        var d = try fs.openDirAbsolute(path, .{ .access_sub_paths = true, .no_follow = true });
        defer d.close();
        const id = fs.IterableDir{ .dir = d };
        var walker = try id.walk(allocator);
        defer walker.deinit();

        var root = try allocator.create(FsNode);
        root.* = try FsNode.init(allocator, path, fs.File.Kind.Directory);
        try walkDirs(allocator, &walker, root);

        return Self{
            .allocator = allocator,
            .root = root,
        };
    }

    pub fn deinit(self: Self) void {
        self.root.deinit();
        self.allocator.destroy(self.root);
    }
    fn walkDirs(allocator: Allocator, walker: *fs.IterableDir.Walker, root: *FsNode) !void {
        var stack = ArrayList(*FsNode).init(allocator);
        defer stack.deinit();
        // const root_name = fs.path.basename(root.name);
        try stack.append(root);

        var prev = root;
        while (try walker.next()) |next| {
            const parent_name = fs.path.basename(fs.path.dirname(next.path) orelse root.name);
            const basename = next.basename;
            var node = try allocator.create(FsNode);
            node.* = try FsNode.init(allocator, basename, next.kind);
            const top = stack.getLast();

            if (std.mem.eql(u8, fs.path.basename(top.name), parent_name)) {
                try top.addChild(node);
            } else {
                var parent_index: usize = 0;
                for (stack.items, 0..) |item, i| {
                    if (std.mem.eql(u8, item.name, parent_name)) {
                        parent_index = i;
                        break;
                    }
                }

                if (parent_index == 0) {
                    try stack.append(prev);
                    try prev.addChild(node);
                } else {
                    for (0..stack.items.len - parent_index - 1) |_| {
                        _ = stack.pop();
                    }
                    try stack.getLast().addChild(node);
                }
            }

            prev = node;
        }
    }
};

const expect = std.testing.expect;
const a = std.testing.allocator;

test "Fs" {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var d = try std.os.getcwd(&buf);
    d = try std.fmt.allocPrint(a, "{s}/test_data", .{d});
    defer a.free(d);

    var vfs = try Filesystem.init(a, d);
    defer vfs.deinit();
    log.warn("path: {s}", .{vfs.root.name});


    var sb = try StringBuilder.init(4096, a);
    defer sb.deinit();
    try sb.append("\n", .{});
    try vfs.root.print(&sb);

    log.warn("{s}", .{sb.string()});
}
