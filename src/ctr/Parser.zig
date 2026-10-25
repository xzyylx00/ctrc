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
const Self = @This();
const ASTNode = @import("ASTNode.zig");
const Tokenizer = @import("Tokenizer.zig");
const StringPool = @import("StringPool.zig");
const Error = @import("Error.zig");
const Stack = @import("Stack.zig").Stack;

pub const Element = struct {
    pub const Kind = enum {
        node,
        token,
    };

    const Data = union {
        node: ASTNode.ASTNodeHandle,
        token: Tokenizer.Token,
    };

    kind: Kind,
    data: Data,
};

// Dynamtic Stack
pub const ElementStack = Stack(Element, 1024);
pub const StateStack = Stack(u8, 1024);

state_stack: StateStack,
element_stack: ElementStack,
lock: std.Io.Mutex,
pool: *ASTNode.ASTNodePool,

pub fn init(allocator: std.mem.Allocator, pool: *ASTNode.ASTNodePool) error{OutOfMemory}!Self {
    const element_stack = try ElementStack.init(allocator);
    errdefer element_stack.deinit();

    const state_stack = try StateStack.init(allocator);
    errdefer state_stack.deinit();

    return Self{
        .state_stack = state_stack,
        .element_stack = element_stack,
        .lock = .init,
        .pool = pool,
    };
}

pub fn deinit(self: *Self) void {
    self.state_stack.deinit();
    self.element_stack.deinit();
    self.* = undefined;
}

fn pushToken(self: *Self, token: Tokenizer.Token) error{OutOfMemory}!void {
    const element = Element{
        .kind = .token,
        .data = .{
            .token = token,
        },
    };

    try self.element_stack.push(element);
}

fn pushASTNode(self: *Self, node: ASTNode.ASTNodeHandle) error{OutOfMemory}!void {
    const element = Element{
        .kind = .node,
        .data = .{
            .node = node,
        },
    };

    try self.element_stack.push(element);
}

fn isSyncToken(token: Tokenizer.Token) bool {
    return switch (token.kind) {
        .semicolon, .r_brace, .r_paren, .keyword_case, .eof, .percent => true,
        else => false,
    };
}

fn isShiftable(state: u8, kind: Tokenizer.Token.Kind) bool {
    return switch (state) {
        0,
        1,
        36,
        => switch (kind) {
            .l_brace,
            .l_paren,
            .underline,
            .keyword_match,
            .keyword_function,
            .keyword_type,
            .keyword_in,
            .keyword_out,
            .keyword_inout,
            .keyword_ref,
            .keyword_ptr,
            .keyword_continue,
            .keyword_break,
            .keyword_runtime,
            .identifier,
            .string,
            .integer,
            .float,
            .char,
            .macro,
            .keyword_nil,
            => true,
            else => false,
        },
        2,
        44,
        52,
        53,
        55,
        56,
        57,
        58,
        61,
        62,
        67,
        87,
        111,
        114,
        115,
        116,
        133,
        => switch (kind) {
            .l_brace,
            .l_paren,
            .keyword_match,
            .keyword_function,
            .keyword_type,
            .keyword_in,
            .keyword_out,
            .keyword_inout,
            .keyword_ref,
            .keyword_ptr,
            .keyword_runtime,
            .identifier,
            .string,
            .integer,
            .float,
            .char,
            .macro,
            .keyword_nil,
            => true,
            else => false,
        },
        4,
        5,
        6,
        14,
        24,
        103,
        104,
        => switch (kind) {
            .l_paren => true,
            else => false,
        },
        12,
        13,
        64,
        76,
        110,
        => switch (kind) {
            .identifier => true,
            else => false,
        },
        15,
        68,
        92,
        119,
        122,
        => switch (kind) {
            .colon => true,
            else => false,
        },
        22 => switch (kind) {
            .eof => true,
            else => false,
        },
        23,
        65,
        127,
        => switch (kind) {
            .comma => true,
            else => false,
        },
        31,
        82,
        129,
        => switch (kind) {
            .semicolon => true,
            else => false,
        },
        34,
        51,
        => switch (kind) {
            .dot => true,
            else => false,
        },
        40 => switch (kind) {
            .equal => true,
            else => false,
        },
        45 => switch (kind) {
            .keyword_in,
            .keyword_out,
            .keyword_inout,
            .keyword_ref,
            .keyword_ptr,
            => true,
            else => false,
        },
        47 => switch (kind) {
            .r_brace => true,
            else => false,
        },
        49,
        74,
        84,
        125,
        126,
        => switch (kind) {
            .comma,
            .r_paren,
            => true,
            else => false,
        },
        54, 90 => switch (kind) {
            .keyword_in,
            .keyword_out,
            .keyword_inout,
            => true,
            else => false,
        },
        59 => switch (kind) {
            .semicolon,
            .keyword_match,
            => true,
            else => false,
        },
        73,
        77,
        80,
        => switch (kind) {
            .r_paren => true,
            else => false,
        },
        78,
        79,
        86,
        137,
        => switch (kind) {
            .comma,
            .semicolon,
            => true,
            else => false,
        },
        89 => switch (kind) {
            .l_brace => true,
            else => false,
        },
        91 => switch (kind) {
            .keyword_external,
            .keyword_internal,
            => true,
            else => false,
        },
        93 => switch (kind) {
            .l_brace => true,
            else => false,
        },
        101 => switch (kind) {
            .keyword_case => true,
            else => false,
        },
        105 => switch (kind) {
            .keyword_external,
            .keyword_internal,
            .colon,
            => true,
            else => false,
        },
        112 => switch (kind) {
            .r_brace,
            .keyword_case,
            => true,
            else => false,
        },
        118 => switch (kind) {
            .percent => true,
            else => false,
        },
        120 => switch (kind) {
            .r_brace,
            .identifier,
            => true,
            else => false,
        },
        else => return false,
    };
}

