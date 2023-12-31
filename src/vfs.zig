const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringBuilder = @import("string_builder.zig").StringBuilder;
const fs = std.fs;
const log = std.log;

pub const Filesystem = struct {
    const Self = @This();

    arena: ArenaAllocator,
    root: *FsNode,

    const FsNode = struct {
        path: []const u8,
        children: ArrayList(*FsNode),
        parent: ?*FsNode,
        kind: fs.File.Kind,
        total: u32 = 1,

        fn init(allocator: Allocator, path: []const u8, kind: fs.File.Kind) !FsNode {
            const children = ArrayList(*FsNode).init(allocator);

            return FsNode{
                .path = path,
                .children = children,
                .parent = null,
                .kind = kind,
            };
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
            if (self.kind == fs.File.Kind.directory) {
                try sb.append("/{s}", .{fs.path.basename(self.path)});
            } else {
                try sb.append("{s}", .{fs.path.basename(self.path)});
            }
            try sb.append("\n", .{});

            for (self.children.items) |child| {
                try child.print(sb);
            }
        }
    };

    pub fn init(allocator: Allocator, path: []const u8) !Self {
        var arena = ArenaAllocator.init(allocator);
        const arenaAllocator = arena.allocator();

        var d = try fs.openDirAbsolute(path, .{ .access_sub_paths = true, .no_follow = true });
        defer d.close();
        const id = fs.IterableDir{ .dir = d };
        var walker = try id.walk(arenaAllocator);
        defer walker.deinit();

        const root_path = try std.fmt.allocPrint(arenaAllocator, "{s}", .{std.fs.path.basename(path)});
        var root = try arenaAllocator.create(FsNode);
        root.* = try FsNode.init(arenaAllocator, root_path, fs.File.Kind.directory);
        try walkDirs(&arena, &walker, root);

        return Self{
            .arena = arena,
            .root = root,
        };
    }

    pub fn deinit(self: Self) void {
        self.arena.deinit();
    }

    fn walkDirs(arena: *ArenaAllocator, walker: *fs.IterableDir.Walker, root: *FsNode) !void {
        const arenaAllocator = arena.allocator();
        var stack = ArrayList(*FsNode).init(arenaAllocator);
        defer stack.deinit();

        try stack.append(root);

        while (try walker.next()) |next| {
            var node = try arenaAllocator.create(FsNode);
            const path = try std.fmt.allocPrint(arenaAllocator, "{s}", .{next.path});
            node.* = try FsNode.init(arenaAllocator, path, next.kind);

            const node_parent = fs.path.dirname(node.path) orelse root.path;

            var top = stack.pop();
            while (!std.mem.eql(u8, top.path, node_parent)) {
                top = stack.pop();
            }
            try stack.append(top);
            try stack.append(node);
            try top.addChild(node);

            // TODO: Below is an unrolled version of above when same level child are added. Does it perform better?
            //       In most real world scenarios the number of files at the same level will be bigger than the number of directories
            //
            // var top = stack.getLast();
            // if (std.mem.eql(u8, top.path, node_parent)) {
            //     try top.addChild(node);
            //     try stack.append(node);
            // } else {
            //     top = stack.pop();
            //     while (!std.mem.eql(u8, top.path, node_parent)) {
            //         top = stack.pop();
            //     }
            //     try stack.append(top);
            //     try stack.append(node);
            //     try top.addChild(node);
            // }
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
    log.warn("path: {s}", .{vfs.root.path});

    var sb = try StringBuilder.init(4096, a);
    defer sb.deinit();
    try sb.append("\n", .{});
    try vfs.root.print(&sb);

    log.warn("{s}", .{sb.string()});

    try assertFs(vfs.root);
}

/// create a simple nested directory structure for testing
/// /root
///   /empty
///   /a
///     /b
///       c.txt
///   b.txt
///   /c
///     c1.txt
///     c2.txt
///   /same
///     /same
///       /same
///
fn makeTestData(dir: testing.TmpDir) !void {
    try dir.dir.makePath("root/empty");
    try dir.dir.makePath("root/a/b");
    try dir.dir.makePath("root/c");
    try dir.dir.makePath("root/same/same/same");
    _ = try dir.dir.createFile("root/b.txt", .{});
    _ = try dir.dir.createFile("root/c/c1.txt", .{});
    _ = try dir.dir.createFile("root/c/c2.txt", .{});
    _ = try dir.dir.createFile("root/a/b/c.txt", .{});
}

fn assertFs(root: *Filesystem.FsNode) !void {
    try expect(root.children.items.len == 5);
}
