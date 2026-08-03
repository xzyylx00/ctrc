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

const Token = struct {
    const Kind = enum {
        keyword_in,
        keyword_out,
        keyword_inout,
        keyword_ptr,
        keyword_ref,
        keyword_match,
        keyword_function,
        keyword_test,
        keyword_type,
        keyword_break,
        keyword_continue,
        keyword_while,
        keyword_nil,

        colon,
        comma,
        semicolon,
        dot,
        slash,
        backslash,
        hash,
        equal,
        bang,
        pipe,
        plus,
        minus,
        percent,
        star,
        ampersand,
        caret,
        tilde,
        underline,
        q_mark,
        l_bracket,
        r_bracket,
        l_brace,
        r_brace,
        l_paren,
        r_paren,
        l_angle,
        r_angle,

        invalid,
        eof,
        identifier,
        string,
        char,
        float,
        integer,
        macro,
        comment,
    };

    pub fn toKeyword(string: []const u8) ?Kind {
        switch (string[0]) {
            'a' => {},
            'b' => {
                if (std.mem.eql(u8, "break", string)) {
                    return .keyword_break;
                }
            },
            'c' => {
                if (std.mem.eql(u8, "continue", string)) {
                    return .keyword_continue;
                }
            },
            'd' => {},
            'e' => {},
            'f' => {
                if (std.mem.eql(u8, "function", string)) {
                    return .keyword_function;
                }
            },
            'g' => {},
            'h' => {},
            'i' => {
                if (std.mem.eql(u8, "in", string)) {
                    return .keyword_in;
                } else if (std.mem.eql(u8, "inout", string)) {
                    return .keyword_inout;
                }
            },
            'j' => {},
            'k' => {},
            'l' => {},
            'm' => {
                if (std.mem.eql(u8, "match", string)) {
                    return .keyword_match;
                }
            },
            'n' => {
                if (std.mem.eql(u8, "nil", string)) {
                    return .keyword_nil;
                }
            },
            'o' => {
                if (std.mem.eql(u8, "out", string)) {
                    return .keyword_out;
                }
            },
            'p' => {
                if (std.mem.eql(u8, "ptr", string)) {
                    return .keyword_ptr;
                }
            },
            'q' => {},
            'r' => {
                if (std.mem.eql(u8, "ref", string)) {
                    return .keyword_ref;
                }
            },
            's' => {},
            't' => {
                if (std.mem.eql(u8, "test", string)) {
                    return .keyword_test;
                } else if (std.mem.eql(u8, "type", string)) {
                    return .keyword_type;
                }
            },
            'u' => {},
            'v' => {},
            'w' => {},
            'x' => {},
            'y' => {},
            'z' => {},

            else => {},
        }

        return null;
    }

    kind: Kind,
    start: u32,
    end: u32,
    line: u32,
    pos: u32,
};

const Lexer = @This();
buffer: [:0]const u8,
index: u32 = undefined,
pos: u32 = 1,
line: u32 = 1,

const State = enum {
    start,
    invalid,

    string,
    string_backslash,
    char,
    identifier,
    hash,
    comment,
    macro,
    commit,

    number_integer,
    number_integer_dot,
    number_integer_exponent,
    number_float,
    number_float_exponent,
};

pub fn init(string: [:0]const u8) Lexer {
    return Lexer{
        .buffer = string,
        .index = if (std.mem.startsWith(u8, string, "\xEF\xBB\xBF")) 3 else 0,
    };
}

