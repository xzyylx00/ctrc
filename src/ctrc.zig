const std = @import("std");
const aslib = @import("aslib");

const Lexer = @import("ctr/lexer.zig");

pub const std_options: std.Options = .{
    .logFn = aslib.log.logFn,
};

pub fn main() !u8 {
    try Lexer.dumpLexer(
        \\test {};
        \\ability {};
    );
    return 0;
}

test {
    _ = aslib;
    _ = Lexer;
}
