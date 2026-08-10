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
const Module = @This();

pub const ErrorReport = struct {
    position: Position,

    kind: ErrorReportKind,
    data: union {
        expected_token: ExpectedToken,
        unexpected_token: UnexpectedToken,
        invalid_character: InvalidCharacter,
    },

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

    const InvalidCharacter = struct {
        found: [:0]const u8,
    };

    const UnexpectedToken = struct {
        expected: [:0]const u8,
        found: Range,
    };

    const ExpectedToken = struct {
        expected: [:0]const u8,
    };

    const ErrorReportKind = enum {
        // Lexer
        invalid_character,

        // Parser
        unexpected_token,
        expected_token,
        expected_expression,
        expected_assignment_target,
    };

    pub fn report(error_report: ErrorReport, source: [:0]const u8) void {
        switch (error_report.kind) {
            .unexpected_token => {
                std.log.debug("Unexpected Token at {d}:{d}, expect {s}, found {s}", .{ error_report.position.line, error_report.position.pos, error_report.data.unexpected_token.expected, source[error_report.data.unexpected_token.found.start..error_report.data.unexpected_token.found.end] });
            },
            .expected_token => {
                std.log.debug("Expected Token at {d}:{d}, expect {s}", .{ error_report.position.line, error_report.position.pos, error_report.data.expected_token.expected });
            },
            .expected_expression => {},
            .expected_assignment_target => {},
            .invalid_character => {},
        }
    }
};

pub const ErrorReportArray = struct {
    error_reports: []ErrorReport,
    used: usize,

    pub fn init(allocator: std.mem.Allocator, size: usize) error{OutOfMemory}!ErrorReportArray {
        const error_reports = try allocator.alloc(ErrorReport, size);
        return ErrorReportArray{
            .error_reports = error_reports,
            .used = 0,
        };
    }

    pub fn deinit(error_report_array: *ErrorReportArray, allocator: std.mem.Allocator) void {
        allocator.free(error_report_array.error_reports);

        error_report_array.* = ErrorReportArray{
            .error_reports = undefined,
            .used = 0,
        };
    }

    pub fn clear(error_report_array: *ErrorReportArray) void {
        error_report_array.used = 0;
    }

    pub fn raw(error_report_array: *const ErrorReportArray) []ErrorReport {
        return error_report_array.error_reports[0..error_report_array.used];
    }

    pub fn addReport(error_report_array: *ErrorReportArray, error_report: ErrorReport) error{OutOfCapacity}!void {
        if (error_report_array.used == error_report_array.error_reports.len) {
            return error.OutOfCapacity;
        }

        error_report_array.error_reports[error_report_array.used] = error_report;
        error_report_array.used += 1;
    }
};

pub const TokenArray = struct {
    tokens: []Lexer.Token,
    _current: ?usize,

    pub fn peek(token_array: *const TokenArray) ?Lexer.Token {
        var _current: ?usize = token_array._current;
        if (_current == null) {
            _current = 0;
        }

        if (token_array.tokens[_current.?].kind == .eof or token_array.tokens[_current.?].kind == .invalid) {
            return null;
        } else {
            return token_array.tokens[_current.?];
        }
    }

    pub fn next(token_array: *TokenArray) Lexer.Token {
        if (token_array._current == null) {
            token_array._current = 0;
        }

        if (token_array.tokens[token_array._current.?].kind == .eof) {
            return token_array.tokens[token_array._current.?];
        } else if (token_array.tokens[token_array._current.?].kind == .invalid) {
            token_array._current = token_array._current.? + 1;
            return token_array.tokens[token_array._current.?];
        } else {
            token_array._current = token_array._current.? + 1;
            return token_array.tokens[token_array._current.?];
        }
    }

    pub fn skipUntil(lexer: *TokenArray, comptime until: []const Lexer.Token.Kind) void {
        while (true) {
            const token = lexer.next();
            inline for (until) |until_kind| {
                if (token.kind == until_kind or token.kind == .eof) {
                    return;
                }
            }
        }
    }

    pub fn current(lexer: *const TokenArray) ?Lexer.Token {
        if (lexer._current) |__current| {
            return lexer.tokens[__current];
        } else {
            return null;
        }
    }
};

source: ?[:0]const u8,
token_array: ?TokenArray,
error_report_array: ErrorReportArray,
ast_node_array: Parser.ASTNodeArray,
ast_node_root: ?usize,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, error_report_array_size: u32, ast_node_array_size: u32) error{OutOfMemory}!Module {
    var error_report_array = try ErrorReportArray.init(allocator, error_report_array_size);
    errdefer error_report_array.deinit(allocator);

    var ast_node_array = try Parser.ASTNodeArray.init(allocator, ast_node_array_size);
    errdefer ast_node_array.deinit(allocator);

    return Module{
        .allocator = allocator,
        .ast_node_array = ast_node_array,
        .error_report_array = error_report_array,
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

    module.* = Module{
        .allocator = undefined,
        .ast_node_array = undefined,
        .error_report_array = undefined,
        .ast_node_root = null,
        .source = null,
        .token_array = null,
    };
}

pub fn lex(module: *Module, source: [:0]const u8) error{ OutOfMemory, OutOfCapacity }!void {
    module.source = source;
    var lexer = Lexer.init(source);

    var token_count: usize = 0;
    while (true) {
        token_count += 1;
        const token = try lexer.next(&module.error_report_array);
        if (token.kind == .eof) {
            break;
        }
    }
    const token_array = try module.allocator.alloc(Lexer.Token, token_count);
    module.token_array = TokenArray{
        .tokens = token_array,
        ._current = null,
    };

    module.error_report_array.clear();

    lexer = Lexer.init(source);

    for (0..token_count) |i| {
        token_array[i] = try lexer.next(&module.error_report_array);
    }
}

pub fn parse(module: *Module) error{OutOfCapacity}!void {
    if (module.token_array) |*token_array| {
        module.ast_node_root = try Parser.parseRoot(&module.ast_node_array, token_array, &module.error_report_array);
    }
}

pub fn report(module: *Module) void {
    if (module.source) |source| {
        for (module.error_report_array.raw()) |error_report| {
            ErrorReport.report(error_report, source);
        }
    }
}
