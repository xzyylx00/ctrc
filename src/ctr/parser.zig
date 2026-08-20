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

const aslib = @import("aslib");
const std = @import("std");
const Lexer = @import("lexer.zig");
const Module = @import("module.zig");
const ErrorReportArray = @import("error.zig").ErrorReportArray;
const TokenArray = @import("token_array.zig").TokenArray;
const Token = Lexer.Token;
const ASTNode = @import("ast.zig").ASTNode;
const ASTNodeArray = @import("ast.zig").ASTNodeArray;

fn releaseASTNode(ast_node_array: *ASTNodeArray, node_index: usize) void {
    const ast_node = ast_node_array.get(node_index) catch unreachable;

    switch (ast_node.kind) {
        else => {},
    }
}

pub fn parseRoot(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Root at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Root at {any}", .{Module.Position.toPosition(lexer.current())});
    const ast_node_index = try ast_node_array.alloc();

    const containor_node_index = try parseBlockExpressionContent(ast_node_array, lexer, error_report_array);
    if (containor_node_index) |_containor_node_index| {
        const eof_token = lexer.next();
        if (eof_token.kind != .eof) {
            // XXX Error
            releaseASTNode(ast_node_array, _containor_node_index);
            ast_node_array.free(ast_node_index) catch unreachable;

            try error_report_array.addUnexpectedTokenReport("\\0", .toRange(eof_token), .toPosition(eof_token));

            return null;
        }

        const ast_node = ASTNode{
            .kind = .root,
            .data = .{
                .root = .{
                    .containor = _containor_node_index,
                },
            },
        };

        ast_node_array.set(ast_node_index, ast_node) catch unreachable;
        return ast_node_index;
    } else {
        // XXX Error
        try error_report_array.addExpectedExpressionReport(.toPosition(lexer.current()));

        ast_node_array.free(ast_node_index) catch unreachable;
        return null;
    }
}

fn parseBlockExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Block Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Block Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    const lbrace_token = lexer.next();
    if (lbrace_token.kind == .l_brace) {
        const context_node = try parseBlockExpressionContent(ast_node_array, lexer, error_report_array);
        if (context_node) |_context_node| {
            const rbrace_token = lexer.next();
            if (rbrace_token.kind == .r_brace) {
                return _context_node;
            } else {
                // XXX Error
                try error_report_array.addUnexpectedTokenReport("}", .toRange(rbrace_token), .toPosition(rbrace_token));
            }
            return null;
        } else {
            // Should this have error report?
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addUnexpectedTokenReport("{", .toRange(lbrace_token), .toPosition(lbrace_token));
        return null;
    }
}

fn parseBlockExpressionContent(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing BlockExpressionContent at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving BlockExpressionContent at {any}", .{Module.Position.toPosition(lexer.current())});
    const ast_node_index = try ast_node_array.alloc();

    var block_expression_node = ASTNode{
        .kind = .block_expression,
        .data = .{
            .block_expression = .{
                .expression = undefined,
                .statement = null,
            },
        },
    };

    var first_statement_node_index: ?usize = null;
    var current_statement_node_index: ?usize = null;
    while (try parseStatement(ast_node_array, lexer, error_report_array)) |statement_node_index| {
        if (first_statement_node_index == null) {
            first_statement_node_index = statement_node_index;
        }
        if (current_statement_node_index) |_current_statement_node_index| {
            const current_statement_node = ast_node_array.get(_current_statement_node_index) catch unreachable;
            const linked_statement_node = ASTNode{
                .kind = .statement,
                .data = .{
                    .statement = .{
                        .kind = current_statement_node.data.statement.kind,
                        .next = statement_node_index,
                        .statement = current_statement_node.data.statement.statement,
                    },
                },
            };
            ast_node_array.set(_current_statement_node_index, linked_statement_node) catch unreachable;
        }
        current_statement_node_index = statement_node_index;
    }

    if (first_statement_node_index) |_first_statement_nodex_index| {
        block_expression_node = .{
            .kind = .block_expression,
            .data = .{
                .block_expression = .{
                    .statement = _first_statement_nodex_index,
                    .expression = undefined,
                },
            },
        };
    }

    if (try parseExpression(ast_node_array, lexer, error_report_array)) |expression_node_index| {
        block_expression_node = .{
            .kind = .block_expression,
            .data = .{
                .block_expression = .{
                    .statement = block_expression_node.data.block_expression.statement,
                    .expression = expression_node_index,
                },
            },
        };
        ast_node_array.set(ast_node_index, block_expression_node) catch unreachable;
        return ast_node_index;
    } else {
        // XXX Error
        try error_report_array.addExpectedExpressionReport(.toPosition(lexer.current()));

        ast_node_array.free(ast_node_index) catch unreachable;
        if (first_statement_node_index) |_first_statement_node_index| {
            releaseASTNode(ast_node_array, _first_statement_node_index);
        }
        return null;
    }
}

fn parseStatement(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    const statement_node_index = try ast_node_array.alloc();
    const previous_lexer = lexer.*;

    if (try parseAssignmentStatement(ast_node_array, lexer, error_report_array)) |assignment_node_index| {
        const statement_node = ASTNode{
            .kind = .statement,
            .data = .{
                .statement = .{
                    .kind = .assignment,
                    .statement = assignment_node_index,
                    .next = null,
                },
            },
        };

        // Should this have error report?
        ast_node_array.set(statement_node_index, statement_node) catch unreachable;
        return statement_node_index;
    } else {
        lexer.* = previous_lexer;
    }

    if (try parseCallStatement(ast_node_array, lexer, error_report_array)) |call_node_index| {
        const statement_node = ASTNode{
            .kind = .statement,
            .data = .{
                .statement = .{
                    .kind = .call,
                    .statement = call_node_index,
                    .next = null,
                },
            },
        };

        // Should this have error report?
        ast_node_array.set(statement_node_index, statement_node) catch unreachable;
        return statement_node_index;
    } else {
        lexer.* = previous_lexer;
    }

    if (try parseBreakStatement(ast_node_array, lexer, error_report_array)) |break_node_index| {
        const statement_node = ASTNode{
            .kind = .statement,
            .data = .{
                .statement = .{
                    .kind = .@"break",
                    .statement = break_node_index,
                    .next = null,
                },
            },
        };

        // Should this have error report?
        ast_node_array.set(statement_node_index, statement_node) catch unreachable;
        return statement_node_index;
    } else {
        lexer.* = previous_lexer;
    }

    if (try parseContinueStatement(ast_node_array, lexer, error_report_array)) |continue_node_index| {
        const statement_node = ASTNode{
            .kind = .statement,
            .data = .{
                .statement = .{
                    .kind = .@"continue",
                    .statement = continue_node_index,
                    .next = null,
                },
            },
        };

        // Should this have error report?
        ast_node_array.set(statement_node_index, statement_node) catch unreachable;
        return statement_node_index;
    } else {
        lexer.* = previous_lexer;
    }

    ast_node_array.free(statement_node_index) catch unreachable;
    return null;
}

