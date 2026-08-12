const std = @import("std");
const aslib = @import("aslib");

const Lexer = @import("ctr/lexer.zig");
const Parser = @import("ctr/parser.zig");
const Module = @import("ctr/module.zig");

pub const std_options: std.Options = .{
    .logFn = aslib.log.logFn,
};

const test_file = @embedFile("test.ctr");

pub fn main(args: std.process.Init) !u8 {
    try Lexer.dumpLexer(test_file[0..]);
    var module = try Module.init(args.gpa, 4096, 32768);
    defer module.deinit();

    try module.lex(test_file[0..]);
    try module.parse();
    if (module.ast_node_root) |root| {
        try Parser.dump(&module.ast_node_array, module.source.?, root, 0);
    }
    module.report();
    std.debug.print("{d} {any}\n", .{ module.error_report_array.used, module.ast_node_root });
    return 0;
}

test {
    _ = aslib;
    _ = Lexer;
}
