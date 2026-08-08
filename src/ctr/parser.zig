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

pub const Parser = @This();

const State = enum {
    root,
    assignment,
    expression,
    type,
    function,
    expect_identifier,
    expect_expression,
    expect_equal,
    expect_access_attribute,
    assignment_multi_check,
    fill_assignment,
    fill_assignment_multi,
    fill_expression,
    fill_type,
    fill_function,
};

pub const ASTNode = struct {
    pub const Kind = enum {
        comment,
        assignment,
        expression,
    };

    const Comment = struct {
        start: u32,
        end: u32,
        next: usize,
    };

    const Assignment = struct {
        const Attribute = enum {
            in,
            inout,
            out,
        };

        const Name = struct {
            start: u32,
            end: u32,
        };

        attribute: Attribute,
        name: Name,
        value: usize,
    };

    const Expression = struct {};

    kind: Kind,
    data: union {
        comment: Comment,
        assignment: Assignment,
        expression: Expression,
    },
};
pub const ASTNodeArray = aslib.array.StableIndexArray(ASTNode);
const ASTNodeStack = aslib.stack.TypedStackUnmanaged(usize);
const StateStack = aslib.stack.TypedStackUnmanaged(State);
const TokenStack = aslib.stack.TypedStackUnmanaged(Token);

const Config = struct {
    ast_node_stack_size: u32,
    state_stack_size: u32,
    token_stack_size: u32,
};

ast_node_array: *ASTNodeArray,
ast_node_stack: ASTNodeStack,
state_stack: StateStack,
token_stack: TokenStack,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, config: Config, ast_node_array: *ASTNodeArray) error{ OutOfMemory, OutOfCapacity }!Parser {
    var ast_node_stack = try ASTNodeStack.init(allocator, config.ast_node_stack_size);
    errdefer ast_node_stack.deinit(allocator);

    var state_stack = try StateStack.init(allocator, config.state_stack_size);
    errdefer state_stack.deinit(allocator);

    var token_stack = try TokenStack.init(allocator, config.token_stack_size);
    errdefer token_stack.deinit(allocator);

    try state_stack.push(State.root);

    return Parser{
        .ast_node_array = ast_node_array,
        .ast_node_stack = ast_node_stack,
        .state_stack = state_stack,
        .token_stack = token_stack,
        .allocator = allocator,
    };
}

pub fn deinit(parser: *Parser) void {
    parser.ast_node_stack.deinit(parser.allocator);
    parser.state_stack.deinit(parser.allocator);
    parser.token_stack.deinit(parser.allocator);
    parser.* = Parser{
        .allocator = undefined,
        .ast_node_array = undefined,
        .ast_node_stack = undefined,
        .state_stack = undefined,
        .token_stack = undefined,
    };
}

