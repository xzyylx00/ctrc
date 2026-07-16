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

pub const Token = struct {
    pub const Type = enum {
        none,
        invalid,

        eof,
        eol,

        keyword_in,
        keyword_out,
        keyword_inout,
        keyword_ptr,
        keyword_ref,
        keyword_function,
        keyword_struct,
        keyword_union,
        keyword_enum,
        keyword_defer,
        keyword_errdefer,
        keyword_okdefer,
        keyword_ability,
        keyword_if,
        keyword_else,
        keyword_switch,
        keyword_return,
        keyword_break,
        keyword_continue,
        keyword_for,
        keyword_test,
        keyword_public,
        keyword_private,
        keyword_error,
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

        identifier,
        string,
        char,
        number,
        macro,
        comment,

        pub fn toKeyword(string: []const u8) ?Type {
            switch (string[0]) {
                'a' => {
                    if (std.mem.eql(u8, "ability", string)) {
                        return .keyword_ability;
                    }
                },
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
                'd' => {
                    if (std.mem.eql(u8, "defer", string)) {
                        return .keyword_defer;
                    }
                },
                'e' => {
                    if (std.mem.eql(u8, "enum", string)) {
                        return .keyword_enum;
                    } else if (std.mem.eql(u8, "errdefer", string)) {
                        return .keyword_errdefer;
                    } else if (std.mem.eql(u8, "else", string)) {
                        return .keyword_else;
                    } else if (std.mem.eql(u8, "error", string)) {
                        return .keyword_error;
                    }
                },
                'f' => {
                    if (std.mem.eql(u8, "function", string)) {
                        return .keyword_function;
                    } else if (std.mem.eql(u8, "for", string)) {
                        return .keyword_for;
                    }
                },
                'g' => {},
                'h' => {},
                'i' => {
                    if (std.mem.eql(u8, "in", string)) {
                        return .keyword_in;
                    } else if (std.mem.eql(u8, "inout", string)) {
                        return .keyword_inout;
                    } else if (std.mem.eql(u8, "if", string)) {
                        return .keyword_if;
                    }
                },
                'j' => {},
                'k' => {},
                'l' => {},
                'm' => {},
                'n' => {},
                'o' => {
                    if (std.mem.eql(u8, "out", string)) {
                        return .keyword_out;
                    } else if (std.mem.eql(u8, "okdefer", string)) {
                        return .keyword_okdefer;
                    }
                },
                'p' => {
                    if (std.mem.eql(u8, "ptr", string)) {
                        return .keyword_ptr;
                    } else if (std.mem.eql(u8, "public", string)) {
                        return .keyword_public;
                    } else if (std.mem.eql(u8, "private", string)) {
                        return .keyword_private;
                    }
                },
                'q' => {},
                'r' => {
                    if (std.mem.eql(u8, "return", string)) {
                        return .keyword_return;
                    } else if (std.mem.eql(u8, "ref", string)) {
                        return .keyword_ref;
                    }
                },
                's' => {
                    if (std.mem.eql(u8, "struct", string)) {
                        return .keyword_struct;
                    } else if (std.mem.eql(u8, "switch", string)) {
                        return .keyword_switch;
                    }
                },
                't' => {
                    if (std.mem.eql(u8, "test", string)) {
                        return .keyword_test;
                    }
                },
                'u' => {
                    if (std.mem.eql(u8, "union", string)) {
                        return .keyword_union;
                    } else if (std.mem.eql(u8, "nil", string)) {
                        return .keyword_nil;
                    }
                },
                'v' => {},
                'w' => {},
                'x' => {},
                'y' => {},
                'z' => {},

                else => {},
            }

            return null;
        }
    };

    ilk: Type,
    start: u32,
    end: u32,
    line: u32,
    pos: u32,
};

const Lexer = @This();

buffer: [:0]const u8,
index: u32 = 0,
pos: u32 = 1,
line: u32 = 1,

const State = enum {
    start,
    end,
    newline,
    invalid,

    string,
    string_backslash,
    char,
    char_backslash,
    number,
    number_integer,
    number_integer_exponent,
    number_integer_dot,
    number_float,
    number_float_exponent,
    macro,
    identifier,
    comment,

    backslash,
    hash,
};

pub fn init(string: [:0]const u8) Lexer {
    return Lexer{ .buffer = string, .index = if (std.mem.startsWith(u8, string, "\xEF\xBB\xBF")) 3 else 0 };
}

