const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const fs = std.fs;
const log = std.log;

pub const FsNode = struct {
    const Self = @This();

    allocator: Allocator,
    name: []const u8,
    children: ?ArrayList(FsNode),
    parent: ?*FsNode,

    fn init(allocator: Allocator, name: []const u8) !Self {
        var n = try allocator.alloc(u8, name.len);
        std.mem.copy(u8, n, name);

        return Self{
            .allocator = allocator,
            .name = n,
            .children = null,
            .parent = null,
        };
    }

    fn deinit(self: Self) void {
        self.allocator.free(self.name);
    }

    fn addChild(self: Self, node: FsNode) !void {
        if (self.children == null) {
            self.children = ArrayList(FsNode).init(self.allocator);
        }
        if (self.children) |ch| {
            try ch.append(node);
        }
    }
};

pub const Filesystem = struct {
    const Self = @This();

    allocator: Allocator,
    root: FsNode,

    pub fn init(allocator: Allocator, path: []const u8) !Self {
        const d = try fs.openDirAbsolute(path, .{ .access_sub_paths = true, .no_follow = true });
        const id = fs.IterableDir{ .dir = d };
        var w = try id.walk(allocator);
        defer w.deinit();

        const root = try FsNode.init(a, path);

        while (try w.next()) |dd| {
            log.warn("path: {s}, kind: {}", .{ dd.path, dd.kind });
        }

        return Self{
            .allocator = allocator,
            .root = root,
        };
    }

    pub fn deinit(self: Self) void {
        self.root.deinit();
    }
};

const expect = std.testing.expect;
const a = std.testing.allocator;

test "Fs" {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const d = try std.os.getcwd(&buf);

    const vfs = try Filesystem.init(a, d);
    defer vfs.deinit();
    log.warn("path: {s}", .{vfs.root.name});

    const r = try FsNode.init(a, "root");
    defer r.deinit();

    const c1 = try FsNode.init(a, "c1");
    defer c1.deinit();
    r.addChild(c1);

    try expect(r.name[1] == 'o');
}