fn parseAssignmentStatement(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Assignment Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Assignment Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    const assignment_node_index = try ast_node_array.alloc();

    var first_target_node_index: ?usize = null;
    var current_target_node_index: ?usize = null;
    while (try parseAssignmentTarget(ast_node_array, lexer, error_report_array)) |target_node_index| {
        if (first_target_node_index == null) {
            first_target_node_index = target_node_index;
        }

        if (current_target_node_index) |_current_target_node_index| {
            const current_target_node = ast_node_array.get(_current_target_node_index) catch unreachable;
            const linked_target_node = ASTNode{
                .data = .{
                    .assignment_target = .{
                        .access_attribute = current_target_node.data.assignment_target.access_attribute,
                        .name = current_target_node.data.assignment_target.name,
                        .next = target_node_index,
                    },
                },
                .kind = .assignment_target,
            };

            ast_node_array.set(_current_target_node_index, linked_target_node) catch unreachable;
        }

        current_target_node_index = target_node_index;

        const peek_token = lexer.peek();
        if (peek_token) |_peek_token| {
            if (_peek_token.kind != .comma) {
                break;
            } else {
                _ = lexer.next();
            }
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport("',' or '}'", .toRange(lexer.current()), .toPosition(lexer.current()));

            if (first_target_node_index) |_first_target_node_index| {
                releaseASTNode(ast_node_array, _first_target_node_index);
            }
            ast_node_array.free(assignment_node_index) catch unreachable;
            return null;
        }
    }

    if (first_target_node_index == null) {
        ast_node_array.free(assignment_node_index) catch unreachable;
        return null;
    }

    const equal_token = lexer.peek();
    if (equal_token) |_equal_token| {
        if (_equal_token.kind != .equal) {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport(
                "'='",
                .toRange(_equal_token),
                .toPosition(_equal_token),
            );

            // Skip
            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

            releaseASTNode(ast_node_array, first_target_node_index.?);
            ast_node_array.free(assignment_node_index) catch unreachable;
            return null;
        }

        _ = lexer.next();
    } else {
        // XXX Error
        try error_report_array.addUnexpectedTokenReport("'='", .toRange(lexer.current()), .toPosition(lexer.current()));

        // Skip
        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

        releaseASTNode(ast_node_array, first_target_node_index.?);
        ast_node_array.free(assignment_node_index) catch unreachable;
        return null;
    }

    var expression_node_index: ?usize = null;
    if (try parseSingleExpression(ast_node_array, lexer, error_report_array)) |_expression_node_index| {
        expression_node_index = _expression_node_index;
    } else {
        // XXX Error
        try error_report_array.addExpectedExpressionReport(.toPosition(lexer.current()));

        // Skip
        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

        releaseASTNode(ast_node_array, first_target_node_index.?);
        ast_node_array.free(assignment_node_index) catch unreachable;
        return null;
    }

    const semicolon_token = lexer.peek();
    if (semicolon_token) |_semicolon_token| {
        if (_semicolon_token.kind == .semicolon) {
            _ = lexer.next();
            const assignment_node = ASTNode{
                .data = .{
                    .assignment_statement = .{
                        .expression = expression_node_index.?,
                        .target = first_target_node_index.?,
                    },
                },
                .kind = .assignment_statement,
            };

            ast_node_array.set(assignment_node_index, assignment_node) catch unreachable;
            return assignment_node_index;
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport(
                "';'",
                .toRange(_semicolon_token),
                .toPosition(_semicolon_token),
            );

            // Skip
            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

            releaseASTNode(ast_node_array, first_target_node_index.?);
            releaseASTNode(ast_node_array, expression_node_index.?);
            return null;
        }
    } else {
        // XXX Error

        try error_report_array.addExpectedTokenReport("';'", .toPosition(lexer.current()));

        // Skip
        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

        releaseASTNode(ast_node_array, first_target_node_index.?);
        releaseASTNode(ast_node_array, expression_node_index.?);
        ast_node_array.free(assignment_node_index) catch unreachable;
        return null;
    }
}

fn parseAssignmentTarget(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Assignment Target at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Assignment Target at {any}", .{Module.Position.toPosition(lexer.current())});
    const assignment_target_node_index = try ast_node_array.alloc();

    const peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_in or _peek_token.kind == .keyword_out or _peek_token.kind == .keyword_inout) {
            _ = lexer.next();
            const name_token = lexer.peek();
            if (name_token) |_name_token| {
                if (_name_token.kind == .identifier) {
                    _ = lexer.next();
                    const assignment_target_node = ASTNode{
                        .data = .{
                            .assignment_target = .{
                                .access_attribute = switch (_peek_token.kind) {
                                    .keyword_in => .in,
                                    .keyword_out => .out,
                                    .keyword_inout => .inout,
                                    else => unreachable,
                                },
                                .name = .{
                                    .start = _name_token.start,
                                    .end = _name_token.end,
                                },
                                .next = null,
                            },
                        },
                        .kind = .assignment_target,
                    };

                    ast_node_array.set(assignment_target_node_index, assignment_target_node) catch unreachable;
                    return assignment_target_node_index;
                } else {
                    // XXX Error
                    try error_report_array.addUnexpectedTokenReport(
                        "Identifer",
                        .toRange(_name_token),
                        .toPosition(_name_token),
                    );

                    // Skip
                    lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

                    ast_node_array.free(assignment_target_node_index) catch unreachable;
                    return null;
                }
            } else {
                // XXX Error
                try error_report_array.addExpectedTokenReport(
                    "Identifer",
                    .toPosition(lexer.current()),
                );

                // Skip
                lexer.skipUntil(&[_]Lexer.Token.Kind{ .semicolon, .r_brace });
                ast_node_array.free(assignment_target_node_index) catch unreachable;
                return null;
            }
        } else if (_peek_token.kind == .underline) {
            _ = lexer.next();
            const assignment_target_node = ASTNode{
                .data = .{
                    .assignment_target = .{
                        .access_attribute = .none,
                        .name = .{
                            .start = _peek_token.start,
                            .end = _peek_token.end,
                        },
                        .next = null,
                    },
                },
                .kind = .assignment_target,
            };

            ast_node_array.set(assignment_target_node_index, assignment_target_node) catch unreachable;
            return assignment_target_node_index;
        } else {
            ast_node_array.free(assignment_target_node_index) catch unreachable;
            return null;
        }
    } else {
        ast_node_array.free(assignment_target_node_index) catch unreachable;
        return null;
    }
}