pub fn next(lexer: *Lexer) Token {
    var token: Token = undefined;

    state: switch (State.start) {
        .start => {
            token = .{
                .start = lexer.index,
                .end = undefined,
                .line = lexer.line,
                .pos = lexer.pos,
                .kind = undefined,
            };
            switch (lexer.buffer[lexer.index]) {
                0 => {
                    if (lexer.buffer.len == lexer.index) {
                        token.kind = .eof;
                        continue :state .commit;
                    } else {
                        continue :state .invalid;
                    }
                },
                ' ' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    continue :state .start;
                },
                '\n', '\t', '\r' => {
                    lexer.index += 1;
                    lexer.pos = 1;
                    lexer.line += 1;
                    continue :state .start;
                },
                '"' => {
                    token.kind = .string;
                    lexer.pos += 1;
                    continue :state .string;
                },
                '\'' => {
                    token.kind = .char;
                    lexer.pos += 1;
                    continue :state .char;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    token.kind = .identifier;
                    continue :state .identifier;
                },
                '#' => {
                    token.kind = .hash;
                    continue :state .hash;
                },
                '=' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    token.kind = .equal;
                    continue :state .commit;
                },
                '!' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    token.kind = .bang;
                    continue :state .commit;
                },
                '|' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    token.kind = .pipe;
                    continue :state .commit;
                },
                '(' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    token.kind = .l_paren;
                    continue :state .commit;
                },
                ')' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    token.kind = .r_paren;
                    continue :state .commit;
                },
                '[' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    token.kind = .l_bracket;
                    continue :state .commit;
                },
                ']' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    token.kind = .r_bracket;
                    continue :state .commit;
                },
                ';' => {
                    token.kind = .semicolon;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                ',' => {
                    token.kind = .comma;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '?' => {
                    token.kind = .q_mark;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                ':' => {
                    token.kind = .colon;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '%' => {
                    token.kind = .percent;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '*' => {
                    token.kind = .star;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '+' => {
                    token.kind = .plus;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '^' => {
                    token.kind = .caret;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '\\' => {
                    token.kind = .backslash;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '{' => {
                    token.kind = .l_brace;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '}' => {
                    token.kind = .r_brace;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '~' => {
                    token.kind = .tilde;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '.' => {
                    token.kind = .dot;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '-' => {
                    token.kind = .minus;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '/' => {
                    token.kind = .slash;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '&' => {
                    token.kind = .ampersand;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '<' => {
                    token.kind = .l_angle;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '>' => {
                    token.kind = .r_angle;
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                '0'...'9' => {
                    token.kind = .integer;
                    lexer.index += 1;
                    continue :state .number_integer;
                },
                else => continue :state .invalid,
            }
        },

        .commit => {
            token.end = lexer.index;
            return token;
        },

        .invalid => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                0 => if (lexer.index == lexer.buffer.len) {
                    token.kind = .invalid;
                    continue :state .commit;
                } else {
                    continue :state .invalid;
                },
                '\n' => {
                    token.kind = .invalid;
                    continue :state .commit;
                },
                else => continue :state .invalid,
            }
        },

        .hash => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                0, '\n' => {
                    token.kind = .invalid;
                    continue :state .commit;
                },
                '!' => {
                    token.kind = .comment;
                    continue :state .comment;
                },
                '"' => {
                    token.kind = .identifier;
                    continue :state .string;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    token.kind = .macro;
                    continue :state .macro;
                },
                else => continue :state .invalid,
            }
        },
        .identifier => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .identifier,
                else => {
                    const identifier = lexer.buffer[token.start..lexer.index];
                    if (Token.toKeyword(identifier)) |kind| {
                        token.kind = kind;
                        continue :state .commit;
                    } else {
                        continue :state .commit;
                    }
                },
            }
        },
        .macro => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .macro,
                else => {
                    continue :state .commit;
                },
            }
        },
        .string => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                0 => {
                    continue :state .invalid;
                },
                '\n' => {
                    continue :state .invalid;
                },
                '\\' => continue :state .string_backslash,
                '"' => {
                    lexer.pos += 1;
                    lexer.index += 1;
                    continue :state .commit;
                },
                0x01...0x09, 0x0b...0x1f, 0x7f => {
                    continue :state .invalid;
                },
                else => continue :state .string,
            }
        },
        .string_backslash => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                0, '\n' => {
                    continue :state .invalid;
                },
                0x01...0x09, 0x0b...0x1f, 0x7f => {
                    continue :state .invalid;
                },
                else => continue :state .string,
            }
        },
        .char => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                0 => {
                    if (lexer.index != lexer.buffer.len) {
                        continue :state .invalid;
                    } else {
                        continue :state .invalid;
                    }
                },
                '\n' => {
                    continue :state .invalid;
                },
                '\'' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    continue :state .commit;
                },
                0x01...0x09, 0x0b...0x1f, 0x7f => {
                    continue :state .invalid;
                },
                else => continue :state .char,
            }
        },
        .comment => {
            lexer.index += 1;
            lexer.pos += 1;

            switch (lexer.buffer[lexer.index]) {
                0 => {
                    if (lexer.index != lexer.buffer.len) {
                        continue :state .invalid;
                    } else {
                        continue :state .commit;
                    }
                },
                '\n' => {
                    continue :state .commit;
                },
                '\r' => continue :state .comment,
                0x01...0x09, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                    continue :state .invalid;
                },
                else => continue :state .comment,
            }
        },
        .number_integer => switch (lexer.buffer[lexer.index]) {
            '.' => continue :state .number_integer_dot,
            '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                lexer.index += 1;
                lexer.pos += 1;
                continue :state .number_integer;
            },
            'e', 'E', 'p', 'P' => {
                continue :state .number_integer_exponent;
            },
            ',', ' ', ';', '\t', '\n', '\r' => {
                continue :state .commit;
            },
            else => continue :state .invalid,
        },
        .number_integer_exponent => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                '-', '+' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    continue :state .number_float;
                },
                else => continue :state .number_integer,
            }
        },
        .number_integer_dot => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    continue :state .number_float;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .number_float_exponent;
                },
                ',', ' ', ';', '\t', '\n', '\r' => {
                    continue :state .commit;
                },
                else => continue :state .invalid,
            }
        },
        .number_float => {
            token.kind = .float;
            switch (lexer.buffer[lexer.index]) {
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    continue :state .number_float;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .number_float_exponent;
                },
                ',', ' ', ';', '\t', '\n', '\r' => {
                    continue :state .commit;
                },

                else => continue :state .invalid,
            }
        },
        .number_float_exponent => {
            lexer.index += 1;
            lexer.pos += 1;
            switch (lexer.buffer[lexer.index]) {
                '-', '+' => {
                    lexer.index += 1;
                    lexer.pos += 1;
                    continue :state .number_float;
                },
                else => continue :state .number_float,
            }
        },
    }

    // return token; // for Zig return check
}

