const std = @import("std");
const aslib = @import("aslib");
const ctr = @import("ctr/ctr.zig");

pub const std_options: std.Options = .{
    .logFn = aslib.log.logFn,
};

const test_file = @embedFile("test.ctr");

pub fn main(args: std.process.Init) !u8 {
    try ctr.Lexer.dumpLexer(test_file[0..]);
    var module = try ctr.Module.init(args.gpa, 4096, 32768);
    defer module.deinit();

    try module.lex(test_file[0..]);
    try module.parse();
    if (module.ast_node_root) |root| {
        try ctr.ast.dump(&module.ast_node_array, module.source.?, root, 0);
    }
    module.report();
    std.debug.print("{d} {any}\n", .{ module.error_report_array.used, module.ast_node_root });

    var stdout_buf: [1024]u8 = undefined;
    const stdout = std.Io.File.stdout();
    var stdout_writer = stdout.writer(args.io, &stdout_buf);
    const writer = &stdout_writer.interface;
    try module.format(writer);
    try writer.flush();
    return 0;
}

test {
    _ = ctr;
}
