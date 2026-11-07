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

    const Data = union(Kind) {
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
    var element_stack = try ElementStack.init(allocator);
    errdefer element_stack.deinit();

    var state_stack = try StateStack.init(allocator);
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
        88,
        113,
        116,
        117,
        118,
        135,
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
        77,
        112,
        => switch (kind) {
            .identifier => true,
            else => false,
        },
        15,
        68,
        93,
        121,
        124,
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
        75,
        129,
        => switch (kind) {
            .comma => true,
            else => false,
        },
        31,
        83,
        131,
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
        85,
        127,
        128,
        => switch (kind) {
            .comma,
            .r_paren,
            => true,
            else => false,
        },
        54, 92 => switch (kind) {
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
        74,
        78,
        81,
        => switch (kind) {
            .r_paren => true,
            else => false,
        },
        79,
        80,
        87,
        139,
        => switch (kind) {
            .comma,
            .semicolon,
            => true,
            else => false,
        },
        90,
        94,
        => switch (kind) {
            .l_brace => true,
            else => false,
        },
        91 => switch (kind) {
            .keyword_external,
            .keyword_internal,
            => true,
            else => false,
        },
        102 => switch (kind) {
            .keyword_case => true,
            else => false,
        },
        105 => switch (kind) {
            .colon,
            => true,
            else => false,
        },
        106 => switch (kind) {
            .keyword_external,
            .keyword_internal,
            => true,
            else => false,
        },
        114 => switch (kind) {
            .r_brace,
            .keyword_case,
            => true,
            else => false,
        },
        119 => switch (kind) {
            .percent => true,
            else => false,
        },
        122 => switch (kind) {
            .r_brace,
            .identifier,
            => true,
            else => false,
        },
        else => return false,
    };
}

fn skipUntilAcceptable(self: *Self, tokens: []Tokenizer.Token, _index: usize) error{ ParseFailed, OutOfMemory }!usize {
    var index = _index;
    while (tokens[index].kind != .eof and !isSyncToken(tokens[index])) : (index += 1) {}

    // if (tokens[index].kind == .eof) {
    //      Handle this
    // }

    while (self.state_stack.count() != 0) {
        if (isShiftable(self.state_stack.top() orelse 255, tokens[index].kind)) {
            return index;
        } else {
            _ = try self.state_stack.pop();
            _ = try self.element_stack.pop();
        }
    }

    return error.ParseFailed;
    // return 255;
}

