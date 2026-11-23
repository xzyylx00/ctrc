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
const Tokenizer = @import("Tokenizer.zig");
const Stack = @import("Stack.zig").Stack;
const Error = @import("Error.zig");

const TAB_SIZE = 4;

fn writeTabs(count: usize, writer: *std.Io.Writer) error{WriteFailed}!void {
    const tabs: [TAB_SIZE]u8 = @splat(' ');
    for (0..count) |_| {
        _ = try writer.write(&tabs);
    }
}

fn encodeString(allocator: std.mem.Allocator, source: [:0]const u8, token: Tokenizer.Token) error{OutOfMemory}![]const u8 {
    _ = allocator;
    return source[token.start..token.end];
}

fn encodeChar(allocator: std.mem.Allocator, source: [:0]const u8, token: Tokenizer.Token) error{OutOfMemory}![]const u8 {
    _ = allocator;
    return source[token.start..token.end];
}

fn encodeInteger(allocator: std.mem.Allocator, source: [:0]const u8, token: Tokenizer.Token) error{OutOfMemory}![]const u8 {
    _ = allocator;
    return source[token.start..token.end];
}

fn encodeFloat(allocator: std.mem.Allocator, source: [:0]const u8, token: Tokenizer.Token) error{OutOfMemory}![]const u8 {
    _ = allocator;
    return source[token.start..token.end];
}

fn encodeIdentifier(allocator: std.mem.Allocator, source: [:0]const u8, token: Tokenizer.Token) error{OutOfMemory}![]const u8 {
    _ = allocator;
    return source[token.start..token.end];
}

fn getTokenString(source: [:0]const u8, token: Tokenizer.Token, allocator: std.mem.Allocator) error{OutOfMemory}![]const u8 {
    return switch (token.kind) {
        .keyword_break => "break ",
        .keyword_case => "case ",
        .keyword_continue => "continue ",
        .keyword_external => "external",
        .keyword_function => "function ",
        .keyword_in => "in ",
        .keyword_inout => "inout ",
        .keyword_internal => "internal ",
        .keyword_match => "match",
        .keyword_nil => "nil",
        .keyword_out => "out ",
        .keyword_ptr => "ptr ",
        .keyword_ref => "ref ",
        .keyword_runtime => "runtime",
        .keyword_type => "type",
        .string => try encodeString(allocator, source, token),
        .char => try encodeChar(allocator, source, token),
        .integer => try encodeInteger(allocator, source, token),
        .float => try encodeFloat(allocator, source, token),
        .identifier => try encodeInteger(allocator, source, token),
        .colon => ": ",
        .comma => ", ",
        .equal => " = ",
        else => source[token.start..token.end],
    };
}

// Shall be called after the tokens passed Parser.parse().
// Use the origin source string, if string's original format is indeed.
// Or use parser's decoded strings to make all escaped character is in same format.
pub fn format(tokens: []Tokenizer.Token, source: [:0]const u8, io: std.Io, allocator: std.mem.Allocator, writer: *std.Io.Writer, filename: u32, reporter: *Error.Reporter) error{ WriteFailed, OutOfMemory, FormatFailed }!void {
    var index: usize = 0;
    var tab: usize = 0;

    var stack = try Stack(Tokenizer.Token.Kind, 1024).init(allocator);
    defer stack.deinit();

    if (tokens.len < 1) {
        try reporter.add(io, .@"error", filename, 1, 1, "Cannot format! Cannot fommat a empty token stream!", .{});
        return error.FormatFailed;
    }

    if (tokens[tokens.len - 1].kind != .eof) {
        try reporter.add(io, .@"error", filename, 1, 1, "Cannot format! End token must be EOF!", .{});
        return error.FormatFailed;
    }

    var newline: bool = false;
    while (true) {
        switch (tokens[index].kind) {
            .l_brace => {
                try writeTabs(tab, writer);
                _ = try writer.write("{\n");
                tab += 1;
                index += 1;
                newline = true;
            },
            .r_brace => {
                _ = try writer.write("\n");
                tab -= 1;
                try writeTabs(tab, writer);
                _ = try writer.write("}");
                index += 1;
                newline = true;
            },
            .keyword_break,
            .keyword_continue,
            .keyword_case,
            .keyword_in,
            .keyword_out,
            .keyword_inout,
            .keyword_ptr,
            .keyword_ref,
            .keyword_external,
            .keyword_function,
            .keyword_internal,
            .keyword_match,
            .keyword_nil,
            .keyword_runtime,
            .keyword_type,
            => {
                try writeTabs(tab, writer);
                _ = try writer.write(try getTokenString(source, tokens[index], allocator));
                index += 1;
            },

            .comment => {
                try writeTabs(tab, writer);
                _ = try writer.write(try getTokenString(source, tokens[index], allocator));
                _ = try writer.write("\n");
                newline = true;
                index += 1;
            },
            .semicolon => {
                if (index + 1 < tokens.len) {
                    if (tokens[index + 1].kind != .comment) {
                        _ = try writer.write(try getTokenString(source, tokens[index], allocator));
                        _ = try writer.write("\n");
                        newline = true;
                    } else {
                        _ = try writer.write(try getTokenString(source, tokens[index], allocator));
                    }
                } else {
                    _ = try writer.write(try getTokenString(source, tokens[index], allocator));
                    _ = try writer.write("\n");
                    newline = true;
                }

                index += 1;
            },
            .eof => {
                break;
            },
            else => {
                if (newline) {
                    try writeTabs(tab, writer);
                    newline = false;
                }
                _ = try writer.write(try getTokenString(source, tokens[index], allocator));
                index += 1;
            },
        }
    }
}