fn parseCallStatement(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Call Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Call Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    const call_statement_node_index = try ast_node_array.alloc();

    if (try parseCallExpression(ast_node_array, lexer, error_report_array)) |call_expression_node_index| {
        const semicolon_token = lexer.peek();
        if (semicolon_token) |_semicolon_token| {
            if (_semicolon_token.kind == .semicolon) {
                _ = lexer.next();
                const call_statement_node = ASTNode{
                    .data = .{
                        .call_statement = .{
                            .call_expression = call_expression_node_index,
                        },
                    },
                    .kind = .call_statement,
                };

                ast_node_array.set(call_statement_node_index, call_statement_node) catch unreachable;
                return call_statement_node_index;
            } else {
                try error_report_array.addUnexpectedTokenReport(
                    "';'",
                    .toRange(_semicolon_token),
                    .toPosition(_semicolon_token),
                );

                // Skip
                lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

                releaseASTNode(ast_node_array, call_expression_node_index);
                ast_node_array.free(call_statement_node_index) catch unreachable;
                return null;
            }
        } else {
            try error_report_array.addExpectedTokenReport(
                "';'",
                .toPosition(lexer.current()),
            );

            // Skip
            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

            releaseASTNode(ast_node_array, call_expression_node_index);
            ast_node_array.free(call_statement_node_index) catch unreachable;
            return null;
        }
    } else {
        ast_node_array.free(call_statement_node_index) catch unreachable;
        return null;
    }
}

fn parseCallExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Call Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Call Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    const call_expression_node_index = try ast_node_array.alloc();

    if (try parseLiteralExpression(ast_node_array, lexer, error_report_array)) |target_node_index| {
        var peek_token: ?Token = null;
        var first_call_parameter_node_index: ?usize = null;
        var current_call_parameter_node_index: ?usize = null;

        peek_token = lexer.peek();
        if (peek_token) |_peek_token| {
            if (_peek_token.kind != .l_paren) {
                ast_node_array.free(call_expression_node_index) catch unreachable;
                return null;
            } else {
                _ = lexer.next();
            }
        } else {
            ast_node_array.free(call_expression_node_index) catch unreachable;
            return null;
        }

        while (try parseCallParameter(ast_node_array, lexer, error_report_array)) |call_parameter_node_index| {
            if (first_call_parameter_node_index == null) {
                first_call_parameter_node_index = call_parameter_node_index;
            }

            if (current_call_parameter_node_index) |_current_call_parameter_node_index| {
                const current_call_parameter_node = ast_node_array.get(_current_call_parameter_node_index) catch unreachable;
                const linked_call_parameter_node = ASTNode{
                    .data = .{
                        .call_parameter = .{
                            .expression = current_call_parameter_node.data.call_parameter.expression,
                            .next = call_parameter_node_index,
                        },
                    },
                    .kind = .call_parameter,
                };

                ast_node_array.set(_current_call_parameter_node_index, linked_call_parameter_node) catch unreachable;
            }
            current_call_parameter_node_index = call_parameter_node_index;

            peek_token = lexer.peek();
            if (peek_token) |_peek_token| {
                if (_peek_token.kind == .comma) {
                    _ = lexer.next();
                    peek_token = lexer.peek();
                    if (peek_token) |__peek_token| {
                        if (__peek_token.kind == .r_paren) {
                            break;
                        }
                    } else {
                        // XXX Error

                        try error_report_array.addExpectedTokenReport(
                            "Expression or ')'",
                            .toPosition(lexer.current()),
                        );

                        // Skip
                        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

                        if (first_call_parameter_node_index) |_first_call_parameter_node_index| {
                            releaseASTNode(ast_node_array, _first_call_parameter_node_index);
                        }
                        ast_node_array.free(call_expression_node_index) catch unreachable;
                        return null;
                    }
                } else {
                    break;
                }
            } else {
                // XXX Error

                try error_report_array.addExpectedTokenReport(
                    "',', or ')'",
                    .toPosition(lexer.current()),
                );

                // Skip
                lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

                if (first_call_parameter_node_index) |_first_call_parameter_node_index| {
                    releaseASTNode(ast_node_array, _first_call_parameter_node_index);
                }
                ast_node_array.free(call_expression_node_index) catch unreachable;
                return null;
            }
        }

        peek_token = lexer.peek();
        if (peek_token) |_peek_token| {
            if (_peek_token.kind != .r_paren) {
                // XXX Error

                try error_report_array.addUnexpectedTokenReport(
                    "')'",
                    .toRange(_peek_token),
                    .toPosition(_peek_token),
                );

                // Skip
                lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

                if (first_call_parameter_node_index) |call_parameter_node_index| {
                    releaseASTNode(ast_node_array, call_parameter_node_index);
                }
                ast_node_array.free(call_expression_node_index) catch unreachable;

                return null;
            } else {
                _ = lexer.next();
            }
        } else {
            // XXX Error
            try error_report_array.addExpectedTokenReport(
                "')'",
                .toPosition(lexer.current()),
            );

            // Skip
            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

            if (first_call_parameter_node_index) |call_parameter_node_index| {
                releaseASTNode(ast_node_array, call_parameter_node_index);
            }
            ast_node_array.free(call_expression_node_index) catch unreachable;
            return null;
        }

        const call_expression_node = ASTNode{
            .data = .{
                .call_expression = .{
                    .parameter = first_call_parameter_node_index,
                    .target = target_node_index,
                },
            },
            .kind = .call_expression,
        };

        ast_node_array.set(call_expression_node_index, call_expression_node) catch unreachable;
        return call_expression_node_index;
    } else {
        ast_node_array.free(call_expression_node_index) catch unreachable;
        return null;
    }
}

fn parseCallParameter(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Call Parameter at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Call Parameter at {any}", .{Module.Position.toPosition(lexer.current())});
    const call_parameter_node_index = try ast_node_array.alloc();

    if (try parseSingleExpression(ast_node_array, lexer, error_report_array)) |expression_node_index| {
        const call_parameter_node = ASTNode{
            .data = .{
                .call_parameter = .{
                    .expression = expression_node_index,
                    .next = null,
                },
            },
            .kind = .call_parameter,
        };
        ast_node_array.set(call_parameter_node_index, call_parameter_node) catch unreachable;
        return call_parameter_node_index;
    }

    return null;
}

fn parseExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    if (try parseMultipleExpression(ast_node_array, lexer, error_report_array)) |multiple_expression_node_index| {
        const multiple_expression_node = ast_node_array.get(multiple_expression_node_index) catch unreachable;

        if (multiple_expression_node.data.multiple_expression.next == null) {
            const single_expression_node_index = multiple_expression_node.data.multiple_expression.expression;
            ast_node_array.free(multiple_expression_node_index) catch unreachable;
            return single_expression_node_index;
        }

        return multiple_expression_node_index;
    } else {
        return null;
    }
}

