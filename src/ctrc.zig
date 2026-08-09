const std = @import("std");
const aslib = @import("aslib");

const Lexer = @import("ctr/lexer.zig");
const Parser = @import("ctr/parser.zig");

pub const std_options: std.Options = .{
    .logFn = aslib.log.logFn,
};

const test_file = @embedFile("test.ctr");

pub fn main(args: std.process.Init) !u8 {
    try Lexer.dumpLexer(test_file[0..]);
    var lexer = Lexer.init(test_file[0..]);
    var ast_node_array = try Parser.ASTNodeArray.init(args.gpa, 32768);
    defer ast_node_array.deinit();
    const root = try Parser.parseRoot(&ast_node_array, &lexer);
    std.debug.print("{any}\n", .{root});
    if (root) |_root| {
        try Parser.dump(&ast_node_array, test_file[0..], _root, 0);
    }

    return 0;
}

test {
    _ = aslib;
    _ = Lexer;
}
