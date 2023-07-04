const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringBuilder = @import("string_builder.zig").StringBuilder;
const fs = std.fs;
const log = std.log;

pub const Filesystem = struct {
    const Self = @This();

    allocator: Allocator,
    root: *FsNode,

    const FsNode = struct {
        allocator: Allocator,
        name: []const u8,
        children: ArrayList(*FsNode),
        parent: ?*FsNode,
        kind: fs.File.Kind,

        fn init(allocator: Allocator, name: []const u8, kind: fs.File.Kind) !FsNode {
            const _name = try std.fmt.allocPrint(allocator, "{s}", .{name});

            const children = ArrayList(*FsNode).init(allocator);

            return FsNode{
                .allocator = allocator,
                .name = _name,
                .children = children,
                .parent = null,
                .kind = kind,
            };
        }

        fn deinit(self: FsNode) void {
            self.allocator.free(self.name);
            for (self.children.items) |child| {
                child.deinit();
                self.allocator.destroy(child);
            }
            self.children.deinit();
        }

        fn addChild(self: *FsNode, node: *FsNode) !void {
            node.parent = self;
            try self.children.append(node);
        }

        fn print(self: FsNode, sb: *StringBuilder) !void {
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

const testing = std.testing;
const expect = testing.expect;

test "Fs" {
    const a = testing.allocator;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    try makeTestData(tmp_dir);

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var d = try tmp_dir.dir.realpath("root", &buf);

    var vfs = try Filesystem.init(a, d);
    defer vfs.deinit();
    log.warn("path: {s}", .{vfs.root.name});

    var sb = try StringBuilder.init(4096, a);
    defer sb.deinit();
    try sb.append("\n", .{});
    try vfs.root.print(&sb);

    log.warn("{s}", .{sb.string()});
}

/// create a simple nested directory structure for testing
/// + root
///   + a2
///     + a2b0
///       | a2b0c0.txt
///   | a0.txt
///   + a1
///     | a1b1.txt
///     | a1b0.txt
///
fn makeTestData(dir: testing.TmpDir) !void {
    try dir.dir.makePath("root/a1");
    try dir.dir.makePath("root/a2/a2b0");
    _ = try dir.dir.createFile("root/a0.txt", .{});
    _ = try dir.dir.createFile("root/a1/a1b0.txt", .{});
    _ = try dir.dir.createFile("root/a1/a1b1.txt", .{});
    _ = try dir.dir.createFile("root/a2/a2b0/a2b0c0.txt", .{});
}
