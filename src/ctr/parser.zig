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
const Token = Lexer.Token;

pub const ASTNode = struct {
    pub const Kind = enum {
        root,
        label_expression,
        block_expression,
        statement,
        assignment_statement,
        expression,
        call_expression,
        call_statement,
        call_parameter,
        type_expression,
        type_entry,
        function_expression,
        function_parameter,
        match_expression,
        match_case,
        break_statement,
        continue_statement,
        literal_expression,
        assignment_target,
    };

    const Root = struct {
        containor: usize,
    };

    const AssignmentTarget = struct {
        const Name = struct {
            start: usize,
            end: usize,
        };
        const AccessAttribute = enum {
            in,
            out,
            inout,
        };
        access_attribute: AccessAttribute,
        name: Name,
        next: ?usize,
    };

    const AssignmentStatement = struct {
        target: usize,
        expression: usize,
    };

    const CallStatement = struct {
        call_expression: usize,
    };

    const CallExpression = struct {
        target: usize,
        parameter: ?usize,
    };

    const CallParameter = struct {
        expression: usize,
        next: ?usize,
    };

    const BlockExpression = struct {
        statement: ?usize,
        expression: usize,
    };

    const LiteralExpression = struct {
        const LiteralKind = enum {
            string,
            char,
            integer,
            float,
            identifier,
        };

        const Position = struct {
            start: usize,
            end: usize,
        };

        kind: LiteralKind,
        position: Position,
    };

    const TypeExpression = struct {
        kind: usize,
        entry: ?usize,
    };

    const TypeEntry = struct {
        const Name = struct {
            start: usize,
            end: usize,
        };

        name: Name,
        expression: ?usize,
        next: ?usize,
    };

    const Statement = struct {
        const StatementKind = enum {
            assignment,
            call,
            @"break",
            @"continue",
        };

        kind: StatementKind,
        statement: usize,
        next: ?usize,
    };

    const Expression = struct {
        const ExpressionKind = enum {
            call,
            function,
            type,
            block,
            match,
            literal,
            label,
        };

        kind: ExpressionKind,
        expression: usize,
    };

    const FunctionExpression = struct {
        parameter: ?usize,
        expression: ?usize,
    };

    const FunctionParameter = struct {
        const Name = struct {
            start: usize,
            end: usize,
        };
        const AccessAttribute = enum {
            in,
            out,
            inout,
        };

        access_attribute: AccessAttribute,
        name: Name,
        expression: usize,
        next: ?usize,
    };

    const LabelExpression = struct {
        label: usize,
        expression: usize,
    };

    const BreakStatement = struct {
        const Name = struct {
            start: usize,
            end: usize,
        };
        name: Name,
        expression: usize,
    };

    const ContinueStatement = struct {
        const Name = struct {
            start: usize,
            end: usize,
        };
        name: Name,
        expression: usize,
    };

    const MatchExpression = struct {
        expression: usize,
        case: ?usize,
    };

    const MatchCase = struct {
        expression: usize, // Use label expression
        next: ?usize,
    };

    kind: Kind,
    data: union {
        root: Root,
        label_expression: LabelExpression,
        block_expression: BlockExpression,
        statement: Statement,
        assignment_statement: AssignmentStatement,
        assignment_target: AssignmentTarget,
        break_statement: BreakStatement,
        continue_statement: ContinueStatement,
        call_statement: CallStatement,
        call_expression: CallExpression,
        call_parameter: CallParameter,
        expression: Expression,
        type_expression: TypeExpression,
        type_entry: TypeEntry,
        literal_expression: LiteralExpression,
        function_expression: FunctionExpression,
        function_parameter: FunctionParameter,
        match_expression: MatchExpression,
        match_case: MatchCase,
    },
};

pub const ASTNodeArray = aslib.array.StableIndexArray(ASTNode);

fn releaseASTNode(ast_node_array: *ASTNodeArray, node_index: usize) void {
    _ = ast_node_array;
    _ = node_index;
}

