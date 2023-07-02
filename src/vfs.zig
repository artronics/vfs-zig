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
    children: ArrayList(FsNode),
    parent: ?*FsNode,
    kind: fs.File.Kind,

    fn init(allocator: Allocator, name: []const u8, kind: fs.File.Kind) !Self {
        var n = try allocator.alloc(u8, name.len);
        std.mem.copy(u8, n, name);

        const children = ArrayList(FsNode).init(allocator);

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
            log.warn("deinit {s}", .{child.name});
            child.deinit();
        }
        self.children.deinit();
    }

    fn addChild(self: *Self, node: *FsNode) !void {
        node.parent = self;
        try self.children.append(node.*);
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
    root: FsNode,

    pub fn init(allocator: Allocator, path: []const u8) !Self {
        var d = try fs.openDirAbsolute(path, .{ .access_sub_paths = true, .no_follow = true });
        defer d.close();
        const id = fs.IterableDir{ .dir = d };
        var walker = try id.walk(allocator);
        defer walker.deinit();

        // var stack = ArrayList(FsNode).init(allocator);
        // defer stack.deinit();
        var root = try FsNode.init(allocator, path, fs.File.Kind.Directory);
        // try walkDirs(allocator, &stack, &w, &root);
        try walkDirs2(allocator, &walker, &root);

        // while (try walker.next()) |dd| {
        // log.warn("path: {s}, kind: {}", .{ dd.path, dd.kind });
        // }

        return Self{
            .allocator = allocator,
            .root = root,
        };
    }

    pub fn deinit(self: Self) void {
        self.root.deinit();
    }
    fn walkDirs2(allocator: Allocator, walker: *fs.IterableDir.Walker, root: *FsNode) !void {
        var stack = ArrayList(*FsNode).init(allocator);
        defer stack.deinit();
        try stack.append(root);
        var top = stack.getLast();
        var visit_parent = true;

        while (try walker.next()) |next| {
            if (next.kind == fs.File.Kind.Directory) {
                var dir_node = try FsNode.init(allocator, next.basename, next.kind);
                try top.addChild(&dir_node);
                try stack.append(&dir_node);
                top = &dir_node;
                visit_parent = true;
            } else if (next.kind == fs.File.Kind.File) {
                if (visit_parent) {
                    _ = stack.pop();
                    visit_parent = false;
                }
                var file_node = try FsNode.init(allocator, next.basename, next.kind);
                try top.addChild(&file_node);
            } else {
                log.warn("file type \"{}\" not supported", .{next.kind});
            }
        }
    }

    fn walkDirs(allocator: Allocator, stack: *ArrayList(FsNode), walker: *fs.IterableDir.Walker, node: *FsNode) !void {
        // _ = stack;
        if (try walker.next()) |next| {
            var next_node = try FsNode.init(allocator, next.basename, next.kind);
            if (node.kind == fs.File.Kind.Directory) {
                try node.addChild(&next_node);
                // try stack.append(node);
                try walkDirs(allocator, stack, walker, &next_node);
            } else {
                try node.addChild(&next_node);
                // var top = stack.pop();
                while (try walker.next()) |leaf| {
                    var leaf_node = try FsNode.init(allocator, leaf.basename, leaf.kind);
                    if (leaf_node.kind == fs.File.Kind.Directory) {
                        try walkDirs(allocator, stack, walker, &leaf_node);
                        break;
                    } else {
                        try node.addChild(&leaf_node);
                    }
                }
            }
        }
    }
};

const expect = std.testing.expect;
const a = std.testing.allocator;

test "Fs" {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const d = try std.os.getcwd(&buf);

    var vfs = try Filesystem.init(a, d);
    defer vfs.deinit();
    log.warn("path: {s}", .{vfs.root.name});

    // var r = try FsNode.init(a, "root", fs.File.Kind.Directory);
    // defer r.deinit();
    // var r = vfs.root;

    var c1 = try FsNode.init(a, "c1", fs.File.Kind.File);
    var c2 = try FsNode.init(a, "c2", fs.File.Kind.Directory);
    var d1 = try FsNode.init(a, "d1", fs.File.Kind.File);
    try c2.addChild(&d1);
    try vfs.root.addChild(&c1);
    try vfs.root.addChild(&c2);

    var sb = try StringBuilder.init(4096, a);
    defer sb.deinit();
    try sb.append("\n", .{});
    try vfs.root.print(&sb);

    log.warn("{s}", .{sb.string()});

    // try expect(r.name[1] == 'i');
}
