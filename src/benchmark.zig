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

fn vfsInitBench(path: []const u8, results: []u64) !void {
    const a = testing.allocator;
    var timer = try time.Timer.start();

    for (0..results.len) |i| {
        var vfs = try Filesystem.init(a, path);
        vfs.deinit();
        results[i] = timer.lap();
    }
}

test "benchmark" {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const zig = try std.fs.cwd().realpath("benchmark_data/zig", &buf);
    var results = [_]u64{0} ** 10;
    try vfsInitBench(zig, &results);

    var sum: u64 = 0;
    for (0..results.len) |i| {
        log.warn("[{d}]: {d}", .{i, results[i] / 1000_000});
        sum += results[i];
    }

    const b = Benchmark{ .time = (sum / results.len) / 1000_000 };
    try b.writeResults();
}