pub fn parse(parser: *Parser, lexer: *Lexer) error{OutOfCapacity}!u32 {
    var error_count: u32 = 0;

    var state: State = undefined;
    while (true) {
        if (parser.state_stack.pop()) |next_state| {
            state = next_state;
        } else {
            break;
        }

        switch (state) {
            .root => {
                // .root expect Token.comment, Token.keyword_in, Token.keyword_out, Token.keyword_inout, Token.keyword_function, Token.macro
                const unknown_token = lexer.peek();
                if (unknown_token) |token| {
                    switch (token.kind) {
                        .comment => {
                            const node_index = try parser.ast_node_array.alloc();
                            const node = ASTNode{
                                .kind = .comment,
                                .data = .{
                                    .comment = .{
                                        .next = undefined,
                                        .start = token.start,
                                        .end = token.end,
                                    },
                                },
                            };

                            parser.ast_node_array.set(node_index, node) catch unreachable;
                            errdefer parser.ast_node_array.free(node_index);

                            try parser.ast_node_stack.push(node_index);

                            try parser.state_stack.push(State.root);
                        },
                        .keyword_in, .keyword_inout, .keyword_out => {
                            try parser.state_stack.push(State.root);
                            try parser.state_stack.push(State.assignment);
                        },
                    }
                }
            },
            .assignment => {
                try parser.state_stack.push(State.fill_assignment);
                try parser.state_stack.push(State.expect_expression);
                try parser.state_stack.push(State.expect_equal);
                try parser.state_stack.push(State.assignment_multi_check);
                try parser.state_stack.push(State.expect_identifier);
                try parser.state_stack.push(State.expect_access_attribute);
            },
            .expect_identifier => {
                const unknown_token = lexer.peek();
                if (unknown_token) |token| {
                    if (token.kind != .identifier) {
                        error_count += 1;
                        aslib.log.err("Unexpected Token: {any}", .{token.kind});
                    } else {
                        try parser.token_stack.push(token);
                        _ = lexer.next();
                    }
                }
            },
            .expect_equal => {
                const unknown_token = lexer.peek();
                if (unknown_token) |token| {
                    if (token.kind != .equal) {
                        error_count += 1;
                        aslib.log.err("Unexpected Token: {any}", .{token.kind});
                    } else {
                        _ = lexer.next();
                    }
                    // May cause codes without "=" passing parser
                }
            },
            .expect_expression => {
                const token = lexer.next();
                switch (token.kind) {
                    .keyword_type => {},
                    .keyword_function => {},
                    .identifier => {},
                }
            },
            .expect_access_attribute => {
                const unknown_token = lexer.peek();
                if (unknown_token) |token| {
                    if (token.kind != .keyword_in and token.kind != .keyword_inout and token.kind != .keyword_out) {
                        error_count += 1;
                        aslib.log.err("Unexpected Token: {any}", .{token.kind});
                    } else {
                        try parser.token_stack.push(token);
                        _ = lexer.next();
                    }
                }
            },
            .assignment_multi_check => {
                const unknown_token = lexer.peek();
                if (unknown_token) |token| {
                    if (token.kind == .comma or token.kind == .identifier) {
                        // Check .identifier if input lost .comma
                        if (token.kind == .identifier) {
                            error_count += 1;
                        }

                        _ = parser.state_stack.pop(); // .expect_equal
                        _ = parser.state_stack.pop(); // .expect_expression
                        _ = parser.state_stack.pop(); // .fill_assignment(_multi)

                        try parser.state_stack.push(State.fill_assignment_multi);
                        try parser.state_stack.push(State.expect_expression);
                        try parser.state_stack.push(State.expect_equal);
                        try parser.state_stack.push(State.assignment_multi_check);
                        try parser.state_stack.push(State.expect_identifier);
                        try parser.state_stack.push(State.expect_access_attribute);
                    }
                }
            },
            .fill_assignment => {
                const unknown_value_node_index: ?usize = parser.ast_node_stack.peek();
                if (unknown_value_node_index) |value_node_index| {
                    const value_node = parser.ast_node_array.get(value_node_index) catch unreachable;
                    if (value_node.kind != .expression) {
                        error_count += 1;
                        aslib.log.err("Unexpected Node: {any}", .{value_node.kind});
                    } else {
                        const unknown_identifier_token: ?Token = parser.token_stack.peek();
                        if (unknown_identifier_token) |identifier_token| {
                            if (identifier_token.kind != .identifier) {
                                aslib.log.err("Unexpected Token: {any}", .{identifier_token.kind});
                            } else {
                                _ = parser.ast_node_stack.pop();
                                _ = parser.token_stack.pop();

                                const node_index = try parser.ast_node_array.alloc();
                                const node = ASTNode{
                                    .kind = .assignment,
                                    .data = .{
                                        .assignment = .{
                                            .attribute = switch (identifier_token.kind) {
                                                .keyword_in => .in,
                                                .keyword_out => .out,
                                                .keyword_inout => .inout,
                                                else => unreachable,
                                            },
                                            .name = .{
                                                .start = identifier_token.start,
                                                .end = identifier_token.end,
                                            },
                                            .value = value_node_index,
                                        },
                                    },
                                };

                                parser.ast_node_array.set(node_index, node) catch unreachable;
                                errdefer parser.ast_node_array.free(node_index);

                                try parser.ast_node_stack.push(node_index);
                            }
                        }
                    }
                }
            },
            .expression => {},
            .fill_expression => {},
        }
    }

    return error_count;
}
