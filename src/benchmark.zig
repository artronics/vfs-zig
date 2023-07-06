const std = @import("std");
const log = std.log;
const Filesystem = @import("vfs.zig").Filesystem;
const testing = std.testing;
const time = std.time;

const Benchmark = struct {
    time: usize,

    fn writeResults(self: Benchmark) !void {
        const cwd = std.fs.cwd();
        const file = try cwd.createFile("benchmark_results/benchmark.csv", .{ .read = true });
        defer file.close();

        var buf: [1024 * 5]u8 = undefined;
        const written = try std.fmt.bufPrint(&buf, "time\n{d}", .{self.time});
        try file.writeAll(written);

        log.warn("\n{s}\n", .{written});
    }
};

fn vfsInitBench(path: []const u8) !u64 {
    const a = testing.allocator;
    var timer = try time.Timer.start();

    var vfs = try Filesystem.init(a, path);
    defer vfs.deinit();

    return timer.lap();
}

test "benchmark" {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const zig = try std.fs.cwd().realpath("benchmark_data/zig", &buf);
    const lap = try vfsInitBench(zig);

    const b = Benchmark{ .time = lap };
    try b.writeResults();
}
