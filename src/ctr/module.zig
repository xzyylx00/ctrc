// Ctrc
// Copyright (C) 2026 xzyylx00
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the Lesser GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// Lesser GNU General Public License for more details.
//
// You should have received a copy of the Lesser GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const aslib = @import("aslib");
const Lexer = @import("lexer.zig");
const Parser = @import("parser.zig");
const ErrorReportArray = @import("error.zig").ErrorReportArray;
const TokenArray = @import("token_array.zig").TokenArray;
const ASTNodeArray = @import("ast.zig").ASTNodeArray;
const Module = @This();

pub const Position = struct {
    line: usize,
    pos: usize,

    pub fn toPosition(token: ?Lexer.Token) Position {
        if (token) |_token| {
            return Position{
                .line = _token.line,
                .pos = _token.pos,
            };
        } else {
            return Position{
                .line = 0,
                .pos = 0,
            };
        }
    }
};

pub const Range = struct {
    start: usize,
    end: usize,

    pub fn toRange(token: ?Lexer.Token) Range {
        if (token) |_token| {
            return Range{
                .start = _token.start,
                .end = _token.end,
            };
        } else {
            return Range{
                .start = 0,
                .end = 0,
            };
        }
    }
};

const Comment = struct {
    line: usize,
    start: usize,
    end: usize,
};

source: ?[:0]const u8,
token_array: ?TokenArray,
comment: ?[]Comment,
error_report_array: ErrorReportArray,
ast_node_array: ASTNodeArray,
ast_node_root: ?usize,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, error_report_array_size: u32, ast_node_array_size: u32) error{OutOfMemory}!Module {
    var error_report_array = try ErrorReportArray.init(allocator, error_report_array_size);
    errdefer error_report_array.deinit(allocator);

    var ast_node_array = try ASTNodeArray.init(allocator, ast_node_array_size);
    errdefer ast_node_array.deinit(allocator);

    return Module{
        .allocator = allocator,
        .ast_node_array = ast_node_array,
        .error_report_array = error_report_array,
        .comment = null,
        .source = null,
        .token_array = null,
        .ast_node_root = null,
    };
}

pub fn deinit(module: *Module) void {
    module.ast_node_array.deinit(module.allocator);
    module.error_report_array.deinit(module.allocator);
    if (module.token_array) |*token_array| {
        module.allocator.free(token_array.tokens);
    }

    if (module.comment) |comment| {
        module.allocator.free(comment);
    }

    module.* = Module{
        .allocator = undefined,
        .ast_node_array = undefined,
        .error_report_array = undefined,
        .comment = null,
        .ast_node_root = null,
        .source = null,
        .token_array = null,
    };
}

pub fn lex(module: *Module, source: [:0]const u8) error{ OutOfMemory, OutOfCapacity }!void {
    module.source = source;
    var lexer = Lexer.init(source);

    var token_count: usize = 0;
    var comment_count: usize = 0;
    while (true) {
        const token = try lexer.next(&module.error_report_array);
        if (token.kind == .eof) {
            token_count += 1;
            break;
        } else if (token.kind == .comment) {
            comment_count += 1;
        } else {
            token_count += 1;
        }
    }
    const token_array = try module.allocator.alloc(Lexer.Token, token_count);
    errdefer module.allocator.free(token_array);
    const comment = try module.allocator.alloc(Comment, comment_count);
    errdefer module.allocator.free(comment);
    module.token_array = TokenArray{
        .tokens = token_array,
        ._current = null,
    };
    module.comment = comment;

    module.error_report_array.clear();

    lexer = Lexer.init(source);

    var token_index: usize = 0;
    var comment_index: usize = 0;
    while (true) {
        const token = try lexer.next(&module.error_report_array);
        if (token.kind != .comment) {
            token_array[token_index] = token;
            token_index += 1;
            if (token.kind == .eof) {
                break;
            }
        } else {
            comment[comment_index] = Comment{
                .line = token.line,
                .start = token.start,
                .end = token.end,
            };
            comment_index += 1;
        }
    }
}

pub fn parse(module: *Module) error{OutOfCapacity}!void {
    if (module.token_array) |*token_array| {
        module.ast_node_root = try Parser.parseRoot(&module.ast_node_array, token_array, &module.error_report_array);
        if (module.ast_node_root != null) {
            module.error_report_array.clear();
            // XXX Find better approach in future
        }
    }
}

pub fn report(module: *Module) void {
    if (module.source) |source| {
        module.error_report_array.report(source);
    }
}
