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

fn writeTabs(count: usize, writer: std.Io.Writer) error{WriteFailed}!void {
    const tabs: [TAB_SIZE * count]u8 = @splat(' ');
    for (0..count) |_| {
        try writer.write(tabs);
    }
}

fn getTokenString(source: [:0]const u8, token: Tokenizer.Token) []const u8 {
    return switch (token.kind) {
        .keyword_break => "break ",
        .keyword_case => "case ",
        .keyword_continue => "continue ",
        .keyword_external => "external",
        .keyword_function => "function",
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
        else => source[token.start..token.end],
    };
}

// Shall be called after the tokens passed Parser.parse().
// Use the origin source string, if string's original format is indeed.
// Or use parser's decoded strings to make all escaped character is in same format.
pub fn format(tokens: []Tokenizer.Token, source: [:0]const u8, io: std.Io, allocator: std.mem.Allocator, writer: std.Io.Writer, filename: u32, reporter: *Error.Reporter) error{ WriteFailed, OutOfMemory, FormatFailed }!void {
    var index: usize = 0;
    var tab: usize = 0;

    var stack: Stack(Tokenizer.Token.Kind, 128) = try .init(allocator);
    defer stack.deinit();

    if (tokens[tokens.len].kind != .eof) {
        try reporter.add(io, .@"error", filename, 1, 1, "Cannot format! End token must be EOF!", .{});
        return error.FormatFailed;
    }

    switch (tokens[index].kind) {
        .l_brace => {
            try writeTabs(tab, writer);
            try writer.write("{\n");
            tab += 1;
            index += 1;
            try stack.push(.l_brace);
        },
        .r_brace => {
            try writeTabs(tab, writer);
            try writer.write("}\n");
            tab -= 1;
            index += 1;
            if (stack.top()) |kind| {
                if (kind != .l_brace) {
                    try reporter.add(io, .@"error", filename, tokens[index].line, tokens[index].pos, "Format failed! Unmatched brace!", .{});
                    return error.FormatFailed;
                } else {
                    _ = stack.pop();
                    if (stack.top()) |top| {
                        switch (top) {
                            .keyword_function, .keyword_match, .keyword_type, .keyword => _ = stack.pop(),
                            else => {},
                        }
                    }
                }
            } else {}
        },
        .keyword_break,
        .keyword_continue,
        .keyword_case,
        .keyword_in,
        .keyword_out,
        .keyword_inout,
        .keyword_ptr,
        .keyword_ref,
        => {
            try writeTabs(tab, writer);
            try writer.write(getTokenString(source, tokens[index]));
            index += 1;
            try stack.push(.keyword_break);
        },
        .identifier => {
            try writeTabs(tab, writer);
            try writer.write(getTokenString(source, tokens[index]));
            index += 1;
        },
    }
}
