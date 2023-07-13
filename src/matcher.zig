const std = @import("std");

const MatchResult = struct {
    index: isize = -1,
};

fn match(text: []const u8, pattern: []const u8) f64 {
    var i = text.len;
    var j = pattern.len;
    while (i > 0 or (i > 0 and j == 0)) : (i -= 1) {
        if (text[i - 1] == pattern[j - 1]) {
            j -= 1;
        }
    }

    return if (j == 0) 1.0 else 0.0;
}

const testing = std.testing;
const expect = testing.expect;

test "matcher" {
    const Scenario = struct {
        text: []const u8,
        pattern: []const u8,
        expected_score: f64,
    };
    const scenarios = [_]Scenario{
        Scenario{ .text = "", .pattern = "", .expected_score = 1.0 },
        Scenario{ .text = "ababc", .pattern = "ababc", .expected_score = 1.0 },
        Scenario{ .text = "axyb", .pattern = "ab", .expected_score = 1.0 },
        Scenario{ .text = "abxy", .pattern = "abc", .expected_score = 0.0 },
        Scenario{ .text = "ab", .pattern = "abc", .expected_score = 0.0 },
    };

    for (scenarios) |scenario| {
        const actual_score = match(scenario.text, scenario.pattern);
        try expect(actual_score == scenario.expected_score);
    }
}