fn skipUntilAcceptable(self: *Self, tokens: []Tokenizer.Token, index: usize) error{ParseFailed}!usize {
    while (tokens[index].kind != .eof and !isSyncToken(tokens[index])) : (index += 1) {}

    // if (tokens[index].kind == .eof) {
    //      Handle this
    // }

    while (self.state_stack.count() != 0) {
        if (isShiftable(self.state_stack.top() orelse 255, tokens[index].kind)) {
            return index;
        } else {
            _ = self.state_stack.pop();
            _ = self.element_stack.pop();
        }
    }

    return error.ParseFailed;
}

fn getReduceGoto(state: u32, node_kind: ASTNode.Kind) u8 {
    switch (state) {
        0 => {
            return switch (node_kind) {
                .module => 22,
                .expressions => 23,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .block_body => 28,
                .match_expression => 29,
                .function => 30,
                .call => 31,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 34,
                .type => 35,
                .statements => 36,
                .statement => 37,
                .call_statement => 38,
                .assignment_statement => 39,
                .assignment_target => 40,
                .continue_statement => 41,
                .break_statement => 42,
                .label_statement => 43,
                .access_attribute => 44,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        1 => {
            return switch (node_kind) {
                .expressions => 23,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .block_body => 47,
                .match_expression => 29,
                .function => 30,
                .call => 31,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 34,
                .type => 35,
                .statements => 36,
                .statement => 37,
                .call_statement => 38,
                .assignment_statement => 39,
                .assignment_target => 40,
                .continue_statement => 41,
                .break_statement => 42,
                .label_statement => 43,
                .access_attribute => 44,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        2 => {
            return switch (node_kind) {
                .expressions => 49,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        36 => {
            return switch (node_kind) {
                .expressions => 65,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 31,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 34,
                .type => 35,
                .statement => 66,
                .call_statement => 38,
                .assignment_statement => 39,
                .assignment_target => 40,
                .continue_statement => 41,
                .break_statement => 42,
                .label_statement => 43,
                .access_attribute => 44,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        44, 52 => {
            return switch (node_kind) {
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 69,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        45 => {
            return switch (node_kind) {
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 70,
                else => unreachable,
            };
        },
        53 => {
            return switch (node_kind) {
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 73,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        54 => {
            return switch (node_kind) {
                .function_parameters => 74,
                .function_parameter => 75,
                .access_attribute => 76,
                else => unreachable,
            };
        },
        55 => {
            return switch (node_kind) {
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 77,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        56 => {
            return switch (node_kind) {
                .expressions => 78,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        57 => {
            return switch (node_kind) {
                .expressions => 79,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        58 => {
            return switch (node_kind) {
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 80,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        59 => {
            return switch (node_kind) {
                .match_expression => 82,
                else => unreachable,
            };
        },
        61 => {
            return switch (node_kind) {
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 83,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        62 => {
            return switch (node_kind) {
                .expressions => 84,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        67 => {
            return switch (node_kind) {
                .expressions => 86,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        68 => {
            return switch (node_kind) {
                .type_attribute => 88,
                else => unreachable,
            };
        },
        87 => {
            return switch (node_kind) {
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 100,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        90 => {
            return switch (node_kind) {
                .function_parameter => 102,
                .access_attribute => 76,
                else => unreachable,
            };
        },
        91 => {
            return switch (node_kind) {
                .function_attributes => 105,
                .function_attribute => 106,
                .function_external_attribute => 107,
                .function_internal_attribute => 108,
                else => unreachable,
            };
        },
        92 => {
            return switch (node_kind) {
                .type_attribute => 109,
                else => unreachable,
            };
        },
        101 => {
            return switch (node_kind) {
                .match_cases => 112,
                .match_case => 113,
                else => unreachable,
            };
        },
        105 => {
            return switch (node_kind) {
                .function_attribute => 117,
                .function_external_attribute => 107,
                .function_internal_attribute => 108,
                .function_body => 118,
                else => unreachable,
            };
        },
        110 => {
            return switch (node_kind) {
                .type_entries => 120,
                .type_entry => 121,
                else => unreachable,
            };
        },
        111 => {
            return switch (node_kind) {
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 122,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        112 => {
            return switch (node_kind) {
                .match_case => 124,
                else => unreachable,
            };
        },
        114 => {
            return switch (node_kind) {
                .expressions => 125,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        115 => {
            return switch (node_kind) {
                .expressions => 126,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        116 => {
            return switch (node_kind) {
                .expressions => 127,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        119 => {
            return switch (node_kind) {
                .type_attribute_optional => 129,
                .type_attribute => 130,
                else => unreachable,
            };
        },
        120 => {
            return switch (node_kind) {
                .type_entry => 132,
                else => unreachable,
            };
        },
        133 => {
            return switch (node_kind) {
                .expressions => 137,
                .non_attributed_expression => 24,
                .wrapped_expressions => 25,
                .expression => 26,
                .block => 27,
                .match_expression => 29,
                .function => 30,
                .call => 50,
                .runtime_expression => 32,
                .literal => 33,
                .identifier => 51,
                .type => 35,
                .access_attribute => 52,
                .pointer_attribute => 45,
                .attributed_expression => 46,
                else => unreachable,
            };
        },
        else => unreachable,
    }
}

pub fn parse(self: *Self, io: std.Io, reporter: *Error.Reporter, filename: u32, tokens: []Tokenizer.Token, string_pool: *StringPool, source: [:0]u8) error{ OutOfMemory, ParseFailed }!ASTNode.ASTNodeHandle {
    self.lock.lock(io) catch unreachable;
    defer self.lock.unlock(io);

    if (self.state_stack.count() != 0) {
        try reporter.add(io, .@"error", filename, 1, 1, "Cannot parse! Initial state stack is not empty!", .{});
        return error.ParseFailed;
    }

    if (tokens.len == 0 or tokens[tokens.len - 1].kind != .eof) {
        try reporter.add(io, .@"error", filename, 1, 1, "Cannot parse! Invalid token array!", .{});
        return error.ParseFailed;
    }

    if (self.element_stack.count() != 0) {
        try reporter.add(io, .@"error", filename, 1, 1, "Cannot parse! Not empty element stack!", .{});
        return error.ParseFailed;
    }

    defer self.state_stack.clear();
    defer self.element_stack.clear();

    try self.state_stack.push(0);

    var index: usize = 0;

    while (true) {
        switch (self.state_stack.top() orelse 255) {
            0, 1, 36 => {
                switch (tokens[index].kind) {
                    .l_brace => {
                        try self.state_stack.push(1);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .l_paren => {
                        try self.state_stack.push(2);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .underline => {
                        try self.state_stack.push(3);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_match => {
                        try self.state_stack.push(4);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_function => {
                        try self.state_stack.push(5);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_type => {
                        try self.state_stack.push(6);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_in => {
                        try self.state_stack.push(7);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_out => {
                        try self.state_stack.push(8);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_inout => {
                        try self.state_stack.push(9);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_ref => {
                        try self.state_stack.push(10);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_ptr => {
                        try self.state_stack.push(11);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_continue => {
                        try self.state_stack.push(12);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_break => {
                        try self.state_stack.push(13);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_runtime => {
                        try self.state_stack.push(14);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .identifier => {
                        try self.state_stack.push(15);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .string => {
                        try self.state_stack.push(16);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .integer => {
                        try self.state_stack.push(17);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .float => {
                        try self.state_stack.push(18);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .char => {
                        try self.state_stack.push(19);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .macro => {
                        try self.state_stack.push(20);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_nil => {
                        try self.state_stack.push(21);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            2,
            52,
            53,
            55,
            56,
            57,
            58,
            61,
            62,
            67,
            87,
            111,
            114,
            115,
            116,
            133,
            => {
                switch (tokens[index].kind) {
                    .l_brace => {
                        try self.state_stack.push(1);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .l_paren => {
                        try self.state_stack.push(2);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_match => {
                        try self.state_stack.push(4);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_function => {
                        try self.state_stack.push(5);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_type => {
                        try self.state_stack.push(6);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_in => {
                        try self.state_stack.push(7);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_out => {
                        try self.state_stack.push(8);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_inout => {
                        try self.state_stack.push(9);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_ref => {
                        try self.state_stack.push(10);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_ptr => {
                        try self.state_stack.push(11);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_runtime => {
                        try self.state_stack.push(14);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .identifier => {
                        try self.state_stack.push(48);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .string => {
                        try self.state_stack.push(16);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .integer => {
                        try self.state_stack.push(17);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .float => {
                        try self.state_stack.push(18);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .char => {
                        try self.state_stack.push(19);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .macro => {
                        try self.state_stack.push(20);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .keyword_nil => {
                        try self.state_stack.push(21);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            3 => {
                // Reduce _ assignment target
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .assignment_target,
                    .data = .{
                        .assignment_target = .{
                            .access = null,
                            .attribute = null,
                            .name = try string_pool.put("_"),
                            .kind = .literal,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .assignment_target));
            },
            4 => {
                switch (tokens[index].kind) {
                    .l_paren => {
                        try self.state_stack.push(53);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            5 => {
                switch (tokens[index].kind) {
                    .l_paren => {
                        try self.state_stack.push(54);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            6 => {
                switch (tokens[index].kind) {
                    .l_paren => {
                        try self.state_stack.push(55);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            7 => {
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .access_attribute,
                    .data = .{
                        .access_attribute = .{
                            .direction = .in,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .access_attribute));
            },
            8 => {
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .access_attribute,
                    .data = .{
                        .access_attribute = .{
                            .direction = .out,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .access_attribute));
            },
            9 => {
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .access_attribute,
                    .data = .{
                        .access_attribute = .{
                            .direction = .inout,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .access_attribute));
            },
            10 => {
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .pointer_attribute,
                    .data = .{
                        .pointer_attribute = .{
                            .kind = .ref,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .pointer_attribute));
            },
            11 => {
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .pointer_attribute,
                    .data = .{
                        .pointer_attribute = .{
                            .kind = .ptr,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .pointer_attribute));
            },
            12 => {
                switch (tokens[index].kind) {
                    .identifier => {
                        try self.state_stack.push(56);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            13 => {
                switch (tokens[index].kind) {
                    .identifier => {
                        try self.state_stack.push(57);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            14 => {
                switch (tokens[index].kind) {
                    .l_paren => {
                        try self.state_stack.push(58);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            15 => {
                switch (tokens[index].kind) {
                    .colon => {
                        try self.state_stack.push(59);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    else => {
                        _ = self.state_stack.pop();
                        const name = self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .identifier,
                            .data = .{
                                .identifier = .{
                                    .name = try string_pool.put(source[name.?.data.token.start..name.?.data.token.end]),
                                    .prev = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .identifier));
                    },
                }
            },
            16 => {
                _ = self.state_stack.pop();
                const string = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .literal,
                    .data = .{
                        .literal = .{
                            .data = .{
                                .string = try string_pool.put(decodeString(source, string.?.data.token, reporter, io, filename) catch |err| switch (err) {
                                    error.DecodeFailed => {
                                        return error.ParseFailed;
                                    },
                                    else => {
                                        return err;
                                    },
                                }),
                            },
                            .kind = .string,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .literal));
            },
            17 => {
                _ = self.state_stack.pop();
                const integer = self.element_stack.pop();
                const value = decodeInteger(source, integer.?.data.token, reporter, io, filename) catch |err| switch (err) {
                    error.DecodeFailed => {
                        return error.ParseFailed;
                    },
                    else => {
                        return err;
                    },
                };

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .literal,
                    .data = .{
                        .literal = .{
                            .data = .{
                                .integer = value,
                            },
                            .kind = .integer,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .literal));
            },
            18 => {
                _ = self.state_stack.pop();
                const float = self.element_stack.pop();
                const value = decodeFloat(source, float.?.data.token, reporter, io, filename) catch |err| switch (err) {
                    error.DecodeFailed => {
                        return error.ParseFailed;
                    },
                    else => {
                        return err;
                    },
                };

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .literal,
                    .data = .{
                        .literal = .{
                            .data = .{
                                .float = value,
                            },
                            .kind = .float,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .literal));
            },
            19 => {
                _ = self.state_stack.pop();
                const char = self.element_stack.pop();
                const value = decodeChar(source, char.?.data.token, reporter, io, filename) catch |err| switch (err) {
                    error.DecodeFailed => {
                        return error.ParseFailed;
                    },
                    else => {
                        return err;
                    },
                };

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .literal,
                    .data = .{
                        .literal = .{
                            .data = .{
                                .char = value,
                            },
                            .kind = .char,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .literal));
            },
            20 => {
                _ = self.state_stack.pop();
                const string = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .literal,
                    .data = .{
                        .literal = .{
                            .data = .{
                                .macro = try string_pool.put(decodeString(source, string.?.data.token, reporter, io, filename) catch |err| switch (err) {
                                    error.DecodeFailed => {
                                        return error.ParseFailed;
                                    },
                                    else => {
                                        return err;
                                    },
                                }),
                            },
                            .kind = .macro,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .literal));
            },
            21 => {
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .literal,
                    .data = .{
                        .literal = .{
                            .data = .{
                                .nil = {},
                            },
                            .kind = .nil,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .literal));
            },
            22 => {
                switch (tokens[index].kind) {
                    .eof => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(60);
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            23 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.state_stack.push(61);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    else => {
                        _ = self.state_stack.pop();
                        const expression = self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .block_body,
                            .data = .{
                                .block_body = .{
                                    .expression = expression.?.data.node,
                                    .statements = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .block_body));
                    },
                }
            },

            24 => {
                switch (tokens[index].kind) {
                    .l_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(62);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            25, 27, 29, 30, 32, 33, 35, 50 => {
                switch (tokens[index].kind) {
                    .l_paren => {
                        _ = self.state_stack.pop();
                        const expressions = self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .non_attributed_expression,
                            .data = .{
                                .non_attributed_expressions = .{
                                    .expressions = expressions.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .non_attributed_expression));
                    },
                    else => {
                        _ = self.state_stack.pop();
                        const expressions = self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .expression,
                            .data = .{
                                .expression = .{
                                    .expression = expressions.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .expression));
                    },
                }
            },
            26 => {
                _ = self.state_stack.pop();
                const expression = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .expressions,
                    .data = .{
                        .expressions = .{
                            .expression = expression.?.data.node,
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .expressions));
            },
            28 => {
                _ = self.state_stack.pop();
                const expression = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .module,
                    .data = .{
                        .module = .{
                            .body = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .module));
            },
            31 => {
                switch (tokens[index].kind) {
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(63);
                        index += 1;
                    },
                    .l_paren => {
                        _ = self.state_stack.pop();
                        const expressions = self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .non_attributed_expression,
                            .data = .{
                                .non_attributed_expressions = .{
                                    .expressions = expressions.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .non_attributed_expression));
                    },
                    else => {
                        _ = self.state_stack.pop();
                        const expressions = self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .expression,
                            .data = .{
                                .expression = .{
                                    .expression = expressions.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .expression));
                    },
                }
            },
            34 => {
                switch (tokens[index].kind) {
                    .dot => {
                        try self.state_stack.push(64);
                        try self.pushToken(tokens[index]);
                        index += 1;
                    },
                    .equal => {
                        _ = self.state_stack.pop();
                        const target = self.element_stack.pop();
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .assignment_target,
                            .data = .{
                                .assignment_target = .{
                                    .access = null,
                                    .attribute = null,
                                    .name = target.?.data.node,
                                    .kind = .identifier,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .assignment_target));
                    },
                    else => {
                        _ = self.state_stack.pop();
                        const value = self.element_stack.pop();
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .literal,
                            .data = .{
                                .literal = .{
                                    .data = .{
                                        .identifier = value.?.data.node,
                                    },
                                    .kind = .identifier,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .literal));
                    },
                }
            },
            37 => {
                _ = self.state_stack.pop();
                const statement = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .statements,
                    .data = .{
                        .statements = .{
                            .prev = null,
                            .statement = statement.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .statements));
            },
            38, 39, 41, 42, 43 => {
                _ = self.state_stack.pop();
                const statement = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .statement,
                    .data = .{
                        .statement = .{
                            .statement = statement.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .statement));
            },
            40 => {
                switch (tokens[index].kind) {
                    .equal => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(67);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            44 => {
                switch (tokens[index].kind) {
                    .l_brace => {
                        try self.state_stack.push(1);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .l_paren => {
                        try self.state_stack.push(2);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_match => {
                        try self.state_stack.push(4);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_function => {
                        try self.state_stack.push(5);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_type => {
                        try self.state_stack.push(6);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_in => {
                        try self.state_stack.push(7);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_out => {
                        try self.state_stack.push(8);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_inout => {
                        try self.state_stack.push(9);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_ref => {
                        try self.state_stack.push(10);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_ptr => {
                        try self.state_stack.push(11);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_runtime => {
                        try self.state_stack.push(14);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .identifier => {
                        try self.state_stack.push(68);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .string => {
                        try self.state_stack.push(16);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .integer => {
                        try self.state_stack.push(17);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .float => {
                        try self.state_stack.push(18);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .char => {
                        try self.state_stack.push(19);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .macro => {
                        try self.state_stack.push(20);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_nil => {
                        try self.state_stack.push(21);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            45 => {
                switch (tokens[index].kind) {
                    .keyword_in => {
                        try self.state_stack.push(7);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_out => {
                        try self.state_stack.push(8);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_inout => {
                        try self.state_stack.push(9);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_ref => {
                        try self.state_stack.push(10);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_ptr => {
                        try self.state_stack.push(11);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            46 => {
                _ = self.state_stack.pop();
                const attributed_expression = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .expression,
                    .data = .{
                        .expression = .{
                            .expression = attributed_expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .expression));
            },
            47 => {
                switch (tokens[index].kind) {
                    .r_brace => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(71);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            48 => {
                _ = self.state_stack.pop();
                const name = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .identifier,
                    .data = .{
                        .identifier = .{
                            .name = try string_pool.put(decodeIdentifier(source, name.?.data.token, reporter, io, filename) catch |err| switch (err) {
                                error.DecodeFailed => {
                                    return error.ParseFailed;
                                },
                                else => {
                                    return err;
                                },
                            }),
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .identifier));
            },
            49 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .r_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(72);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            51 => {
                switch (tokens[index].kind) {
                    .dot => {
                        try self.state_stack.push(64);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    else => {
                        _ = self.state_stack.pop();
                        const value = self.element_stack.pop();
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .literal,
                            .data = .{
                                .literal = .{
                                    .data = .{
                                        .identifier = value.?.data.node,
                                    },
                                    .kind = .identifier,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .literal));
                    },
                }
            },
            54 => {
                switch (tokens[index].kind) {
                    .keyword_in => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(7);
                        index += 1;
                    },
                    .keyword_out => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(8);
                        index += 1;
                    },
                    .keyword_inout => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(9);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            59 => {
                switch (tokens[index].kind) {
                    .semicolon => {
                        try self.state_stack.push(81);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    .keyword_match => {
                        try self.state_stack.push(4);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            60 => {
                _ = self.element_stack.pop();
                const module = self.element_stack.pop();
                return module.?.data.node;
            },
            63 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const call = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .call_statement,
                    .data = .{
                        .call_statement = .{
                            .call = call.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .call_statement));
            },
            64 => {
                switch (tokens[index].kind) {
                    .identifier => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(85);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            65 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.state_stack.push(61);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    else => {
                        _ = self.state_stack.pop();
                        _ = self.state_stack.pop();
                        const expression = self.element_stack.pop();
                        const statements = self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .block_body,
                            .data = .{
                                .block_body = .{
                                    .expression = expression.?.data.node,
                                    .statements = statements.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .block_body));
                    },
                }
            },
            66 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const statment = self.element_stack.pop();
                const statments = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .statements,
                    .data = .{
                        .statements = .{
                            .prev = statments.?.data.node,
                            .statement = statment.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .statements));
            },
            68 => {
                switch (tokens[index].kind) {
                    .colon => {
                        try self.state_stack.push(87);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    else => {
                        _ = self.state_stack.pop();
                        const name = self.element_stack.pop();
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .identifier,
                            .data = .{
                                .identifier = .{
                                    .name = try string_pool.put(source[name.?.data.token.start..name.?.data.token.end]),
                                    .prev = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .identifier));
                    },
                }
            },
            69, 70 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const expression = self.element_stack.pop();
                const attribute = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .attributed_expression,
                    .data = .{
                        .attributed_expression = .{
                            .attribute = attribute.?.data.node,
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .attributed_expression));
            },
            71 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const body = self.element_stack.pop();
                _ = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .block,
                    .data = .{
                        .block = .{
                            .body = body.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .block));
            },
            72 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expressions = self.element_stack.pop();
                _ = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .wrapped_expressions,
                    .data = .{
                        .wrapped_expressions = .{
                            .expressions = expressions.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .wrapped_expressions));
            },
            73 => {
                switch (tokens[index].kind) {
                    .r_paren => {
                        try self.state_stack.push(89);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            74 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(90);
                        index += 1;
                    },
                    .r_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(91);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            75 => {
                _ = self.state_stack.pop();
                const parameter = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_parameters,
                    .data = .{
                        .function_parameters = .{
                            .parameter = parameter.?.data.node,
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_parameters));
            },
            76 => {
                switch (tokens[index].kind) {
                    .identifier => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(92);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            77 => {
                switch (tokens[index].kind) {
                    .r_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(93);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            78 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(94);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            79 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(95);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            80 => {
                switch (tokens[index].kind) {
                    .r_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(96);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            81 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                _ = self.element_stack.pop();
                const name = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .label_statement,
                    .data = .{
                        .label_statement = .{
                            .expression = null,
                            .name = try string_pool.put(decodeIdentifier(source, name.?.data.token, reporter, io, filename) catch |err| switch (err) {
                                error.DecodeFailed => {
                                    return error.ParseFailed;
                                },
                                else => {
                                    return err;
                                },
                            }),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .label_statement));
            },
            82 => {
                switch (tokens[index].kind) {
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(97);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            83 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const expression = self.element_stack.pop();
                _ = self.element_stack.pop();
                const expressions = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .expressions,
                    .data = .{
                        .expressions = .{
                            .expression = expression.?.data.node,
                            .prev = expressions.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .expressions));
            },
            84 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .r_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(98);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            85 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const identifier = self.element_stack.pop();
                _ = self.element_stack.pop();
                const identifiers = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .identifier,
                    .data = .{
                        .identifier = .{
                            .name = try string_pool.put(source[identifier.?.data.token.start..identifier.?.data.token.end]),
                            .prev = identifiers.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .identifier));
            },
            86 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(99);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            88 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const attribute = self.element_stack.pop();
                const name = self.element_stack.pop();
                const access = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .assignment_target,
                    .data = .{
                        .assignment_target = .{
                            .access = access.?.data.node,
                            .attribute = attribute.?.data.node,
                            .name = try string_pool.put(source[name.?.data.token.start..name.?.data.token.end]),
                            .kind = .literal,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .assignment_target));
            },
            89 => {
                switch (tokens[index].kind) {
                    .l_brace => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(101);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            90 => {
                switch (tokens[index].kind) {
                    .keyword_in => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(7);
                        index += 1;
                    },
                    .keyword_out => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(8);
                        index += 1;
                    },
                    .keyword_inout => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(9);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            91 => {
                switch (tokens[index].kind) {
                    .keyword_external => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(103);
                        index += 1;
                    },
                    .keyword_internal => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(104);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            92 => {
                switch (tokens[index].kind) {
                    .colon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(87);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            93 => {
                switch (tokens[index].kind) {
                    .l_brace => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(110);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            94 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expressions = self.element_stack.pop();
                const target = self.element_stack.pop();
                _ = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .continue_statement,
                    .data = .{
                        .continue_statement = .{
                            .expressions = expressions.?.data.node,
                            .target = try string_pool.put(source[target.?.data.token.start..target.?.data.token.end]),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .continue_statement));
            },
            95 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expressions = self.element_stack.pop();
                const target = self.element_stack.pop();
                _ = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .break_statement,
                    .data = .{
                        .break_statement = .{
                            .expressions = expressions.?.data.node,
                            .target = try string_pool.put(source[target.?.data.token.start..target.?.data.token.end]),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .break_statement));
            },
            96 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expression = self.element_stack.pop();
                _ = self.element_stack.pop();
                _ = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .runtime_expression,
                    .data = .{
                        .runtime_expression = .{
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .runtime_expression));
            },
            97 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expression = self.element_stack.pop();
                _ = self.element_stack.pop();
                const label = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .label_statement,
                    .data = .{
                        .label_statement = .{
                            .expression = expression.?.data.node,
                            .name = try string_pool.put(source[label.?.data.token.start..label.?.data.token.end]),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .label_statement));
            },
            98 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expressions = self.element_stack.pop();
                _ = self.element_stack.pop();
                const target = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .call,
                    .data = .{
                        .call = .{
                            .target = target.?.data.node,
                            .arguments = expressions.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .call));
            },
            99 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expressions = self.element_stack.pop();
                _ = self.element_stack.pop();
                const target = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .assignment_statement,
                    .data = .{
                        .assignment_statement = .{
                            .expressions = expressions.?.data.node,
                            .target = target.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .assignment_statement));
            },
            100 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const expression = self.element_stack.pop();
                _ = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_attribute,
                    .data = .{
                        .type_attribute = .{
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .type_attribute));
            },
            101 => {
                switch (tokens[index].kind) {
                    .keyword_case => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(111);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            102 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const parameter = self.element_stack.pop();
                _ = self.element_stack.pop();
                const parameters = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_parameters,
                    .data = .{
                        .function_parameters = .{
                            .parameter = parameter.?.data.node,
                            .prev = parameters.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_parameters));
            },
            103 => {
                switch (tokens[index].kind) {
                    .l_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(114);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            104 => {
                switch (tokens[index].kind) {
                    .l_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(115);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            105 => {
                switch (tokens[index].kind) {
                    .colon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(116);
                        index += 1;
                    },
                    .keyword_external => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(103);
                        index += 1;
                    },
                    .keyword_internal => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(104);
                        index += 1;
                    },
                    else => {
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .function_body,
                            .data = .{
                                .function_body = .{
                                    .expression = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_body));
                    },
                }
            },
            106 => {
                _ = self.state_stack.pop();
                const attribute = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_attributes,
                    .data = .{
                        .function_attributes = .{
                            .attribute = attribute.?.data.node,
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_attributes));
            },
            107, 108 => {
                _ = self.state_stack.pop();
                const attribute = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_attribute,
                    .data = .{
                        .function_attribute = .{
                            .attribute = attribute.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_attribute));
            },
            109 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const attribute = self.element_stack.pop();
                const name = self.element_stack.pop();
                const access = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_parameter,
                    .data = .{
                        .function_parameter = .{
                            .access = access.?.data.node,
                            .attribute = attribute.?.data.node,
                            .name = try string_pool.put(source[name.?.data.token.start..name.?.data.token.end]),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_parameter));
            },
            110 => {
                switch (tokens[index].kind) {
                    .identifier => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(119);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            112 => {
                switch (tokens[index].kind) {
                    .r_brace => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(123);
                        index += 1;
                    },
                    .keyword_case => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(111);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            113 => {
                _ = self.state_stack.pop();
                const case = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .match_cases,
                    .data = .{
                        .match_cases = .{
                            .case = case.?.data.node,
                            .cases = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .match_cases));
            },
            117 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const attribute = self.element_stack.pop();
                const attributes = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_attributes,
                    .data = .{
                        .function_attributes = .{
                            .attribute = attribute.?.data.node,
                            .prev = attributes.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_attributes));
            },
            118 => {
                switch (tokens[index].kind) {
                    .percent => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(128);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            119 => {
                switch (tokens[index].kind) {
                    .colon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(87);
                        index += 1;
                    },
                    else => {
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .type_attribute_optional,
                            .data = .{
                                .type_attribute_optional = .{
                                    .attribute = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .type_attribute_optional));
                    },
                }
            },
            120 => {
                switch (tokens[index].kind) {
                    .r_brace => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(131);
                        index += 1;
                    },
                    .identifier => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(119);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            121 => {
                _ = self.state_stack.pop();
                const entry = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_entries,
                    .data = .{
                        .type_entries = .{
                            .entry = entry.?.data.node,
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .type_entries));
            },
            122 => {
                switch (tokens[index].kind) {
                    .colon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(133);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            123 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const cases = self.element_stack.pop();
                _ = self.element_stack.pop();
                _ = self.element_stack.pop();
                const expression = self.element_stack.pop();
                _ = self.element_stack.pop();
                _ = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .match_expression,
                    .data = .{
                        .match_expression = .{
                            .cases = cases.?.data.node,
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .match_expression));
            },
            124 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const case = self.element_stack.pop();
                const cases = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .match_cases,
                    .data = .{
                        .match_cases = .{
                            .cases = cases.?.data.node,
                            .case = case.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .match_cases));
            },
            125 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .r_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(134);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            126 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .r_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(135);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            127 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    else => {
                        _ = self.state_stack.pop();
                        _ = self.state_stack.pop();
                        const expression = self.element_stack.pop();
                        _ = self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .function_body,
                            .data = .{
                                .function_body = .{
                                    .expression = expression.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_body));
                    },
                }
            },
            128 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const body = self.element_stack.pop();
                const attributes = self.element_stack.pop();
                _ = self.element_stack.pop();
                const parameters = self.element_stack.pop();
                _ = self.element_stack.pop();
                _ = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function,
                    .data = .{
                        .function = .{
                            .attributes = attributes.?.data.node,
                            .parameters = parameters.?.data.node,
                            .body = body.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function));
            },
            129 => {
                switch (tokens[index].kind) {
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(136);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            130 => {
                _ = self.state_stack.pop();
                const attribute = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_attribute_optional,
                    .data = .{
                        .type_attribute_optional = .{
                            .attribute = attribute.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .type_attribute_optional));
            },
            131 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const entries = self.element_stack.pop();
                _ = self.element_stack.pop();
                _ = self.element_stack.pop();
                const expression = self.element_stack.pop();
                _ = self.element_stack.pop();
                _ = self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type,
                    .data = .{
                        .type = .{
                            .entries = entries.?.data.node,
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .type));
            },
            132 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                const entry = self.element_stack.pop();
                const entries = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_entries,
                    .data = .{
                        .type_entries = .{
                            .entry = entry.?.data.node,
                            .prev = entries.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .type_entries));
            },
            134 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expression = self.element_stack.pop();
                _ = self.element_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_external_attribute,
                    .data = .{
                        .function_external_attribute = .{
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_external_attribute));
            },
            135 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expression = self.element_stack.pop();
                _ = self.element_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_internal_attribute,
                    .data = .{
                        .function_internal_attribute = .{
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .function_internal_attribute));
            },
            136 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expression = self.element_stack.pop();
                const name = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_entry,
                    .data = .{
                        .type_entry = .{
                            .expression = expression.?.data.node,
                            .name = try string_pool.put(source[name.?.data.token.start..name.?.data.token.end]),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .type_entry));
            },
            137 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(138);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            138 => {
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.state_stack.pop();
                _ = self.element_stack.pop();
                const expression = self.element_stack.pop();
                _ = self.element_stack.pop();
                const condition = self.element_stack.pop();
                _ = self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .match_case,
                    .data = .{
                        .match_case = .{
                            .expression = condition.?.data.node,
                            .body = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top(), .match_case));
            },
            255 => {
                try reporter.add(io, .@"error", filename, 1, 1, "", .{});
                return error.ParseFailed;
            },
            else => unreachable,
        }
    }
}

// We don't support multiple-bytes charactor right now.
fn decodeChar(source: [:0]u8, token: Tokenizer.Token, reporter: *Error.Reporter, io: std.Io, filename: u32) error{ DecodeFailed, OutOfMemory }!u8 {
    var from = token.start + 1;
    var index = from;
    var write = from;

    const State = enum {
        start,
        finish,
        escaped,
        escaped_hex,
        escaped_hex2,
    };

    ct: switch (State.start) {
        .start => {
            switch (source[index]) {
                0 => {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                    return error.DecodeFailed;
                },
                '\\' => {
                    from = index;
                    index += 1;
                    continue :ct .escaped;
                },
                '\'' => {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode empty char!", .{});
                    return error.DecodeFailed;
                },
                else => {
                    index += 1;
                    continue :ct .finish;
                },
            }
        },
        .finish => {
            switch (source[index]) {
                0 => {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                    return error.DecodeFailed;
                },
                '\'' => {
                    return source[write - 1];
                },
                else => {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode non-single-byte char!", .{});
                    return error.DecodeFailed;
                },
            }
        },
        .escaped => {
            switch (source[index]) {
                0 => {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                    return error.DecodeFailed;
                },
                't' => {
                    source[write] = '\t';
                    index += 1;
                    write += 1;
                    if (source[index] == 0) {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                        return error.DecodeFailed;
                    }
                    if (source[index] != '\'') {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode non-single-byte char!", .{});
                        return error.DecodeFailed;
                    } else {
                        source[write] = '\'';
                        write += 1;
                    }
                    return source[write - 1];
                },
                'n' => {
                    source[write] = '\n';
                    index += 1;
                    write += 1;

                    if (source[index] == 0) {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                        return error.DecodeFailed;
                    }
                    if (source[index] != '\'') {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode non-single-byte char!", .{});
                        return error.DecodeFailed;
                    } else {
                        source[write] = '\'';
                        write += 1;
                    }
                    return source[write - 1];
                },
                'r' => {
                    source[write] = '\r';
                    index += 1;
                    write += 1;

                    if (source[index] == 0) {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                        return error.DecodeFailed;
                    }
                    if (source[index] != '\'') {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode non-single-byte char!", .{});
                        return error.DecodeFailed;
                    } else {
                        source[write] = '\'';
                        write += 1;
                    }
                    return source[write - 1];
                },
                '\'' => {
                    source[write] = '\'';
                    index += 1;
                    write += 1;

                    if (source[index] == 0) {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                        return error.DecodeFailed;
                    }
                    if (source[index] != '\'') {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode non-single-byte char!", .{});
                        return error.DecodeFailed;
                    } else {
                        source[write] = '\'';
                        write += 1;
                    }
                    return source[write - 1];
                },
                '"' => {
                    source[write] = '"';
                    index += 1;
                    write += 1;

                    if (source[index] == 0) {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                        return error.DecodeFailed;
                    }
                    if (source[index] != '\'') {
                        try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode non-single-byte char!", .{});
                        return error.DecodeFailed;
                    } else {
                        source[write] = '\'';
                        write += 1;
                    }
                    return source[write - 1];
                },
                'x' => {
                    index += 1;
                    from = index;
                    continue :ct .escaped_hex;
                },
                else => {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode non-hex-escaped charactor right now!", .{});
                    return error.DecodeFailed;
                },
            }
        },
        .escaped_hex => {
            if (source[index] == 0) {
                try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                return error.DecodeFailed;
            } else if (std.ascii.isHex(source[index])) {
                index += 1;
                continue :ct .escaped_hex2;
            } else if (source[index] == '\'') {
                try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode charactor! Too short!", .{});
                return error.DecodeFailed;
            } else {
                try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode charactor! Expect a hex encoded charactor!", .{});
                return error.DecodeFailed;
            }
        },
        .escaped_hex2 => {
            if (source[index] == 0) {
                try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                return error.DecodeFailed;
            } else if (std.ascii.isHex(source[index])) {
                index += 1;

                if (source[index] == 0) {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                    return error.DecodeFailed;
                }
                if (source[index] != '\'') {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode non-single-byte char!", .{});
                    return error.DecodeFailed;
                }
                var buf: [2]u8 = undefined;
                const result = std.fmt.hexToBytes(&buf, source[from..index]) catch unreachable;
                source[write] = result[0];
                write += 1;
                source[write] = '\'';
                write += 1;
                return source[write - 2];
            } else {
                try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Cannot decode charactor! Expect a hex encoded charactor!", .{});
                return error.DecodeFailed;
            }
        },
    }
}

fn decodeString(source: [:0]u8, token: Tokenizer.Token, reporter: *Error.Reporter, io: std.Io, filename: u32) error{ DecodeFailed, OutOfMemory }![]u8 {
    var from = token.start + 1;
    var index = from;
    var write = from;

    const State = enum {
        start,
        escaped,
        escaped_hex,
        escaped_hex2,
    };

    ct: switch (State.start) {
        .start => {
            switch (source[index]) {
                0 => {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                    return error.DecodeFailed;
                },
                '\\' => {
                    from = index;
                    index += 1;
                    continue :ct .escaped;
                },
                '"' => {
                    source[write] = '"';
                    write += 1;
                    return source[index..write];
                },
                else => {
                    index += 1;
                    write += 1;
                    continue :ct .start;
                },
            }
        },
        .escaped => {
            switch (source[index]) {
                0 => {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                    return error.DecodeFailed;
                },
                't' => {
                    source[write] = '\t';
                    index += 1;
                    write += 1;
                    continue :ct .start;
                },
                'n' => {
                    source[write] = '\n';
                    index += 1;
                    write += 1;
                    continue :ct .start;
                },
                'r' => {
                    source[write] = '\r';
                    index += 1;
                    write += 1;
                    continue :ct .start;
                },
                '\'' => {
                    source[write] = '\'';
                    index += 1;
                    write += 1;
                    continue :ct .start;
                },
                '"' => {
                    source[write] = '"';
                    index += 1;
                    write += 1;
                    continue :ct .start;
                },
                'x' => {
                    index += 1;
                    continue :ct .escaped_hex;
                },
                else => {
                    try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected charactor {s}", .{source[index .. index + 1]});
                    return error.DecodeFailed;
                },
            }
        },
        .escaped_hex => {
            if (source[index] == 0) {
                try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                return error.DecodeFailed;
            } else if (std.ascii.isHex(source[index])) {
                index += 1;
                continue :ct .escaped_hex2;
            } else {
                try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected charactor {s}", .{source[index .. index + 1]});
                return error.DecodeFailed;
            }
        },
        .escaped_hex2 => {
            if (source[index] == 0) {
                try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected EOF!", .{});
                return error.DecodeFailed;
            } else if (std.ascii.isHex(source[index])) {
                index += 1;
                var buf: [2]u8 = undefined;
                const result = std.fmt.hexToBytes(&buf, source[from..index]) catch unreachable;
                source[write] = result[0];
                write += 1;
                continue :ct .start;
            } else {
                try reporter.add(io, .@"error", filename, token.line, index - token.start + token.pos, "Unexpected charactor {s}", .{source[index .. index + 1]});
                return error.DecodeFailed;
            }
        },
    }
}

fn decodeIdentifier(source: [:0]u8, token: Tokenizer.Token, reporter: *Error.Reporter, io: std.Io, filename: u32) error{ DecodeFailed, OutOfMemory }![]u8 {
    if (source[token.start] == '#') {
        return try decodeString(source, token, reporter, io, filename);
    } else {
        return source[token.start..token.end];
    }
}

fn decodeInteger(source: [:0]u8, token: Tokenizer.Token, reporter: *Error.Reporter, io: std.Io, filename: u32) error{ DecodeFailed, OutOfMemory }!usize {
    _ = source;
    _ = token;
    _ = reporter;
    _ = io;
    _ = filename;
    // Stub
    return 0;
}

fn decodeFloat(source: [:0]u8, token: Tokenizer.Token, reporter: *Error.Reporter, io: std.Io, filename: u32) error{ DecodeFailed, OutOfMemory }!f64 {
    _ = source;
    _ = token;
    _ = reporter;
    _ = io;
    _ = filename;
    // Stub
    return 0;
}

fn reportUnexpectedToken(reporter: *Error.Reporter, io: std.Io, filename: u32, token: Tokenizer.Token) error{OutOfMemory}!void {
    try reporter.add(io, .@"error", filename, token.line, token.pos, "Unexpected token {any}", .{token.kind});
}