fn parseSingleExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Single Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Single Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    const expression_node_index = try ast_node_array.alloc();
    const previous_lexer = lexer.*;

    const peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .identifier) {
            if (try parseLabelExpression(ast_node_array, lexer, error_report_array)) |label_expression_index| {
                const expression_node = ASTNode{
                    .kind = .expression,
                    .data = .{
                        .expression = .{
                            .expression = label_expression_index,
                            .kind = .label,
                        },
                    },
                };

                ast_node_array.set(expression_node_index, expression_node) catch unreachable;
                return expression_node_index;
            } else {
                lexer.* = previous_lexer;
            }
        }
        if (try parseCallExpression(ast_node_array, lexer, error_report_array)) |call_expression_index| {
            const expression_node = ASTNode{
                .kind = .expression,
                .data = .{
                    .expression = .{
                        .expression = call_expression_index,
                        .kind = .call,
                    },
                },
            };

            ast_node_array.set(expression_node_index, expression_node) catch unreachable;
            return expression_node_index;
        } else {
            lexer.* = previous_lexer;
        }

        if (try parseLiteralExpression(ast_node_array, lexer, error_report_array)) |literal_expression_index| {
            const expression_node = ASTNode{
                .kind = .expression,
                .data = .{
                    .expression = .{
                        .expression = literal_expression_index,
                        .kind = .literal,
                    },
                },
            };

            ast_node_array.set(expression_node_index, expression_node) catch unreachable;
            return expression_node_index;
        } else {
            lexer.* = previous_lexer;
        }

        if (_peek_token.kind == .keyword_match) {
            if (try parseMatchExpression(ast_node_array, lexer, error_report_array)) |match_expression_index| {
                const expression_node = ASTNode{
                    .kind = .expression,
                    .data = .{
                        .expression = .{
                            .expression = match_expression_index,
                            .kind = .match,
                        },
                    },
                };

                ast_node_array.set(expression_node_index, expression_node) catch unreachable;
                return expression_node_index;
            } else {
                lexer.* = previous_lexer;
            }
        }

        if (_peek_token.kind == .keyword_in or _peek_token.kind == .keyword_inout or _peek_token.kind == .keyword_out or _peek_token.kind == .keyword_ptr or _peek_token.kind == .keyword_ref) {
            if (try parseAttributedExpression(ast_node_array, lexer, error_report_array)) |attributed_expression_index| {
                const expression_node = ASTNode{
                    .kind = .expression,
                    .data = .{
                        .expression = .{
                            .expression = attributed_expression_index,
                            .kind = .attributed,
                        },
                    },
                };

                ast_node_array.set(expression_node_index, expression_node) catch unreachable;
                return expression_node_index;
            } else {
                lexer.* = previous_lexer;
            }
        }

        if (_peek_token.kind == .keyword_type) {
            if (try parseTypeExpression(ast_node_array, lexer, error_report_array)) |type_expression_index| {
                const expression_node = ASTNode{
                    .kind = .expression,
                    .data = .{
                        .expression = .{
                            .expression = type_expression_index,
                            .kind = .type,
                        },
                    },
                };

                ast_node_array.set(expression_node_index, expression_node) catch unreachable;
                return expression_node_index;
            } else {
                lexer.* = previous_lexer;
            }
        }
        if (_peek_token.kind == .keyword_function) {
            if (try parseFunctionExpression(ast_node_array, lexer, error_report_array)) |function_expression_index| {
                const expression_node = ASTNode{
                    .kind = .expression,
                    .data = .{
                        .expression = .{
                            .expression = function_expression_index,
                            .kind = .function,
                        },
                    },
                };

                ast_node_array.set(expression_node_index, expression_node) catch unreachable;
                return expression_node_index;
            } else {
                lexer.* = previous_lexer;
            }
        }
        if (_peek_token.kind == .l_brace) {
            if (try parseBlockExpression(ast_node_array, lexer, error_report_array)) |block_expression_index| {
                const expression_node = ASTNode{
                    .kind = .expression,
                    .data = .{
                        .expression = .{
                            .expression = block_expression_index,
                            .kind = .block,
                        },
                    },
                };

                ast_node_array.set(expression_node_index, expression_node) catch unreachable;
                return expression_node_index;
            } else {
                lexer.* = previous_lexer;
            }
        }
    } else {
        // XXX Error
    }

    ast_node_array.free(expression_node_index) catch unreachable;
    return null;
}

fn parseMultipleExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Multiple Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Multiple Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    // XXX Need error report
    var first_expression_node_index: ?usize = null;
    var current_expression_node_index: ?usize = null;
    while (true) {
        if (try parseSingleExpression(ast_node_array, lexer, error_report_array)) |expression_node_index| {
            const multiple_expression_node_index = try ast_node_array.alloc();
            if (first_expression_node_index == null) {
                first_expression_node_index = multiple_expression_node_index;
            }

            if (current_expression_node_index) |_current_expression_node_index| {
                const current_expression_node = ast_node_array.get(_current_expression_node_index) catch unreachable;
                const linked_expression_node = ASTNode{
                    .kind = .multiple_expression,
                    .data = .{
                        .multiple_expression = .{
                            .expression = current_expression_node.data.multiple_expression.expression,
                            .next = multiple_expression_node_index,
                        },
                    },
                };

                ast_node_array.set(_current_expression_node_index, linked_expression_node) catch unreachable;
            }

            current_expression_node_index = multiple_expression_node_index;

            const multiple_expression_node = ASTNode{
                .kind = .multiple_expression,
                .data = .{
                    .multiple_expression = .{
                        .expression = expression_node_index,
                        .next = null,
                    },
                },
            };
            ast_node_array.set(multiple_expression_node_index, multiple_expression_node) catch unreachable;
        }

        if (lexer.peek()) |peek_token| {
            if (peek_token.kind != .comma) {
                break;
            } else {
                _ = lexer.next();
            }
        } else {
            // Should this be error?
            break;
        }
    }

    return first_expression_node_index;
}