pub fn dump(lexer: *Lexer, token: *const Token) void {
    std.log.debug("{d}:{d} {s} \"{s}\"", .{ token.line, token.pos, @tagName(token.kind), lexer.buffer[token.start..token.end] });
}

fn testLexer(source: [:0]const u8, expected_token_kinds: []const Token.Kind) !void {
    var lexer = Lexer.init(source);
    for (expected_token_kinds) |expected_token_kind| {
        const token = lexer.next();
        try std.testing.expectEqual(expected_token_kind, token.kind);
    }

    const last_token = lexer.next();
    try std.testing.expectEqual(Token.Kind.eof, last_token.kind);
    try std.testing.expectEqual(source.len, last_token.start);
    try std.testing.expectEqual(source.len, last_token.end);
}

pub fn dumpLexer(source: [:0]const u8) !void {
    var lexer = Lexer.init(source);

    while (true) {
        const token = lexer.next();
        lexer.dump(&token);
        if (token.kind == .invalid or token.kind == .eof) {
            return;
        }
    }
}

test "keywords" {
    try testLexer("in inout out", &.{
        .keyword_in, .keyword_inout, .keyword_out,
    });
}

test "comment" {
    try testLexer("#! Comment here", &.{.comment});
}

test "strings" {
    try testLexer("\"text test \";", &.{
        .string, .semicolon,
    });

    try testLexer("\'c\';", &.{
        .char,
        .semicolon,
    });
}