fn getReduceGoto(state: u32, node_kind: ASTNode.Kind) u8 {
    switch (state) {
        0 => {
            return switch (node_kind) {
                .module => 22,
                .expressions => 23,
                .non_attributed_expressions => 24,
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
                .non_attributed_expressions => 24,
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
                .non_attributed_expressions => 24,
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
                .non_attributed_expressions => 24,
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
                .non_attributed_expressions => 24,
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
                .non_attributed_expressions => 24,
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
                .function_parameters_optional => 74,
                .function_parameters => 75,
                .function_parameter => 76,
                .access_attribute => 77,
                else => unreachable,
            };
        },
        55 => {
            return switch (node_kind) {
                .non_attributed_expressions => 24,
                .wrapped_expressions => 25,
                .expression => 78,
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
                .expressions => 79,
                .non_attributed_expressions => 24,
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
                .expressions => 80,
                .non_attributed_expressions => 24,
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
                .non_attributed_expressions => 24,
                .wrapped_expressions => 25,
                .expression => 81,
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
                .match_expression => 83,
                else => unreachable,
            };
        },
        61 => {
            return switch (node_kind) {
                .non_attributed_expressions => 24,
                .wrapped_expressions => 25,
                .expression => 84,
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
                .expressions => 85,
                .non_attributed_expressions => 24,
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
                .expressions => 87,
                .non_attributed_expressions => 24,
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
                .type_attribute => 89,
                else => unreachable,
            };
        },
        88 => {
            return switch (node_kind) {
                .non_attributed_expressions => 24,
                .wrapped_expressions => 25,
                .expression => 101,
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

        91 => {
            return switch (node_kind) {
                .function_attributes_optional => 105,
                .function_attributes => 106,
                .function_attribute => 107,
                .function_external_attribute => 108,
                .function_internal_attribute => 109,
                else => unreachable,
            };
        },
        92 => {
            return switch (node_kind) {
                .function_parameter => 110,
                .access_attribute => 77,
                else => unreachable,
            };
        },
        93 => {
            return switch (node_kind) {
                .type_attribute => 111,
                else => unreachable,
            };
        },
        102 => {
            return switch (node_kind) {
                .match_cases => 114,
                .match_case => 115,
                else => unreachable,
            };
        },
        105 => {
            return switch (node_kind) {
                .function_body => 119,
                else => unreachable,
            };
        },
        106 => {
            return switch (node_kind) {
                .function_attribute => 120,
                .function_external_attribute => 108,
                .function_internal_attribute => 109,
                else => unreachable,
            };
        },
        112 => {
            return switch (node_kind) {
                .type_entries => 122,
                .type_entry => 123,
                else => unreachable,
            };
        },
        113 => {
            return switch (node_kind) {
                .non_attributed_expressions => 24,
                .wrapped_expressions => 25,
                .expression => 124,
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
        114 => {
            return switch (node_kind) {
                .match_case => 126,
                else => unreachable,
            };
        },
        116 => {
            return switch (node_kind) {
                .expressions => 127,
                .non_attributed_expressions => 24,
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
        117 => {
            return switch (node_kind) {
                .expressions => 128,
                .non_attributed_expressions => 24,
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
        118 => {
            return switch (node_kind) {
                .expressions => 129,
                .non_attributed_expressions => 24,
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
        121 => {
            return switch (node_kind) {
                .type_attribute_optional => 131,
                .type_attribute => 132,
                else => unreachable,
            };
        },
        122 => {
            return switch (node_kind) {
                .type_entry => 134,
                else => unreachable,
            };
        },
        135 => {
            return switch (node_kind) {
                .expressions => 139,
                .non_attributed_expressions => 24,
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
            88,
            113,
            116,
            117,
            118,
            135,
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
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();

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

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .assignment_target));
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
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .access_attribute,
                    .data = .{
                        .access_attribute = .{
                            .direction = .in,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .access_attribute));
            },
            8 => {
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .access_attribute,
                    .data = .{
                        .access_attribute = .{
                            .direction = .out,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .access_attribute));
            },
            9 => {
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .access_attribute,
                    .data = .{
                        .access_attribute = .{
                            .direction = .inout,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .access_attribute));
            },
            10 => {
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .pointer_attribute,
                    .data = .{
                        .pointer_attribute = .{
                            .kind = .ref,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .pointer_attribute));
            },
            11 => {
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .pointer_attribute,
                    .data = .{
                        .pointer_attribute = .{
                            .kind = .ptr,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .pointer_attribute));
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
                        _ = try self.state_stack.pop();
                        const name = try self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .identifier,
                            .data = .{
                                .identifier = .{
                                    .name = try string_pool.put(source[name.?.data.token.start..name.?.data.token.end]),
                                    .prev = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .identifier));
                    },
                }
            },
            16 => {
                _ = try self.state_stack.pop();
                const string = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .literal,
                    .data = .{
                        .literal = .{
                            .data = .{
                                .string = try string_pool.put(decodeString(source, string.?.data.token, reporter, io, filename) catch |err| switch (err) {
                                    error.DecodeFailed => {
                                        return error.ParseFailed;
                                    },
                                    else => |_err| {
                                        return @errorCast(_err);
                                    },
                                }),
                            },
                            .kind = .string,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .literal));
            },
            17 => {
                _ = try self.state_stack.pop();
                const integer = try self.element_stack.pop();
                const value = decodeInteger(source, integer.?.data.token, reporter, io, filename) catch |err| switch (err) {
                    error.DecodeFailed => {
                        return error.ParseFailed;
                    },
                    else => |_err| {
                        return @errorCast(_err);
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

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .literal));
            },
            18 => {
                _ = try self.state_stack.pop();
                const float = try self.element_stack.pop();
                const value = decodeFloat(source, float.?.data.token, reporter, io, filename) catch |err| switch (err) {
                    error.DecodeFailed => {
                        return error.ParseFailed;
                    },
                    else => |_err| {
                        return @errorCast(_err);
                    },
                };

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .literal,
                    .data = .{
                        .literal = .{
                            .data = .{
                                .float = @bitCast(value),
                            },
                            .kind = .float,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .literal));
            },
            19 => {
                _ = try self.state_stack.pop();
                const char = try self.element_stack.pop();
                const value = decodeChar(source, char.?.data.token, reporter, io, filename) catch |err| switch (err) {
                    error.DecodeFailed => {
                        return error.ParseFailed;
                    },
                    else => |_err| {
                        return @errorCast(_err);
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

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .literal));
            },
            20 => {
                _ = try self.state_stack.pop();
                const string = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .literal,
                    .data = .{
                        .literal = .{
                            .data = .{
                                .macro = try string_pool.put(decodeIdentifier(source, string.?.data.token, reporter, io, filename) catch |err| switch (err) {
                                    error.DecodeFailed => {
                                        return error.ParseFailed;
                                    },
                                    else => |_err| {
                                        return @errorCast(_err);
                                    },
                                }),
                            },
                            .kind = .macro,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .literal));
            },
            21 => {
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();

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

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .literal));
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
                        _ = try self.state_stack.pop();
                        const expression = try self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .block_body,
                            .data = .{
                                .block_body = .{
                                    .expression = expression.?.data.node,
                                    .statements = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .block_body));
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
                        _ = try self.state_stack.pop();
                        const expressions = try self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .non_attributed_expressions,
                            .data = .{
                                .non_attributed_expressions = .{
                                    .expressions = expressions.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .non_attributed_expressions));
                    },
                    else => {
                        _ = try self.state_stack.pop();
                        const expressions = try self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .expression,
                            .data = .{
                                .expression = .{
                                    .expression = expressions.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .expression));
                    },
                }
            },
            26 => {
                _ = try self.state_stack.pop();
                const expression = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .expressions,
                    .data = .{
                        .expressions = .{
                            .expression = expression.?.data.node,
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .expressions));
            },
            28 => {
                _ = try self.state_stack.pop();
                const expression = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .module,
                    .data = .{
                        .module = .{
                            .body = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .module));
            },
            31 => {
                switch (tokens[index].kind) {
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(63);
                        index += 1;
                    },
                    .l_paren => {
                        _ = try self.state_stack.pop();
                        const expressions = try self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .non_attributed_expressions,
                            .data = .{
                                .non_attributed_expressions = .{
                                    .expressions = expressions.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .non_attributed_expressions));
                    },
                    else => {
                        _ = try self.state_stack.pop();
                        const expressions = try self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .expression,
                            .data = .{
                                .expression = .{
                                    .expression = expressions.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .expression));
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
                        _ = try self.state_stack.pop();
                        const target = try self.element_stack.pop();
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

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .assignment_target));
                    },
                    else => {
                        _ = try self.state_stack.pop();
                        const value = try self.element_stack.pop();
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

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .literal));
                    },
                }
            },
            37 => {
                _ = try self.state_stack.pop();
                const statement = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .statements,
                    .data = .{
                        .statements = .{
                            .prev = null,
                            .statement = statement.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .statements));
            },
            38, 39, 41, 42, 43 => {
                _ = try self.state_stack.pop();
                const statement = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .statement,
                    .data = .{
                        .statement = .{
                            .statement = statement.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .statement));
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
                _ = try self.state_stack.pop();
                const attributed_expression = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .expression,
                    .data = .{
                        .expression = .{
                            .expression = attributed_expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .expression));
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
                _ = try self.state_stack.pop();
                const name = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .identifier,
                    .data = .{
                        .identifier = .{
                            .name = try string_pool.put(decodeIdentifier(source, name.?.data.token, reporter, io, filename) catch |err| switch (err) {
                                error.DecodeFailed => {
                                    return error.ParseFailed;
                                },
                                else => |_err| {
                                    return @errorCast(_err);
                                },
                            }),
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .identifier));
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
                        _ = try self.state_stack.pop();
                        const value = try self.element_stack.pop();
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

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .literal));
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
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .function_parameters_optional,
                            .data = .{
                                .function_parameters_optional = .{
                                    .parameters = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_parameters_optional));
                    },
                }
            },
            59 => {
                switch (tokens[index].kind) {
                    .semicolon => {
                        try self.state_stack.push(82);
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
                _ = try self.element_stack.pop();
                const module = try self.element_stack.pop();
                return module.?.data.node;
            },
            63 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const call = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .call_statement,
                    .data = .{
                        .call_statement = .{
                            .call = call.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .call_statement));
            },
            64 => {
                switch (tokens[index].kind) {
                    .identifier => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(86);
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
                        _ = try self.state_stack.pop();
                        _ = try self.state_stack.pop();
                        const expression = try self.element_stack.pop();
                        const statements = try self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .block_body,
                            .data = .{
                                .block_body = .{
                                    .expression = expression.?.data.node,
                                    .statements = statements.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .block_body));
                    },
                }
            },
            66 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const statment = try self.element_stack.pop();
                const statments = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .statements,
                    .data = .{
                        .statements = .{
                            .prev = statments.?.data.node,
                            .statement = statment.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .statements));
            },
            68 => {
                switch (tokens[index].kind) {
                    .colon => {
                        try self.state_stack.push(88);
                        try self.pushToken(tokens[index]);
                        index += 1;
                        continue;
                    },
                    else => {
                        _ = try self.state_stack.pop();
                        const name = try self.element_stack.pop();
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .identifier,
                            .data = .{
                                .identifier = .{
                                    .name = try string_pool.put(source[name.?.data.token.start..name.?.data.token.end]),
                                    .prev = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .identifier));
                    },
                }
            },
            69, 70 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const expression = try self.element_stack.pop();
                const attribute = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .attributed_expression,
                    .data = .{
                        .attributed_expression = .{
                            .attribute = attribute.?.data.node,
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .attributed_expression));
            },
            71 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const body = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .block,
                    .data = .{
                        .block = .{
                            .body = body.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .block));
            },
            72 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expressions = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .wrapped_expressions,
                    .data = .{
                        .wrapped_expressions = .{
                            .expressions = expressions.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .wrapped_expressions));
            },
            73 => {
                switch (tokens[index].kind) {
                    .r_paren => {
                        try self.state_stack.push(90);
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
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(92);
                        index += 1;
                    },
                    else => {
                        _ = try self.state_stack.pop();
                        const parameters = try self.element_stack.pop();
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .function_parameters_optional,
                            .data = .{
                                .function_parameters_optional = .{
                                    .parameters = parameters.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_parameters_optional));
                    },
                }
            },
            76 => {
                _ = try self.state_stack.pop();
                const parameter = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_parameters,
                    .data = .{
                        .function_parameters = .{
                            .parameter = parameter.?.data.node,
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_parameters));
            },
            77 => {
                switch (tokens[index].kind) {
                    .identifier => {
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
                    .r_paren => {
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
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .semicolon => {
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
                switch (tokens[index].kind) {
                    .r_paren => {
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
            82 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const name = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .label_statement,
                    .data = .{
                        .label_statement = .{
                            .expression = null,
                            .name = try string_pool.put(decodeIdentifier(source, name.?.data.token, reporter, io, filename) catch |err| switch (err) {
                                error.DecodeFailed => {
                                    return error.ParseFailed;
                                },
                                else => |_err| {
                                    return @errorCast(_err);
                                },
                            }),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .label_statement));
            },
            83 => {
                switch (tokens[index].kind) {
                    .semicolon => {
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
            84 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const expression = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const expressions = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .expressions,
                    .data = .{
                        .expressions = .{
                            .expression = expression.?.data.node,
                            .prev = expressions.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .expressions));
            },
            85 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .r_paren => {
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
            86 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const identifier = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const identifiers = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .identifier,
                    .data = .{
                        .identifier = .{
                            .name = try string_pool.put(source[identifier.?.data.token.start..identifier.?.data.token.end]),
                            .prev = identifiers.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .identifier));
            },
            87 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(100);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            89 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const attribute = try self.element_stack.pop();
                const name = try self.element_stack.pop();
                const access = try self.element_stack.pop();
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

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .assignment_target));
            },
            90 => {
                switch (tokens[index].kind) {
                    .l_brace => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(102);
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
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .function_attributes_optional,
                            .data = .{
                                .function_attributes_optional = .{
                                    .attributes = null,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_attributes_optional));
                    },
                }
            },
            92 => {
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
            93 => {
                switch (tokens[index].kind) {
                    .colon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(88);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            94 => {
                switch (tokens[index].kind) {
                    .l_brace => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(112);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            95 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expressions = try self.element_stack.pop();
                const target = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .continue_statement,
                    .data = .{
                        .continue_statement = .{
                            .expressions = expressions.?.data.node,
                            .target = try string_pool.put(source[target.?.data.token.start..target.?.data.token.end]),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .continue_statement));
            },
            96 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expressions = try self.element_stack.pop();
                const target = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .break_statement,
                    .data = .{
                        .break_statement = .{
                            .expressions = expressions.?.data.node,
                            .target = try string_pool.put(source[target.?.data.token.start..target.?.data.token.end]),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .break_statement));
            },
            97 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expression = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .runtime_expression,
                    .data = .{
                        .runtime_expression = .{
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .runtime_expression));
            },
            98 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expression = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const label = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .label_statement,
                    .data = .{
                        .label_statement = .{
                            .expression = expression.?.data.node,
                            .name = try string_pool.put(source[label.?.data.token.start..label.?.data.token.end]),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .label_statement));
            },
            99 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expressions = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const target = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .call,
                    .data = .{
                        .call = .{
                            .target = target.?.data.node,
                            .arguments = expressions.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .call));
            },
            100 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expressions = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const target = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .assignment_statement,
                    .data = .{
                        .assignment_statement = .{
                            .expressions = expressions.?.data.node,
                            .target = target.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .assignment_statement));
            },
            101 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const expression = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_attribute,
                    .data = .{
                        .type_attribute = .{
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .type_attribute));
            },
            102 => {
                switch (tokens[index].kind) {
                    .keyword_case => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(113);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            103 => {
                switch (tokens[index].kind) {
                    .l_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(116);
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
                        try self.state_stack.push(117);
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
                        try self.state_stack.push(118);
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

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_body));
                    },
                }
            },
            106 => {
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
                        _ = try self.state_stack.pop();
                        const attributes = try self.element_stack.pop();
                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .function_attributes_optional,
                            .data = .{
                                .function_attributes_optional = .{
                                    .attributes = attributes.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_attributes_optional));
                    },
                }
            },
            107 => {
                _ = try self.state_stack.pop();
                const attribute = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_attributes,
                    .data = .{
                        .function_attributes = .{
                            .attribute = attribute.?.data.node,
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_attributes));
            },
            108, 109 => {
                _ = try self.state_stack.pop();
                const attribute = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_attribute,
                    .data = .{
                        .function_attribute = .{
                            .attribute = attribute.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_attribute));
            },
            110 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const parameter = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const parameters = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_parameters,
                    .data = .{
                        .function_parameters = .{
                            .parameter = parameter.?.data.node,
                            .prev = parameters.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_parameters));
            },
            111 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const attribute = try self.element_stack.pop();
                const name = try self.element_stack.pop();
                const access = try self.element_stack.pop();
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

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_parameter));
            },
            112 => {
                switch (tokens[index].kind) {
                    .identifier => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(121);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            114 => {
                switch (tokens[index].kind) {
                    .r_brace => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(125);
                        index += 1;
                    },
                    .keyword_case => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(113);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            115 => {
                _ = try self.state_stack.pop();
                const case = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .match_cases,
                    .data = .{
                        .match_cases = .{
                            .case = case.?.data.node,
                            .cases = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .match_cases));
            },
            119 => {
                switch (tokens[index].kind) {
                    .percent => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(130);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            120 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const attribute = try self.element_stack.pop();
                const attributes = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_attributes,
                    .data = .{
                        .function_attributes = .{
                            .attribute = attribute.?.data.node,
                            .prev = attributes.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_attributes));
            },
            121 => {
                switch (tokens[index].kind) {
                    .colon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(88);
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

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .type_attribute_optional));
                    },
                }
            },
            122 => {
                switch (tokens[index].kind) {
                    .r_brace => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(133);
                        index += 1;
                    },
                    .identifier => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(121);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            123 => {
                _ = try self.state_stack.pop();
                const entry = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_entries,
                    .data = .{
                        .type_entries = .{
                            .entry = entry.?.data.node,
                            .prev = null,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .type_entries));
            },
            124 => {
                switch (tokens[index].kind) {
                    .colon => {
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
            125 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const cases = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const expression = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .match_expression,
                    .data = .{
                        .match_expression = .{
                            .cases = cases.?.data.node,
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .match_expression));
            },
            126 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const case = try self.element_stack.pop();
                const cases = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .match_cases,
                    .data = .{
                        .match_cases = .{
                            .cases = cases.?.data.node,
                            .case = case.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .match_cases));
            },
            127 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .r_paren => {
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
            128 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .r_paren => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(137);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            129 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    else => {
                        _ = try self.state_stack.pop();
                        _ = try self.state_stack.pop();
                        const expression = try self.element_stack.pop();
                        _ = try self.element_stack.pop();

                        try self.pushASTNode(try self.pool.put(ASTNode{
                            .kind = .function_body,
                            .data = .{
                                .function_body = .{
                                    .expression = expression.?.data.node,
                                },
                            },
                        }));

                        try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_body));
                    },
                }
            },
            130 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const body = try self.element_stack.pop();
                const attributes = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const parameters = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                _ = try self.element_stack.pop();
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

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function));
            },
            131 => {
                switch (tokens[index].kind) {
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
            132 => {
                _ = try self.state_stack.pop();
                const attribute = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_attribute_optional,
                    .data = .{
                        .type_attribute_optional = .{
                            .attribute = attribute.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .type_attribute_optional));
            },
            133 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const entries = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const expression = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type,
                    .data = .{
                        .type = .{
                            .entries = entries.?.data.node,
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .type));
            },
            134 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                const entry = try self.element_stack.pop();
                const entries = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_entries,
                    .data = .{
                        .type_entries = .{
                            .entry = entry.?.data.node,
                            .prev = entries.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .type_entries));
            },
            136 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expression = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                _ = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_external_attribute,
                    .data = .{
                        .function_external_attribute = .{
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_external_attribute));
            },
            137 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expression = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                _ = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .function_internal_attribute,
                    .data = .{
                        .function_internal_attribute = .{
                            .expression = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .function_internal_attribute));
            },
            138 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expression = try self.element_stack.pop();
                const name = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .type_entry,
                    .data = .{
                        .type_entry = .{
                            .expression = expression.?.data.node,
                            .name = try string_pool.put(source[name.?.data.token.start..name.?.data.token.end]),
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .type_entry));
            },
            139 => {
                switch (tokens[index].kind) {
                    .comma => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(61);
                        index += 1;
                    },
                    .semicolon => {
                        try self.pushToken(tokens[index]);
                        try self.state_stack.push(140);
                        index += 1;
                    },
                    else => {
                        try reportUnexpectedToken(reporter, io, filename, tokens[index]);
                        index = try self.skipUntilAcceptable(tokens, index);
                    },
                }
            },
            140 => {
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.state_stack.pop();
                _ = try self.element_stack.pop();
                const expression = try self.element_stack.pop();
                _ = try self.element_stack.pop();
                const condition = try self.element_stack.pop();
                _ = try self.element_stack.pop();

                try self.pushASTNode(try self.pool.put(ASTNode{
                    .kind = .match_case,
                    .data = .{
                        .match_case = .{
                            .expression = condition.?.data.node,
                            .body = expression.?.data.node,
                        },
                    },
                }));

                try self.state_stack.push(getReduceGoto(self.state_stack.top() orelse 255, .match_case));
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
                    index += 1;
                    from = index;
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
                '\\' => {
                    source[write] = '\\';
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
                    from += 1;
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

// Assume the string start with ", end with "
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
                    index += 1;
                    from = index;
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
                '\\' => {
                    source[write] = '\\';
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
                    from += 1;
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
        if (token.start + 1 < source.len and source[token.start + 1] == '"') {
            return try decodeString(source, token, reporter, io, filename);
        } else {
            return source[token.start..token.end];
        }
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
