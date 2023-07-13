const std = @import("std");

const MatchResult = struct {
    index: isize = -1,
};

fn match(pattern: []const u8, text: []const u8) MatchResult {
    _ = pattern;
    _ = text;
    return MatchResult{};
}

const testing = std.testing;
const expect = testing.expect;

test "matcher" {
    const p1 = "ababc";
    const texts = [_][]const u8{p1};

    const pattern = "ababc";

    var results: [texts.len]MatchResult = undefined;

    for (texts, 0..) |text, i| {
        results[i] = match(pattern, text);
    }

    try expect(results[0].index == -1);
}
