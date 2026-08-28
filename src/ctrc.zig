const std = @import("std");
const logFn = @import("ctr/lib/log.zig").logFn;
const ctr = @import("ctr/ctr.zig");

pub const std_options: std.Options = .{
    .logFn = logFn,
};

const test_file = @embedFile("test.ctr");

const MainCommand = enum {
    fmt,
    help,
};

pub fn main(init: std.process.Init) !u8 {
    // try ctr.Lexer.dumpLexer(test_file[0..]);
    // var module = try ctr.Module.init(args.gpa, 4096, 32768);
    // defer module.deinit();

    // try module.lex(test_file[0..]);
    // try module.parse();
    // if (module.ast_node_root) |root| {
    //     try ctr.ast.dump(&module.ast_node_array, module.source.?, root, 0);
    // }
    // module.report();
    // std.debug.print("{d} {any}\n", .{ module.error_report_array.used, module.ast_node_root });

    // var stdout_buf: [1024]u8 = undefined;
    // const stdout = std.Io.File.stdout();
    // var stdout_writer = stdout.writer(args.io, &stdout_buf);
    // const writer = &stdout_writer.interface;
    // try module.format(writer);
    // try writer.flush();
    // try module.simplify();
    // try module.format(writer);
    // try writer.flush();
    // module.report();
    // return 0;

    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();

    const program_name = args.next();
    var main_command: ?MainCommand = null;

    while (args.next()) |arg| {
        if (main_command == null) {
            if (std.mem.eql(u8, arg, "fmt")) {
                main_command = MainCommand.fmt;
            } else if (std.mem.eql(u8, arg, "help")) {
                main_command = MainCommand.help;
            } else {
                std.debug.print("Unrecognized command '{s}', please try '{s} help' for help", .{ arg, program_name orelse "ctrc" });
                return 255;
            }
        } else {
            switch (main_command.?) {
                .fmt => {
                    var module = try ctr.Module.init(init.gpa, 1024, 32768);
                    defer module.deinit();

                    const source_file = std.Io.Dir.cwd().openFile(init.io, arg, .{ .mode = .read_write }) catch |err| {
                        std.debug.print("Error {s} occurred while opening file {s}", .{ @errorName(err), arg });
                        continue;
                    };
                    defer source_file.close(init.io);
                    const source_length = try source_file.length(init.io);
                    const source = try init.gpa.alloc(u8, source_length + 1);
                    defer init.gpa.free(source);

                    _ = try source_file.readPositionalAll(init.io, source, 0);
                    source[source_length] = 0;

                    module.lex(source[0..source_length :0]) catch |err| {
                        std.debug.print("Error {s} occurred while lexing file {s}", .{ @errorName(err), arg });
                        continue;
                    };
                    module.parse() catch |err| {
                        std.debug.print("Error {s} occurred while parsing file {s}", .{ @errorName(err), arg });
                        continue;
                    };
                    module.report(arg);
                    var source_writer = source_file.writer(init.io, &.{});
                    module.format(&source_writer.interface) catch |err| {
                        std.debug.print("Error {s} occurred while writing formatted file {s}", .{ @errorName(err), arg });
                        continue;
                    };
                    std.debug.print("{s}", .{arg});
                },
                .help => {},
            }
        }
    }

    return 0;
}

test {
    _ = ctr;
}