fn parseLiteralExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    _ = error_report_array;
    std.log.debug("Parsing Literal Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Literal Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    const literal_expression_node_index = try ast_node_array.alloc();

    const peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .string or _peek_token.kind == .char or _peek_token.kind == .identifier or _peek_token.kind == .integer or _peek_token.kind == .float or _peek_token.kind == .keyword_nil or _peek_token.kind == .macro or _peek_token.kind == .underline) {
            _ = lexer.next();
            const literal_expression_node = ASTNode{
                .data = .{
                    .literal_expression = .{
                        .kind = switch (_peek_token.kind) {
                            .string => .string,
                            .char => .char,
                            .identifier => .identifier,
                            .integer => .integer,
                            .float => .float,
                            .macro => .macro,
                            .underline => .underline,
                            .keyword_nil => .nil,
                            else => unreachable,
                        },
                        .position = .{
                            .start = _peek_token.start,
                            .end = _peek_token.end,
                        },
                    },
                },
                .kind = .literal_expression,
            };

            ast_node_array.set(literal_expression_node_index, literal_expression_node) catch unreachable;
            return literal_expression_node_index;
        } else {
            ast_node_array.free(literal_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        ast_node_array.free(literal_expression_node_index) catch unreachable;
        return null;
    }
}

fn parseTypeExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Type Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Type Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    const type_expression_node_index = try ast_node_array.alloc();

    var peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_type) {
            _ = lexer.next();
        } else {
            ast_node_array.free(type_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport(
            "'type'",
            .toPosition(lexer.current()),
        );

        ast_node_array.free(type_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_paren) {
            _ = lexer.next();
        } else {
            // XXX Error

            try error_report_array.addUnexpectedTokenReport(
                "'('",
                .toRange(_peek_token),
                .toPosition(_peek_token),
            );

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

            ast_node_array.free(type_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error

        try error_report_array.addExpectedTokenReport(
            "'('",
            .toPosition(lexer.current()),
        );

        ast_node_array.free(type_expression_node_index) catch unreachable;
        return null;
    }

    var expression_node_index: ?usize = null;
    if (try parseExpression(ast_node_array, lexer, error_report_array)) |_expression_node_index| {
        expression_node_index = _expression_node_index;
    } else {
        // XXX Error

        try error_report_array.addExpectedExpressionReport(.toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

        ast_node_array.free(type_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport(
                "')'",
                .toRange(_peek_token),

                .toPosition(_peek_token),
            );

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

            releaseASTNode(ast_node_array, expression_node_index.?);
            ast_node_array.free(type_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport(
            "')'",
            .toPosition(lexer.current()),
        );

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

        releaseASTNode(ast_node_array, expression_node_index.?);

        ast_node_array.free(type_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_brace) {
            _ = lexer.next();
        } else {
            // XXX Error

            try error_report_array.addUnexpectedTokenReport(
                "'{'",
                .toRange(_peek_token),
                .toPosition(_peek_token),
            );

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            releaseASTNode(ast_node_array, expression_node_index.?);

            ast_node_array.free(type_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport(
            "'{'",
            .toPosition(lexer.current()),
        );

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

        releaseASTNode(ast_node_array, expression_node_index.?);

        ast_node_array.free(type_expression_node_index) catch unreachable;
        return null;
    }

    var first_type_entry_node_index: ?usize = null;
    var current_type_entry_node_index: ?usize = null;

    while (try parseTypeEntry(ast_node_array, lexer, error_report_array)) |type_entry_node_index| {
        if (first_type_entry_node_index == null) {
            first_type_entry_node_index = type_entry_node_index;
        }

        if (current_type_entry_node_index) |_current_type_entry_node_index| {
            const current_type_entry_node = ast_node_array.get(_current_type_entry_node_index) catch unreachable;
            const linked_type_entry_node = ASTNode{
                .data = .{
                    .type_entry = .{
                        .next = type_entry_node_index,
                        .expression = current_type_entry_node.data.type_entry.expression,
                        .name = current_type_entry_node.data.type_entry.name,
                    },
                },
                .kind = .type_entry,
            };
            ast_node_array.set(_current_type_entry_node_index, linked_type_entry_node) catch unreachable;
        }

        current_type_entry_node_index = type_entry_node_index;

        peek_token = lexer.peek();
        if (peek_token) |_peek_token| {
            if (_peek_token.kind == .comma) {
                _ = lexer.next();
                peek_token = lexer.peek();
                if (peek_token) |__peek_token| {
                    if (__peek_token.kind == .r_brace) {
                        break;
                    }
                } else {
                    try error_report_array.addExpectedTokenReport("TypeEntry or '}'", .toPosition(lexer.current()));

                    lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

                    releaseASTNode(ast_node_array, expression_node_index.?);
                    ast_node_array.free(type_expression_node_index) catch unreachable;
                    return null;
                }
            } else {
                break;
            }
        } else {
            try error_report_array.addExpectedTokenReport("',', or '}'", .toPosition(lexer.current()));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

            releaseASTNode(ast_node_array, expression_node_index.?);
            ast_node_array.free(type_expression_node_index) catch unreachable;
            return null;
        }
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_brace) {
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport(
                "'}'",
                .toRange(_peek_token),
                .toPosition(_peek_token),
            );

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(type_expression_node_index) catch unreachable;
            if (first_type_entry_node_index) |_first_type_entry_node_index| {
                releaseASTNode(ast_node_array, _first_type_entry_node_index);
            }
            return null;
        }
    } else {
        // XXX Error

        try error_report_array.addExpectedTokenReport(
            "'}'",
            .toPosition(lexer.current()),
        );

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(type_expression_node_index) catch unreachable;
        if (first_type_entry_node_index) |_first_type_entry_node_index| {
            releaseASTNode(ast_node_array, _first_type_entry_node_index);
        }
        ast_node_array.free(type_expression_node_index) catch unreachable;
        return null;
    }

    const type_expression_node = ASTNode{
        .data = .{
            .type_expression = .{
                .entry = first_type_entry_node_index,
                .kind = expression_node_index.?,
            },
        },
        .kind = .type_expression,
    };
    ast_node_array.set(type_expression_node_index, type_expression_node) catch unreachable;
    return type_expression_node_index;
}

fn parseTypeEntry(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Type Entry at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Type Entry at {any}", .{Module.Position.toPosition(lexer.current())});
    const type_entry_node_index = try ast_node_array.alloc();

    var name_token: Token = undefined;
    var peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .identifier) {
            name_token = _peek_token;
            _ = lexer.next();
        } else {
            ast_node_array.free(type_entry_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport(
            "Identifer, or '}'",
            .toPosition(lexer.current()),
        );

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(type_entry_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .colon) {
            _ = lexer.next();
        } else {
            const type_entry_node = ASTNode{
                .data = .{
                    .type_entry = .{
                        .expression = null,
                        .name = .{
                            .start = name_token.start,
                            .end = name_token.end,
                        },
                        .next = null,
                    },
                },
                .kind = .type_entry,
            };

            ast_node_array.set(type_entry_node_index, type_entry_node) catch unreachable;

            return type_entry_node_index;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport(
            "':', or '}'",

            .toPosition(lexer.current()),
        );

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

        ast_node_array.free(type_entry_node_index) catch unreachable;
        return null;
    }

    var expression_node_index: ?usize = undefined;
    if (try parseSingleExpression(ast_node_array, lexer, error_report_array)) |_expression_node_index| {
        expression_node_index = _expression_node_index;
    }
    const type_entry_node = ASTNode{
        .data = .{
            .type_entry = .{
                .expression = expression_node_index,
                .name = .{
                    .start = name_token.start,
                    .end = name_token.end,
                },
                .next = null,
            },
        },
        .kind = .type_entry,
    };

    ast_node_array.set(type_entry_node_index, type_entry_node) catch unreachable;

    return type_entry_node_index;
}

fn parseFunctionParameter(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Function Parameter at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Function Parameter at {any}", .{Module.Position.toPosition(lexer.current())});
    const function_parameter_node_index = try ast_node_array.alloc();

    var peek_token = lexer.peek();
    var attribute_token: Token = undefined;
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_in or _peek_token.kind == .keyword_inout or _peek_token.kind == .keyword_out) {
            attribute_token = _peek_token;
            _ = lexer.next();
        } else {
            ast_node_array.free(function_parameter_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("')'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

        ast_node_array.free(function_parameter_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    var name_token: Token = undefined;
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .identifier) {
            name_token = _peek_token;
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport("Identifer", .toRange(_peek_token), .toPosition(_peek_token));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(function_parameter_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport(
            "Identifier",
            .toPosition(lexer.current()),
        );

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(function_parameter_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .colon) {
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport(
                "':'",
                .toRange(_peek_token),
                .toPosition(_peek_token),
            );

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(function_parameter_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("':", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

        ast_node_array.free(function_parameter_node_index) catch unreachable;
        return null;
    }

    if (try parseSingleExpression(ast_node_array, lexer, error_report_array)) |expression_node_index| {
        const function_parameter_node = ASTNode{
            .data = .{
                .function_parameter = .{
                    .expression = expression_node_index,
                    .access_attribute = switch (attribute_token.kind) {
                        .keyword_in => .in,
                        .keyword_out => .out,
                        .keyword_inout => .inout,
                        else => unreachable,
                    },
                    .name = .{
                        .start = name_token.start,
                        .end = name_token.end,
                    },
                    .next = null,
                },
            },
            .kind = .function_parameter,
        };
        ast_node_array.set(function_parameter_node_index, function_parameter_node) catch unreachable;
        return function_parameter_node_index;
    } else {
        // XXX Error
        try error_report_array.addExpectedExpressionReport(
            .toPosition(lexer.current()),
        );

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(function_parameter_node_index) catch unreachable;
        return null;
    }
}

fn parseFunctionExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Function Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Function Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    const function_expression_node_index = try ast_node_array.alloc();

    var peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_function) {
            _ = lexer.next();
        } else {
            ast_node_array.free(function_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'function'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(function_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport(
                "'('",
                .toRange(_peek_token),
                .toPosition(_peek_token),
            );

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(function_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport(
            "'('",
            .toPosition(lexer.current()),
        );

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(function_expression_node_index) catch unreachable;
        return null;
    }

    var first_function_parameter_node_index: ?usize = null;
    var current_function_parameter_node_index: ?usize = null;

    while (try parseFunctionParameter(ast_node_array, lexer, error_report_array)) |function_parameter_node_index| {
        if (first_function_parameter_node_index == null) {
            first_function_parameter_node_index = function_parameter_node_index;
        }

        if (current_function_parameter_node_index) |_current_function_parameter_node_index| {
            const current_function_parameter_node = ast_node_array.get(_current_function_parameter_node_index) catch unreachable;
            const linked_function_parameter_node = ASTNode{
                .data = .{
                    .function_parameter = .{
                        .access_attribute = current_function_parameter_node.data.function_parameter.access_attribute,
                        .expression = current_function_parameter_node.data.function_parameter.expression,
                        .name = current_function_parameter_node.data.function_parameter.name,
                        .next = function_parameter_node_index,
                    },
                },
                .kind = .function_parameter,
            };

            ast_node_array.set(_current_function_parameter_node_index, linked_function_parameter_node) catch unreachable;
        }

        current_function_parameter_node_index = function_parameter_node_index;

        peek_token = lexer.peek();
        if (peek_token) |_peek_token| {
            if (_peek_token.kind == .comma) {
                _ = lexer.next();
                peek_token = lexer.peek();
                if (peek_token) |__peek_token| {
                    if (__peek_token.kind == .r_paren) {
                        break;
                    }
                } else {
                    // XXX Error
                    try error_report_array.addExpectedTokenReport(
                        "Function Parameter Definition or ')'",
                        .toPosition(lexer.current()),
                    );

                    lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
                    ast_node_array.free(function_expression_node_index) catch unreachable;
                    return null;
                }
            } else {
                break;
            }
        } else {
            // XXX Error
            try error_report_array.addExpectedTokenReport(
                "',', or ')'",
                .toPosition(lexer.current()),
            );

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(function_expression_node_index) catch unreachable;
            return null;
        }
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport(
                "')'",
                .toRange(_peek_token),
                .toPosition(_peek_token),
            );

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});

            ast_node_array.free(function_expression_node_index) catch unreachable;
            if (first_function_parameter_node_index) |_first_function_parameter_node_index| {
                releaseASTNode(ast_node_array, _first_function_parameter_node_index);
            }
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("')'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(function_expression_node_index) catch unreachable;
        if (first_function_parameter_node_index) |_first_function_parameter_node_index| {
            releaseASTNode(ast_node_array, _first_function_parameter_node_index);
        }
        return null;
    }

    var first_function_attribute_node_index: ?usize = null;
    var current_function_attribute_node_index: ?usize = null;
    while (try parseFunctionAttribute(ast_node_array, lexer, error_report_array)) |function_attribute_node_index| {
        if (first_function_attribute_node_index == null) {
            first_function_attribute_node_index = function_attribute_node_index;
        }

        if (current_function_attribute_node_index) |_current_function_attribute_node_index| {
            const current_function_attribute_node = ast_node_array.get(_current_function_attribute_node_index) catch unreachable;
            const linked_function_attribute_node = ASTNode{
                .data = .{
                    .function_attribute = .{
                        .expression = current_function_attribute_node.data.function_attribute.expression,
                        .kind = current_function_attribute_node.data.function_attribute.kind,
                        .next = function_attribute_node_index,
                    },
                },
                .kind = .function_attribute,
            };

            ast_node_array.set(_current_function_attribute_node_index, linked_function_attribute_node) catch unreachable;
        }

        current_function_attribute_node_index = function_attribute_node_index;
    }

    const expression = try parseExpression(ast_node_array, lexer, error_report_array);

    const function_expression_node = ASTNode{
        .data = .{
            .function_expression = .{
                .expression = expression,
                .parameter = first_function_parameter_node_index,
                .attribute = first_function_attribute_node_index,
            },
        },
        .kind = .function_expression,
    };

    ast_node_array.set(function_expression_node_index, function_expression_node) catch unreachable;
    return function_expression_node_index;
}

fn parseFunctionAttribute(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Function Attribute at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Function Attribute at {any}", .{Module.Position.toPosition(lexer.current())});
    const function_attribute_node_index = try ast_node_array.alloc();

    var peek_token = lexer.peek();
    var attribute_kind_token: Token = undefined;
    if (peek_token) |_peek_token| {
        if (_peek_token.kind != .keyword_internal and _peek_token.kind != .keyword_external) {
            ast_node_array.free(function_attribute_node_index) catch unreachable;
            return null;
        }
        attribute_kind_token = lexer.next();
    } else {
        ast_node_array.free(function_attribute_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind != .l_paren) {
            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            try error_report_array.addUnexpectedTokenReport("'('", .toRange(_peek_token), .toPosition(_peek_token));
            ast_node_array.free(function_attribute_node_index) catch unreachable;
            return null;
        }
        _ = lexer.next();
    } else {
        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        try error_report_array.addExpectedTokenReport("'('", .toPosition(lexer.current()));
        ast_node_array.free(function_attribute_node_index) catch unreachable;
        return null;
    }

    const expression = try parseSingleExpression(ast_node_array, lexer, error_report_array);

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind != .r_paren) {
            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            try error_report_array.addUnexpectedTokenReport("'('", .toRange(_peek_token), .toPosition(_peek_token));
            ast_node_array.free(function_attribute_node_index) catch unreachable;
            return null;
        }
        _ = lexer.next();
    } else {
        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        try error_report_array.addExpectedTokenReport("'('", .toPosition(lexer.current()));
        ast_node_array.free(function_attribute_node_index) catch unreachable;
        return null;
    }

    const function_attribute_node = ASTNode{
        .data = .{
            .function_attribute = .{
                .expression = expression,
                .kind = switch (attribute_kind_token.kind) {
                    .keyword_internal => .internal,
                    .keyword_external => .external,
                    else => unreachable,
                },
                .next = null,
            },
        },
        .kind = .function_attribute,
    };

    ast_node_array.set(function_attribute_node_index, function_attribute_node) catch unreachable;
    return function_attribute_node_index;
}

fn parseLabelExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Label Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Label Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    const label_expression_node_index = try ast_node_array.alloc();

    var label_expression: usize = undefined;
    if (try parseLiteralExpression(ast_node_array, lexer, error_report_array)) |_label_expression| {
        label_expression = _label_expression;
    } else {
        ast_node_array.free(label_expression_node_index) catch unreachable;
        return null;
    }

    const peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .colon) {
            _ = lexer.next();
        } else {
            ast_node_array.free(label_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        ast_node_array.free(label_expression_node_index) catch unreachable;
        return null;
    }

    if (try parseExpression(ast_node_array, lexer, error_report_array)) |expression| {
        const label_expression_node = ASTNode{
            .data = .{
                .label_expression = .{
                    .expression = expression,
                    .label = label_expression,
                },
            },
            .kind = .label_expression,
        };
        ast_node_array.set(label_expression_node_index, label_expression_node) catch unreachable;
        return label_expression_node_index;
    } else {
        // XXX Error
        try error_report_array.addExpectedExpressionReport(.toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(label_expression_node_index) catch unreachable;
        return null;
    }
}

fn parseMatchExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Match Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Match Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    const match_expression_node_index = try ast_node_array.alloc();

    var peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_match) {
            _ = lexer.next();
        } else {
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'match'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport("'('", .toRange(_peek_token), .toPosition(_peek_token));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'('", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    var expression: usize = undefined;
    if (try parseExpression(ast_node_array, lexer, error_report_array)) |_expression| {
        expression = _expression;
    } else {
        // XXX Error
        try error_report_array.addExpectedExpressionReport(.toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport("')'", .toRange(_peek_token), .toPosition(_peek_token));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("')'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_brace) {
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport("'{'", .toRange(_peek_token), .toPosition(_peek_token));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'{'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    var first_match_case_node_index: ?usize = null;
    var current_match_case_node_index: ?usize = null;
    while (try parseMatchCase(ast_node_array, lexer, error_report_array)) |match_case_node_index| {
        if (first_match_case_node_index == null) {
            first_match_case_node_index = match_case_node_index;
        }

        if (current_match_case_node_index) |_current_match_case_node_index| {
            const current_match_case_node = ast_node_array.get(_current_match_case_node_index) catch unreachable;
            const linked_match_case_node = ASTNode{
                .data = .{
                    .match_case = .{
                        .expression = current_match_case_node.data.match_case.expression,
                        .next = match_case_node_index,
                    },
                },
                .kind = .match_case,
            };

            ast_node_array.set(_current_match_case_node_index, linked_match_case_node) catch unreachable;
        }

        current_match_case_node_index = match_case_node_index;

        peek_token = lexer.peek();
        if (peek_token) |_peek_token| {
            if (_peek_token.kind != .semicolon) {
                break;
            } else {
                _ = lexer.next();
            }
        } else {
            // XXX Error
            try error_report_array.addExpectedTokenReport(";', or '}'", .toPosition(lexer.current()));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_brace) {
            _ = lexer.next();
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport("'}'", .toRange(_peek_token), .toPosition(_peek_token));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            if (first_match_case_node_index) |_first_match_case_node_index| {
                releaseASTNode(ast_node_array, _first_match_case_node_index);
            }
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'}'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        if (first_match_case_node_index) |_first_match_case_node_index| {
            releaseASTNode(ast_node_array, _first_match_case_node_index);
        }
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    const match_expression_node = ASTNode{
        .data = .{
            .match_expression = .{
                .case = first_match_case_node_index,
                .expression = expression,
            },
        },
        .kind = .match_expression,
    };

    ast_node_array.set(match_expression_node_index, match_expression_node) catch unreachable;
    return match_expression_node_index;
}

fn parseMatchCase(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Match Case at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Match Case at {any}", .{Module.Position.toPosition(lexer.current())});
    const match_case_node_index = try ast_node_array.alloc();

    const peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_case) {
            _ = lexer.next();
        } else if (_peek_token.kind == .r_brace) {
            ast_node_array.free(match_case_node_index) catch unreachable;
            return null;
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport("'case'", .toRange(_peek_token), .toPosition(_peek_token));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(match_case_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'case'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(match_case_node_index) catch unreachable;
        return null;
    }

    if (try parseLabelExpression(ast_node_array, lexer, error_report_array)) |label_expression| {
        const match_case_node = ASTNode{
            .data = .{
                .match_case = .{
                    .expression = label_expression,
                    .next = null,
                },
            },
            .kind = .match_case,
        };

        ast_node_array.set(match_case_node_index, match_case_node) catch unreachable;
        return match_case_node_index;
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("Label", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(match_case_node_index) catch unreachable;
        return null;
    }
}

fn parseAttributedExpression(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Attributed Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Attribute Expression at {any}", .{Module.Position.toPosition(lexer.current())});
    const attributed_expression_node_index = try ast_node_array.alloc();

    if (lexer.peek()) |peek_token| {
        if (peek_token.kind == .keyword_in or peek_token.kind == .keyword_out or peek_token.kind == .keyword_inout or peek_token.kind == .keyword_ptr or peek_token.kind == .keyword_ref) {
            _ = lexer.next();

            if (try parseExpression(ast_node_array, lexer, error_report_array)) |expression| {
                const attributed_expression_node = ASTNode{
                    .data = .{
                        .attributed_expression = .{
                            .expression = expression,
                            .kind = switch (peek_token.kind) {
                                .keyword_in => .in,
                                .keyword_out => .out,
                                .keyword_inout => .inout,
                                .keyword_ptr => .ptr,
                                .keyword_ref => .ref,
                                else => unreachable,
                            },
                        },
                    },
                    .kind = .attributed_expression,
                };

                ast_node_array.set(attributed_expression_node_index, attributed_expression_node) catch unreachable;
                return attributed_expression_node_index;
            }
        } else {
            ast_node_array.free(attributed_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'in', 'out', 'inout', 'nil', 'ptr', 'ref', Identifier, '_'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(attributed_expression_node_index) catch unreachable;
        return null;
    }

    ast_node_array.free(attributed_expression_node_index) catch unreachable;
    return null;
}

fn parseBreakStatement(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Break Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Break Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    const break_statement_node_index = try ast_node_array.alloc();

    if (lexer.peek()) |peek_token| {
        if (peek_token.kind == .keyword_break) {
            _ = lexer.next();
        } else {
            ast_node_array.free(break_statement_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'break'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(break_statement_node_index) catch unreachable;
        return null;
    }

    const target_token: ?Token = lexer.peek();
    if (target_token) |_target_token| {
        if (_target_token.kind == .identifier) {
            _ = lexer.next();
            if (try parseExpression(ast_node_array, lexer, error_report_array)) |expression| {
                if (lexer.peek()) |peek_token| {
                    if (peek_token.kind != .semicolon) {
                        // XXX Error
                        try error_report_array.addUnexpectedTokenReport("')'", .toRange(peek_token), .toPosition(peek_token));

                        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
                        releaseASTNode(ast_node_array, expression);
                        ast_node_array.free(break_statement_node_index) catch unreachable;
                        return null;
                    } else {
                        _ = lexer.next();
                    }
                } else {
                    // XXX Error
                    try error_report_array.addExpectedTokenReport("';'", .toPosition(lexer.current()));

                    lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
                    releaseASTNode(ast_node_array, expression);
                    ast_node_array.free(break_statement_node_index) catch unreachable;
                    return null;
                }

                const break_statement_node = ASTNode{
                    .data = .{
                        .break_statement = .{
                            .expression = expression,
                            .name = .{
                                .start = _target_token.start,
                                .end = _target_token.end,
                            },
                        },
                    },
                    .kind = .break_statement,
                };
                ast_node_array.set(break_statement_node_index, break_statement_node) catch unreachable;
                return break_statement_node_index;
            } else {
                // XXX Error
                try error_report_array.addExpectedExpressionReport(.toPosition(lexer.current()));

                lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
                ast_node_array.free(break_statement_node_index) catch unreachable;
                return null;
            }
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport("Identifier", .toRange(_target_token), .toPosition(_target_token));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(break_statement_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'break'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(break_statement_node_index) catch unreachable;
        return null;
    }
}

fn parseContinueStatement(ast_node_array: *ASTNodeArray, lexer: *TokenArray, error_report_array: *ErrorReportArray) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Continue Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    defer std.log.debug("Leaving Continue Statement at {any}", .{Module.Position.toPosition(lexer.current())});
    const continue_statement_node_index = try ast_node_array.alloc();

    if (lexer.peek()) |peek_token| {
        if (peek_token.kind == .keyword_continue) {
            _ = lexer.next();
        } else {
            ast_node_array.free(continue_statement_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'continue'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(continue_statement_node_index) catch unreachable;
        return null;
    }

    const target_token: ?Token = lexer.peek();
    if (target_token) |_target_token| {
        if (_target_token.kind == .identifier) {
            _ = lexer.next();
            if (try parseExpression(ast_node_array, lexer, error_report_array)) |expression| {
                if (lexer.peek()) |peek_token| {
                    if (peek_token.kind != .semicolon) {
                        // XXX Error
                        try error_report_array.addUnexpectedTokenReport("';'", .toRange(peek_token), .toPosition(peek_token));

                        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
                        releaseASTNode(ast_node_array, expression);
                        ast_node_array.free(continue_statement_node_index) catch unreachable;
                        return null;
                    } else {
                        _ = lexer.next();
                    }
                } else {
                    // XXX Error
                    try error_report_array.addExpectedTokenReport("';'", .toPosition(lexer.current()));

                    lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
                    releaseASTNode(ast_node_array, expression);
                    ast_node_array.free(continue_statement_node_index) catch unreachable;
                    return null;
                }

                const continue_statement_node = ASTNode{
                    .data = .{
                        .continue_statement = .{
                            .expression = expression,
                            .name = .{
                                .start = _target_token.start,
                                .end = _target_token.end,
                            },
                        },
                    },
                    .kind = .continue_statement,
                };
                ast_node_array.set(continue_statement_node_index, continue_statement_node) catch unreachable;
                return continue_statement_node_index;
            } else {
                // XXX Error
                try error_report_array.addExpectedExpressionReport(.toPosition(lexer.current()));

                lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
                ast_node_array.free(continue_statement_node_index) catch unreachable;
                return null;
            }
        } else {
            // XXX Error
            try error_report_array.addUnexpectedTokenReport("Identifier", .toRange(_target_token), .toPosition(_target_token));

            lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
            ast_node_array.free(continue_statement_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        try error_report_array.addExpectedTokenReport("'continue'", .toPosition(lexer.current()));

        lexer.skipUntil(&[_]Lexer.Token.Kind{.semicolon});
        ast_node_array.free(continue_statement_node_index) catch unreachable;
        return null;
    }
}