pub fn parseRoot(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Root at {d}:{d}", .{ lexer.line, lexer.pos });
    const ast_node_index = try ast_node_array.alloc();

    const containor_node_index = try parseBlockExpressionContent(ast_node_array, lexer);
    if (containor_node_index) |_containor_node_index| {
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

        ast_node_array.free(ast_node_index) catch unreachable;
        return null;
    }
}

fn parseBlockExpression(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Block Expression at {d}:{d}", .{ lexer.line, lexer.pos });
    const lbracket_token = lexer.next();
    if (lbracket_token.kind == .l_brace) {
        const context_node = try parseBlockExpressionContent(ast_node_array, lexer);
        if (context_node) |_context_node| {
            const rbracket_token = lexer.next();
            if (rbracket_token.kind == .r_brace) {
                return _context_node;
            }
        }
    }

    // XXX Error
    return null;
}

fn parseBlockExpressionContent(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing BlockExpressionContent at {d}:{d}", .{ lexer.line, lexer.pos });
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
    while (try parseStatement(ast_node_array, lexer)) |statement_node_index| {
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

    if (try parseExpression(ast_node_array, lexer)) |expression_node_index| {
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
        ast_node_array.free(ast_node_index) catch unreachable;
        if (first_statement_node_index) |_first_statement_node_index| {
            releaseASTNode(ast_node_array, _first_statement_node_index);
        }
        return null;
    }

    return null;
}

fn parseStatement(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Statement at {d}:{d}", .{ lexer.line, lexer.pos });
    const statement_node_index = try ast_node_array.alloc();
    const previous_lexer = lexer.*;

    if (try parseAssignmentStatement(ast_node_array, lexer)) |assignment_node_index| {
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

        ast_node_array.set(statement_node_index, statement_node) catch unreachable;
        return statement_node_index;
    } else {
        lexer.* = previous_lexer;
    }

    if (try parseCallStatement(ast_node_array, lexer)) |call_node_index| {
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

        ast_node_array.set(statement_node_index, statement_node) catch unreachable;
        return statement_node_index;
    } else {
        lexer.* = previous_lexer;
    }

    if (try parseBreakStatement(ast_node_array, lexer)) |break_node_index| {
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

        ast_node_array.set(statement_node_index, statement_node) catch unreachable;
        return statement_node_index;
    } else {
        lexer.* = previous_lexer;
    }

    if (try parseContinueStatement(ast_node_array, lexer)) |continue_node_index| {
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

        ast_node_array.set(statement_node_index, statement_node) catch unreachable;
        return statement_node_index;
    } else {
        lexer.* = previous_lexer;
    }

    // XXX Error
    ast_node_array.free(statement_node_index) catch unreachable;
    return null;
}

fn parseAssignmentStatement(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Assignment Statement at {d}:{d}", .{ lexer.line, lexer.pos });
    const assignment_node_index = try ast_node_array.alloc();

    var first_target_node_index: ?usize = null;
    var current_target_node_index: ?usize = null;
    while (try parseAssignmentTarget(ast_node_array, lexer)) |target_node_index| {
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

            if (first_target_node_index) |_first_target_node_index| {
                releaseASTNode(ast_node_array, _first_target_node_index);
            }
            ast_node_array.free(assignment_node_index) catch unreachable;
            return null;
        }
    }

    if (first_target_node_index == null) {
        // XXX Error
        ast_node_array.free(assignment_node_index) catch unreachable;
        return null;
    }

    const equal_token = lexer.peek();
    if (equal_token) |_equal_token| {
        if (_equal_token.kind != .equal) {
            // XXX Error
        }

        _ = lexer.next();
    }

    var expression_node_index: ?usize = null;
    if (try parseExpression(ast_node_array, lexer)) |_expression_node_index| {
        expression_node_index = _expression_node_index;
    } else {
        // XXX Error
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
        }
    }

    // XXX Error
    if (first_target_node_index) |_first_target_node_index| {
        releaseASTNode(ast_node_array, _first_target_node_index);
    }
    if (expression_node_index) |_expression_node_index| {
        releaseASTNode(ast_node_array, _expression_node_index);
    }
    ast_node_array.free(assignment_node_index) catch unreachable;
    return null;
}