pub fn next(lex: *Lexer) Token {
    var token: Token = .{
        .ilk = .none,
        .start = lex.index,
        .end = undefined,
        .line = lex.line,
        .pos = lex.pos,
    };

    state: switch (State.start) {
        .start => switch (lex.buffer[lex.index]) {
            0 => {
                if (lex.buffer.len == lex.index) {
                    return .{
                        .ilk = .eof,
                        .start = lex.index,
                        .end = lex.index,
                        .line = lex.line,
                        .pos = lex.pos,
                    };
                } else {
                    continue :state .invalid;
                }
            },
            ' ' => {
                lex.index += 1;
                lex.pos += 1;
                token.pos += 1;
                token.start = lex.index;
                continue :state .start;
            },
            '\n', '\t', '\r' => {
                lex.index += 1;
                lex.pos = 1;
                lex.line += 1;
                token.pos = 1;
                token.line += 1;
                token.start = lex.index;
                continue :state .start;
            },
            '"' => {
                token.ilk = .string;
                lex.pos += 1;
                continue :state .string;
            },
            '\'' => {
                token.ilk = .char;
                lex.pos += 1;
                continue :state .char;
            },
            'a'...'z', 'A'...'Z', '_' => {
                token.ilk = .identifier;
                continue :state .identifier;
            },
            '#' => {
                token.ilk = .hash;
                continue :state .hash;
            },
            '=' => {
                lex.index += 1;
                lex.pos += 1;
                token.ilk = .equal;
            },
            '!' => {
                lex.index += 1;
                lex.pos += 1;
                token.ilk = .bang;
            },
            '|' => {
                lex.index += 1;
                lex.pos += 1;
                token.ilk = .pipe;
            },
            '(' => {
                lex.index += 1;
                lex.pos += 1;
                token.ilk = .l_paren;
            },
            ')' => {
                lex.index += 1;
                lex.pos += 1;
                token.ilk = .r_paren;
            },
            '[' => {
                lex.index += 1;
                lex.pos += 1;
                token.ilk = .l_bracket;
            },
            ']' => {
                lex.index += 1;
                lex.pos += 1;
                token.ilk = .r_bracket;
            },
            ';' => {
                token.ilk = .semicolon;
                lex.pos += 1;
                lex.index += 1;
            },
            ',' => {
                token.ilk = .comma;
                lex.pos += 1;
                lex.index += 1;
            },
            '?' => {
                token.ilk = .q_mark;
                lex.pos += 1;
                lex.index += 1;
            },
            ':' => {
                token.ilk = .colon;
                lex.pos += 1;
                lex.index += 1;
            },
            '%' => {
                token.ilk = .percent;
                lex.pos += 1;
                lex.index += 1;
            },
            '*' => {
                token.ilk = .star;
                lex.pos += 1;
                lex.index += 1;
            },
            '+' => {
                token.ilk = .plus;
                lex.pos += 1;
                lex.index += 1;
            },
            '^' => {
                token.ilk = .caret;
                lex.pos += 1;
                lex.index += 1;
            },
            '\\' => {
                token.ilk = .backslash;
                continue :state .backslash;
            },
            '{' => {
                token.ilk = .l_brace;
                lex.pos += 1;
                lex.index += 1;
            },
            '}' => {
                token.ilk = .r_brace;
                lex.pos += 1;
                lex.index += 1;
            },
            '~' => {
                token.ilk = .tilde;
                lex.pos += 1;
                lex.index += 1;
            },
            '.' => {
                token.ilk = .dot;
                lex.pos += 1;
                lex.index += 1;
            },
            '-' => {
                token.ilk = .minus;
                lex.pos += 1;
                lex.index += 1;
            },
            '/' => {
                token.ilk = .slash;
                lex.pos += 1;
                lex.index += 1;
            },
            '&' => {
                token.ilk = .ampersand;
                lex.pos += 1;
                lex.index += 1;
            },
            '0'...'9' => {
                token.ilk = .number;
                lex.index += 1;
                continue :state .number;
            },
            else => continue :state .invalid,
        },

        .end => {},

        .newline => {
            lex.index += 1;
            switch (lex.buffer[lex.index]) {
                0 => {
                    if (lex.index == lex.buffer.len) {
                        token.ilk = .invalid;
                    } else {
                        continue :state .invalid;
                    }
                },
                '\n' => {
                    lex.index += 1;
                    lex.line += 1;
                    lex.pos = 0;
                    token.start = lex.index;
                    continue :state .start;
                },
                else => continue :state .invalid,
            }
        },

        .invalid => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                0 => if (lex.index == lex.buffer.len) {
                    token.ilk = .invalid;
                } else {
                    continue :state .invalid;
                },
                '\n' => token.ilk = .invalid,
                else => continue :state .invalid,
            }
        },

        .hash => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                0, '\n' => token.ilk = .invalid,
                '!' => {
                    token.ilk = .comment;
                    continue :state .comment;
                },
                '"' => {
                    token.ilk = .identifier;
                    continue :state .string;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    token.ilk = .macro;
                    continue :state .macro;
                },
                else => continue :state .invalid,
            }
        },

        .identifier => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .identifier,
                else => {
                    const identifier = lex.buffer[token.start..lex.index];
                    if (Token.Type.toKeyword(identifier)) |ilk| {
                        token.ilk = ilk;
                    }
                },
            }
        },

        .macro => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .macro,
                else => {},
            }
        },

        .backslash => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                0 => token.ilk = .invalid,
                '\\' => continue :state .backslash,
                '\n' => token.ilk = .invalid,
                else => continue :state .invalid,
            }
        },

        .string => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                0 => {
                    if (lex.index != lex.buffer.len) {
                        continue :state .invalid;
                    } else {
                        token.ilk = .invalid;
                    }
                },
                '\n' => token.ilk = .invalid,
                '\\' => continue :state .string_backslash,
                '"' => {
                    lex.pos += 1;
                    lex.index += 1;
                },
                0x01...0x09, 0x0b...0x1f, 0x7f => {
                    continue :state .invalid;
                },
                else => continue :state .string,
            }
        },

        .string_backslash => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                0, '\n' => token.ilk = .invalid,
                0x01...0x09, 0x0b...0x1f, 0x7f => {
                    continue :state .invalid;
                },
                else => continue :state .string,
            }
        },

        .char => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                0 => {
                    if (lex.index != lex.buffer.len) {
                        continue :state .invalid;
                    } else {
                        token.ilk = .invalid;
                    }
                },
                '\n' => token.ilk = .invalid,
                '\\' => continue :state .char_backslash,
                '\'' => {
                    lex.index += 1;
                    lex.pos += 1;
                },
                0x01...0x09, 0x0b...0x1f, 0x7f => {
                    continue :state .invalid;
                },
                else => continue :state .char,
            }
        },

        .char_backslash => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                0 => {
                    if (lex.index != lex.buffer.len) {
                        continue :state .invalid;
                    } else {
                        token.ilk = .invalid;
                    }
                },
                '\n' => token.ilk = .invalid,
                0x01...0x09, 0x0b...0x1f, 0x7f => {
                    continue :state .invalid;
                },
                else => continue :state .char,
            }
        },

        .comment => {
            lex.index += 1;
            lex.pos += 1;

            switch (lex.buffer[lex.index]) {
                0 => {
                    if (lex.index != lex.buffer.len) {
                        continue :state .invalid;
                    } else return .{
                        .ilk = .eof,
                        .start = lex.index,
                        .end = lex.index,
                        .line = lex.line,
                        .pos = lex.pos,
                    };
                },
                '\n' => {
                    lex.index += 1;
                    lex.pos += 1;
                    token.start = lex.index;
                    continue :state .start;
                },
                '\r' => continue :state .newline,
                0x01...0x09, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                    continue :state .invalid;
                },
                else => continue :state .comment,
            }
        },

        .number => {
            continue :state .number_integer;
        },

        .number_integer => switch (lex.buffer[lex.index]) {
            '.' => continue :state .number_integer_dot,
            '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                lex.index += 1;
                lex.pos += 1;
                continue :state .number_integer;
            },
            'e', 'E', 'p', 'P' => {
                continue :state .number_integer_exponent;
            },
            else => {},
        },
        .number_integer_exponent => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                '-', '+' => {
                    lex.index += 1;
                    lex.pos += 1;
                    continue :state .number_float;
                },
                else => continue :state .number_integer,
            }
        },
        .number_integer_dot => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                    lex.index += 1;
                    lex.pos += 1;
                    continue :state .number_float;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .number_float_exponent;
                },
                else => lex.index -= 1,
            }
        },
        .number_float => switch (lex.buffer[lex.index]) {
            '_', 'a'...'d', 'f'...'o', 'q'...'z', 'A'...'D', 'F'...'O', 'Q'...'Z', '0'...'9' => {
                lex.index += 1;
                lex.pos += 1;
                continue :state .number_float;
            },
            'e', 'E', 'p', 'P' => {
                continue :state .number_float_exponent;
            },
            else => {},
        },
        .number_float_exponent => {
            lex.index += 1;
            lex.pos += 1;
            switch (lex.buffer[lex.index]) {
                '-', '+' => {
                    lex.index += 1;
                    lex.pos += 1;
                    continue :state .number_float;
                },
                else => continue :state .number_float,
            }
        },
    }

    token.end = lex.index;
    return token;
}

pub fn dump(lexer: *Lexer, token: *const Token) void {
    std.log.debug("{d}:{d} {s} \"{s}\"", .{ token.line, token.pos, @tagName(token.ilk), lexer.buffer[token.start..token.end] });
}

fn testLexer(source: [:0]const u8, expected_token_ilks: []const Token.Type) !void {
    var lexer = Lexer.init(source);
    for (expected_token_ilks) |expected_token_ilk| {
        const token = lexer.next();
        try std.testing.expectEqual(expected_token_ilk, token.ilk);
    }

    const last_token = lexer.next();
    try std.testing.expectEqual(Token.Type.eof, last_token.ilk);
    try std.testing.expectEqual(source.len, last_token.start);
    try std.testing.expectEqual(source.len, last_token.end);
}

pub fn dumpLexer(source: [:0]const u8) !void {
    var lexer = Lexer.init(source);

    while (true) {
        const token = lexer.next();
        lexer.dump(&token);
        if (token.ilk == .invalid or token.ilk == .eof) {
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
    try testLexer("#! Comment here", &.{});
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