fn parseAssignmentTarget(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Assignment Target at {d}:{d}", .{ lexer.line, lexer.pos });
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
                }
            }
        }
    }

    // XXX Error
    ast_node_array.free(assignment_target_node_index) catch unreachable;
    return null;
}

fn parseCallStatement(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Call Statement at {d}:{d}", .{ lexer.line, lexer.pos });
    const call_statement_node_index = try ast_node_array.alloc();

    if (try parseCallExpression(ast_node_array, lexer)) |call_expression_node_index| {
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
            }
        }
    }

    ast_node_array.free(call_statement_node_index) catch unreachable;
    return null;
}

fn parseCallExpression(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Call Expression at {d}:{d}", .{ lexer.line, lexer.pos });
    const call_expression_node_index = try ast_node_array.alloc();

    if (try parseLiteralExpression(ast_node_array, lexer)) |target_node_index| {
        var first_call_parameter_node_index: ?usize = null;
        var current_call_parameter_node_index: ?usize = null;
        var peek_token: ?Token = null;

        peek_token = lexer.peek();
        if (peek_token) |_peek_token| {
            if (_peek_token.kind != .l_paren) {
                // XXX Error
                // And more
                return null;
            } else {
                _ = lexer.next();
            }
        }

        while (try parseCallParameter(ast_node_array, lexer)) |call_parameter_node_index| {
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
                if (_peek_token.kind != .comma) {
                    break;
                } else {
                    _ = lexer.next();
                }
            }
        }
        peek_token = lexer.peek();
        if (peek_token) |_peek_token| {
            if (_peek_token.kind != .r_paren) {
                // XXX Error
                // And more
                return null;
            } else {
                _ = lexer.next();
            }
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
    }

    ast_node_array.free(call_expression_node_index) catch unreachable;
    return null;
}

fn parseCallParameter(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Call Parameter at {d}:{d}", .{ lexer.line, lexer.pos });
    const call_parameter_node_index = try ast_node_array.alloc();

    if (try parseExpression(ast_node_array, lexer)) |expression_node_index| {
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

    // XXX Error
    return null;
}

fn parseExpression(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Expression at {d}:{d}", .{ lexer.line, lexer.pos });
    const expression_node_index = try ast_node_array.alloc();
    const previous_lexer = lexer.*;

    if (try parseLabelExpression(ast_node_array, lexer)) |label_expression_index| {
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

    if (try parseMatchExpression(ast_node_array, lexer)) |match_expression_index| {
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

    if (try parseCallExpression(ast_node_array, lexer)) |call_expression_index| {
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

    if (try parseLiteralExpression(ast_node_array, lexer)) |literal_expression_index| {
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

    if (try parseTypeExpression(ast_node_array, lexer)) |type_expression_index| {
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

    if (try parseFunctionExpression(ast_node_array, lexer)) |function_expression_index| {
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

    if (try parseBlockExpression(ast_node_array, lexer)) |block_expression_index| {
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

    // XXX Error
    ast_node_array.free(expression_node_index) catch unreachable;
    return null;
}

fn parseLiteralExpression(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Literal Expression at {d}:{d}", .{ lexer.line, lexer.pos });
    const literal_expression_node_index = try ast_node_array.alloc();

    const peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        // lexer.dump(&_peek_token);
        if (_peek_token.kind == .string or _peek_token.kind == .char or _peek_token.kind == .identifier or _peek_token.kind == .integer or _peek_token.kind == .float) {
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
        }
    }

    ast_node_array.free(literal_expression_node_index) catch unreachable;
    return null;
}

fn parseTypeExpression(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Type Expression at {d}:{d}", .{ lexer.line, lexer.pos });
    const type_expression_node_index = try ast_node_array.alloc();

    var peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_type) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(type_expression_node_index) catch unreachable;
            return null;
        }
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(type_expression_node_index) catch unreachable;
            return null;
        }
    }

    var expression_node_index: ?usize = null;
    if (try parseExpression(ast_node_array, lexer)) |_expression_node_index| {
        expression_node_index = _expression_node_index;
    } else {
        // XXX Error
        ast_node_array.free(type_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.next();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(type_expression_node_index) catch unreachable;
            return null;
        }
    }

    peek_token = lexer.next();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_bracket) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(type_expression_node_index) catch unreachable;
            return null;
        }
    }

    var first_type_entry_node_index: ?usize = null;
    var current_type_entry_node_index: ?usize = null;

    while (try parseTypeEntry(ast_node_array, lexer)) |type_entry_node_index| {
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
            if (_peek_token.kind != .comma) {
                break;
            } else {
                _ = lexer.next();
            }
        }
    }

    peek_token = lexer.next();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_bracket) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(type_expression_node_index) catch unreachable;
            if (first_type_entry_node_index) |_first_type_entry_node_index| {
                releaseASTNode(ast_node_array, _first_type_entry_node_index);
            }
            return null;
        }
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

fn parseTypeEntry(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Type Entry at {d}:{d}", .{ lexer.line, lexer.pos });
    const type_entry_node_index = try ast_node_array.alloc();

    var name_token: Token = undefined;
    var peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .identifier) {
            name_token = _peek_token;
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(type_entry_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(type_entry_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .colon) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(type_entry_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(type_entry_node_index) catch unreachable;
        return null;
    }

    var expression_node_index: ?usize = undefined;
    if (try parseExpression(ast_node_array, lexer)) |_expression_node_index| {
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

fn parseFunctionParameter(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Function Parameter at {d}:{d}", .{ lexer.line, lexer.pos });
    const function_parameter_node_index = try ast_node_array.alloc();

    var peek_token = lexer.peek();
    var attribute_token: Token = undefined;
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_in or _peek_token.kind == .keyword_inout or _peek_token.kind == .keyword_out) {
            attribute_token = _peek_token;
        } else {
            // XXX Error
            ast_node_array.free(function_parameter_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(function_parameter_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    var name_token: Token = undefined;
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .identifier) {
            name_token = _peek_token;
        } else {
            // XXX Error
            ast_node_array.free(function_parameter_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(function_parameter_node_index) catch unreachable;
        return null;
    }

    if (try parseExpression(ast_node_array, lexer)) |expression_node_index| {
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
    }

    // XXX Error
    ast_node_array.free(function_parameter_node_index) catch unreachable;
    return null;
}

fn parseFunctionExpression(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Function Expression at {d}:{d}", .{ lexer.line, lexer.pos });
    const function_expression_node_index = try ast_node_array.alloc();

    var peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_function) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(function_expression_node_index) catch unreachable;
            return null;
        }
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(function_expression_node_index) catch unreachable;
            return null;
        }
    }

    var first_function_parameter_node_index: ?usize = null;
    var current_function_parameter_node_index: ?usize = null;

    while (try parseFunctionParameter(ast_node_array, lexer)) |function_parameter_node_index| {
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
            if (_peek_token.kind != .comma) {
                break;
            } else {
                _ = lexer.next();
            }
        }
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(function_expression_node_index) catch unreachable;
            if (first_function_parameter_node_index) |_first_function_parameter_node_index| {
                releaseASTNode(ast_node_array, _first_function_parameter_node_index);
            }
            return null;
        }
    }

    const expression = try parseExpression(ast_node_array, lexer);

    const function_expression_node = ASTNode{
        .data = .{
            .function_expression = .{
                .expression = expression,
                .parameter = first_function_parameter_node_index,
            },
        },
        .kind = .function_expression,
    };

    ast_node_array.set(function_expression_node_index, function_expression_node) catch unreachable;
    return function_expression_node_index;
}

fn parseLabelExpression(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Label Expression at {d}:{d}", .{ lexer.line, lexer.pos });
    const label_expression_node_index = try ast_node_array.alloc();

    var label_expression: usize = undefined;
    if (try parseLiteralExpression(ast_node_array, lexer)) |_label_expression| {
        label_expression = _label_expression;
    } else {
        // XXX Error
        ast_node_array.free(label_expression_node_index) catch unreachable;
        return null;
    }

    const peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .colon) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(label_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(label_expression_node_index) catch unreachable;
        return null;
    }

    if (try parseExpression(ast_node_array, lexer)) |expression| {
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
    }

    // XXX Error
    ast_node_array.free(label_expression_node_index) catch unreachable;
    return null;
}

// fn parsePointerExpression(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {}

fn parseMatchExpression(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Match Expression at {d}:{d}", .{ lexer.line, lexer.pos });
    const match_expression_node_index = try ast_node_array.alloc();

    var peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_match) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    var expression: usize = undefined;
    if (try parseExpression(ast_node_array, lexer)) |_expression| {
        expression = _expression;
    } else {

        // XXX Error
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_paren) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .l_brace) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(match_expression_node_index) catch unreachable;
        return null;
    }

    var first_match_case_node_index: ?usize = null;
    var current_match_case_node_index: ?usize = null;
    while (try parseMatchCase(ast_node_array, lexer)) |match_case_node_index| {
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
            if (_peek_token.kind != .comma) {
                break;
            } else {
                _ = lexer.next();
            }
        }
    }

    peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .r_brace) {
            _ = lexer.next();
        } else {
            // XXX Error
            if (first_match_case_node_index) |_first_match_case_node_index| {
                releaseASTNode(ast_node_array, _first_match_case_node_index);
            }
            ast_node_array.free(match_expression_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
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

fn parseMatchCase(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Match Case at {d}:{d}", .{ lexer.line, lexer.pos });
    const match_case_node_index = try ast_node_array.alloc();

    const peek_token = lexer.peek();
    if (peek_token) |_peek_token| {
        if (_peek_token.kind == .keyword_case) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(match_case_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(match_case_node_index) catch unreachable;
        return null;
    }

    if (try parseLabelExpression(ast_node_array, lexer)) |label_expression| {
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
    }

    // XXX Error
    ast_node_array.free(match_case_node_index) catch unreachable;
    return null;
}

fn parseBreakStatement(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Break Statement at {d}:{d}", .{ lexer.line, lexer.pos });
    const break_statement_node_index = try ast_node_array.alloc();

    if (lexer.peek()) |peek_token| {
        if (peek_token.kind == .keyword_break) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(break_statement_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(break_statement_node_index) catch unreachable;
        return null;
    }

    const target_token: ?Token = lexer.peek();
    if (target_token) |_target_token| {
        if (_target_token.kind == .identifier) {
            _ = lexer.next();
            if (try parseExpression(ast_node_array, lexer)) |expression| {
                if (lexer.peek()) |peek_token| {
                    if (peek_token.kind != .semicolon) {
                        // XXX Error
                        releaseASTNode(ast_node_array, expression);
                        ast_node_array.free(break_statement_node_index) catch unreachable;
                        return null;
                    } else {
                        _ = lexer.next();
                    }
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
                ast_node_array.free(break_statement_node_index) catch unreachable;
                return null;
            }
        } else {
            // XXX Error
            ast_node_array.free(break_statement_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(break_statement_node_index) catch unreachable;
        return null;
    }
}

fn parseContinueStatement(ast_node_array: *ASTNodeArray, lexer: *Lexer) error{OutOfCapacity}!?usize {
    std.log.debug("Parsing Continue Statement at {d}:{d}", .{ lexer.line, lexer.pos });
    const continue_statement_node_index = try ast_node_array.alloc();

    if (lexer.peek()) |peek_token| {
        if (peek_token.kind == .keyword_continue) {
            _ = lexer.next();
        } else {
            // XXX Error
            ast_node_array.free(continue_statement_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(continue_statement_node_index) catch unreachable;
        return null;
    }

    const target_token: ?Token = lexer.peek();
    if (target_token) |_target_token| {
        if (_target_token.kind == .identifier) {
            _ = lexer.next();
            if (try parseExpression(ast_node_array, lexer)) |expression| {
                if (lexer.peek()) |peek_token| {
                    if (peek_token.kind != .semicolon) {
                        // XXX Error
                        releaseASTNode(ast_node_array, expression);
                        ast_node_array.free(continue_statement_node_index) catch unreachable;
                        return null;
                    } else {
                        _ = lexer.next();
                    }
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
                ast_node_array.free(continue_statement_node_index) catch unreachable;
                return null;
            }
        } else {
            // XXX Error
            ast_node_array.free(continue_statement_node_index) catch unreachable;
            return null;
        }
    } else {
        // XXX Error
        ast_node_array.free(continue_statement_node_index) catch unreachable;
        return null;
    }
}

pub fn dump(ast_node_array: *ASTNodeArray, source: [:0]const u8, root_node_index: usize, space: u32) error{OutOfRange}!void {
    const indent = 2;
    // @breakpoint();
    const root_node = try ast_node_array.get(root_node_index);

    const printSpace = struct {
        pub fn printSpace(_space: u32) void {
            for (0.._space) |_| {
                std.debug.print(" ", .{});
            }
        }
    }.printSpace;

    printSpace(space);

    // std.debug.print("{d}:{any}", .{ root_node_index, root_node.kind });

    switch (root_node.kind) {
        .assignment_statement => {
            std.debug.print("Assignment Statment:\n", .{});
            try dump(ast_node_array, source, root_node.data.assignment_statement.target, space + indent);
            try dump(ast_node_array, source, root_node.data.assignment_statement.expression, space + indent);
        },
        .assignment_target => {
            std.debug.print("Assignment Target:\n", .{});
            printSpace(space + indent);
            std.debug.print("Access Attribute: {s}\n", .{
                switch (root_node.data.assignment_target.access_attribute) {
                    .in => "in",
                    .inout => "inout",
                    .out => "out",
                },
            });
            printSpace(space + indent);
            std.debug.print("Name: {s}\n", .{source[root_node.data.assignment_target.name.start..root_node.data.assignment_target.name.end]});
            if (root_node.data.assignment_target.next) |next| {
                return try dump(ast_node_array, source, next, space);
            }
        },
        .block_expression => {
            std.debug.print("Block Expression:\n", .{});
            var current_statement = root_node.data.block_expression.statement;
            while (current_statement) |_current_statement| {
                const current_statement_node = try ast_node_array.get(_current_statement);
                try dump(ast_node_array, source, _current_statement, space + indent);
                current_statement = current_statement_node.data.statement.next;
            }
            try dump(ast_node_array, source, root_node.data.block_expression.expression, space + indent);
        },
        .call_expression => {
            std.debug.print("Call Expression:\n", .{});
            printSpace(space + indent);
            std.debug.print("Target:\n", .{});
            try dump(ast_node_array, source, root_node.data.call_expression.target, space + indent * 2);
            var current_parameter = root_node.data.call_expression.parameter;
            while (current_parameter) |_current_parameter| {
                const current_parameter_node = try ast_node_array.get(_current_parameter);
                try dump(ast_node_array, source, _current_parameter, space + indent);
                current_parameter = current_parameter_node.data.call_parameter.next;
            }
        },
        .call_parameter => {
            std.debug.print("Call Parameter:\n", .{});
            try dump(ast_node_array, source, root_node.data.call_parameter.expression, space + indent);
        },
        .call_statement => {
            std.debug.print("Call Statement:\n", .{});
            try dump(ast_node_array, source, root_node.data.call_statement.call_expression, space + indent);
        },
        .expression => {
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, root_node.data.expression.expression, space + indent);
        },
        .literal_expression => {
            std.debug.print("Literal Expression:\n", .{});
            printSpace(space + indent);
            std.debug.print("{s}: {s}\n", .{
                switch (root_node.data.literal_expression.kind) {
                    .char => "char",
                    .float => "float",
                    .identifier => "identifier",
                    .integer => "integer",
                    .string => "string",
                },
                source[root_node.data.literal_expression.position.start..root_node.data.literal_expression.position.end],
            });
        },
        .root => {
            std.debug.print("Root:\n", .{});
            try dump(ast_node_array, source, root_node.data.root.containor, space + indent);
        },
        .statement => {
            std.debug.print("Statement:\n", .{});
            try dump(ast_node_array, source, root_node.data.statement.statement, space + indent);
        },
        .function_expression => {
            std.debug.print("Function Expression:\n", .{});
            var current_parameter = root_node.data.function_expression.parameter;
            while (current_parameter) |_current_parameter| {
                const current_parameter_node = try ast_node_array.get(_current_parameter);
                try dump(ast_node_array, source, _current_parameter, space + indent);
                current_parameter = current_parameter_node.data.function_parameter.next;
            }

            if (root_node.data.function_expression.expression) |expression| {
                try dump(ast_node_array, source, expression, space + indent);
            }
        },
        .function_parameter => {
            std.debug.print("Function Parameter:\n", .{});
            printSpace(space + indent);
            std.debug.print("Access Attribute: {s}\n", .{
                switch (root_node.data.function_parameter.access_attribute) {
                    .in => "in",
                    .inout => "inout",
                    .out => "out",
                },
            });
            printSpace(space + indent);
            std.debug.print("Name: {s}\n", .{source[root_node.data.function_parameter.name.start..root_node.data.function_parameter.name.end]});
            printSpace(space + indent);
            try dump(ast_node_array, source, root_node.data.function_parameter.expression, space + indent * 2);
            if (root_node.data.function_parameter.next) |next| {
                return try dump(ast_node_array, source, next, space);
            }
        },
        .type_entry => {
            std.debug.print("Type Entry:\n", .{});

            printSpace(space + indent);
            std.debug.print("Name: {s}\n", .{source[root_node.data.type_entry.name.start..root_node.data.type_entry.name.end]});

            if (root_node.data.type_entry.expression) |expression| {
                printSpace(space + indent);
                std.debug.print("Expression:\n", .{});
                try dump(ast_node_array, source, expression, space + indent * 2);
            }

            if (root_node.data.type_entry.next) |next| {
                return try dump(ast_node_array, source, next, space);
            }
        },
        .type_expression => {
            std.debug.print("Type Expression:\n", .{});

            printSpace(space + indent);
            std.debug.print("Type Constuctor:\n", .{});
            try dump(ast_node_array, source, root_node.data.type_expression.kind, space + indent * 2);
            if (root_node.data.type_expression.entry) |entry| {
                printSpace(space + indent);
                std.debug.print("Entry:\n", .{});
                try dump(ast_node_array, source, entry, space + indent * 2);
            }
        },
        .break_statement => {
            std.debug.print("Break Statement:\n", .{});

            printSpace(space + indent);
            std.debug.print("Target: {s}\n", .{source[root_node.data.break_statement.name.start..root_node.data.break_statement.name.end]});
            printSpace(space + indent);
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, root_node.data.break_statement.expression, space + indent * 2);
        },
        .continue_statement => {
            std.debug.print("Continue Statement:\n", .{});

            printSpace(space + indent);
            std.debug.print("Target: {s}\n", .{source[root_node.data.continue_statement.name.start..root_node.data.continue_statement.name.end]});
            printSpace(space + indent);
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, root_node.data.continue_statement.expression, space + indent * 2);
        },
        .label_expression => {
            std.debug.print("Label Expression:\n", .{});

            printSpace(space + indent);
            std.debug.print("Label:\n", .{});
            try dump(ast_node_array, source, root_node.data.label_expression.label, space + indent * 2);
            printSpace(space + indent);
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, root_node.data.label_expression.expression, space + indent * 2);
        },
        .match_case => {
            std.debug.print("Match Case:\n", .{});

            const internal_label_expression = try ast_node_array.get(root_node.data.match_case.expression);
            // XXX Don't forget Match Case use Label Expression's internal data!

            printSpace(space + indent);
            std.debug.print("Case:\n", .{});
            try dump(ast_node_array, source, internal_label_expression.data.label_expression.label, space + indent * 2);
            printSpace(space + indent);
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, internal_label_expression.data.label_expression.expression, space + indent * 2);
        },
        .match_expression => {
            std.debug.print("Match Expression:\n", .{});

            printSpace(space + indent);
            std.debug.print("Condition:\n", .{});
            try dump(ast_node_array, source, root_node.data.match_expression.expression, space + indent * 2);

            var current_case_node_index = root_node.data.match_expression.case;
            while (current_case_node_index) |_current_case_node_index| {
                const current_case_node = try ast_node_array.get(_current_case_node_index);
                try dump(ast_node_array, source, _current_case_node_index, space + indent * 2);
                current_case_node_index = current_case_node.data.match_case.next;
            }
        },
    }
}
