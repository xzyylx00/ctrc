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
    pub const Kind = enum {
        keyword_in,
        keyword_out,
        keyword_inout,
        keyword_ptr,
        keyword_ref,
        keyword_match,
        keyword_case,
        keyword_function,
        keyword_type,
        keyword_break,
        keyword_continue,
        keyword_nil,
        keyword_external,
        keyword_internal,
        keyword_runtime,

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
        newline,

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
                } else if (std.mem.eql(u8, "case", string)) {
                    return .keyword_case;
                }
            },
            'd' => {},
            'e' => {
                if (std.mem.eql(u8, "external", string)) {
                    return .keyword_external;
                }
            },
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
                } else if (std.mem.eql(u8, "internal", string)) {
                    return .keyword_internal;
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
                } else if (std.mem.eql(u8, "runtime", string)) {
                    return .keyword_runtime;
                }
            },
            's' => {},
            't' => {
                if (std.mem.eql(u8, "type", string)) {
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

    pub fn isKeyword(token: *const Token) bool {
        switch (token.kind) {
            .keyword_in,
            .keyword_out,
            .keyword_inout,
            .keyword_ptr,
            .keyword_ref,
            .keyword_match,
            .keyword_function,
            .keyword_type,
            .keyword_break,
            .keyword_continue,
            .keyword_nil,
            .keyword_case,
            .keyword_external,
            .keyword_internal,
            => return true,
            else => return false,
        }
    }

    kind: Kind,
    start: u32,
    end: u32,
    line: u32,
    pos: u32,
};

const Tokenizer = @This();
buffer: [:0]const u8,
index: u32 = undefined,
pos: u32 = 1,
line: u32 = 1,

const State = enum {
    start,
    identifier,
    invalid,
    commit,
    string,
    string_backslash,
    char,
    char_backslash,
    hash,
    comment,
    macro,

    integer,
    integer_dot,
    integer_exponent,
    float,
    float_exponent,
};

pub fn init(string: [:0]const u8) Tokenizer {
    return Tokenizer{
        .buffer = string,
        .index = if (std.mem.startsWith(u8, string, "\xEF\xBB\xBF")) 3 else 0,
    };
}

pub fn next(tokenizer: *Tokenizer) Token {
    var token = Token{
        .kind = .invalid,
        .start = tokenizer.index,
        .end = tokenizer.index,
        .line = tokenizer.line,
        .pos = tokenizer.pos,
    };

    state: switch (State.start) {
        .start => {
            switch (tokenizer.buffer[tokenizer.index]) {
                '\x00' => {
                    if (tokenizer.index + 1 == tokenizer.buffer.len) {
                        token.kind = .eof;
                        continue :state .commit;
                    }
                    continue :state .invalid;
                },
                ' ', '\t' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    continue :state .start;
                },
                '\r' => {
                    tokenizer.index += 1;
                    continue :state .start;
                },
                '\n' => {
                    token.line = tokenizer.line;
                    token.pos = tokenizer.pos;
                    tokenizer.line += 1;
                    token.kind = .newline;
                    tokenizer.index += 1;
                    tokenizer.pos = 1;
                    continue :state .commit;
                },
                '"' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    continue :state .string;
                },
                '\'' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
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
                '0'...'9' => {
                    token.kind = .integer;
                    continue :state .integer;
                },
                '.' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .dot;
                    continue :state .commit;
                },
                '=' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .equal;
                    continue :state .commit;
                },
                '!' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .bang;
                    continue :state .commit;
                },
                '|' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .pipe;
                    continue :state .commit;
                },
                '(' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .l_paren;
                    continue :state .commit;
                },
                ')' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .r_paren;
                    continue :state .commit;
                },
                '[' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .l_bracket;
                    continue :state .commit;
                },
                ']' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .r_bracket;
                    continue :state .commit;
                },
                '{' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .l_brace;
                    continue :state .commit;
                },
                '}' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .r_brace;
                    continue :state .commit;
                },
                '<' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .l_angle;
                    continue :state .commit;
                },
                '>' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .r_angle;
                    continue :state .commit;
                },
                ';' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .semicolon;
                    continue :state .commit;
                },
                ',' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .comma;
                    continue :state .commit;
                },
                '?' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .q_mark;
                    continue :state .commit;
                },
                ':' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .colon;
                    continue :state .commit;
                },
                '%' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .percent;
                    continue :state .commit;
                },
                '*' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .star;
                    continue :state .commit;
                },
                '+' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .plus;
                    continue :state .commit;
                },
                '-' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .minus;
                    continue :state .commit;
                },
                '^' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .caret;
                    continue :state .commit;
                },
                '/' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .slash;
                    continue :state .commit;
                },
                '\\' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .backslash;
                    continue :state .commit;
                },
                '~' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .tilde;
                    continue :state .commit;
                },
                '&' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    token.kind = .ampersand;
                    continue :state .commit;
                },
            }
        },
        .commit => {
            token.end = tokenizer.index - 1;
            if (token.kind == .identifier and Token.toKeyword(tokenizer.buffer[token.start..token.end])) |kind| {
                token.kind = kind;
            }
            return token;
        },
        .invalid => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            if (tokenizer.buffer[tokenizer.index] == '\x00') {
                token.kind = .eof;
                continue :state .commit;
            } else if (tokenizer.buffer[tokenizer.index] == '\n') {
                token.kind = .invalid;
                continue :state .commit;
            }
        },
        .hash => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
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
                else => {
                    continue :state .invalid;
                },
            }
        },
        .identifier => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                'a'...'z', 'A'...'Z', '_' => {
                    continue :state .identifier;
                },
                else => {
                    if (tokenizer.index - token.start == 1 and tokenizer.buffer[token.start] == '_') {
                        token.kind = .underline;
                    }

                    continue :state .commit;
                },
            }
        },
        .macro => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                'a'...'z', 'A'...'Z', '_' => {
                    continue :state .macro;
                },
                else => {
                    continue :state .commit;
                },
            }
        },
        .string => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                '"' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    continue :state .commit;
                },
                '\\' => {
                    continue :state .string_backslash;
                },
                '\n', '\x00'...'\x08', '\x0b', '\x0c', '\x0e'...'\x1f', '\x7f' => {
                    continue :state .invalid;
                },
                else => {
                    continue :state .string;
                },
            }
        },
        .string_backslash => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                '\n', '\x00'...'\x08', '\x0b', '\x0c', '\x0e'...'\x1f', '\x7f' => {
                    continue :state .invalid;
                },
                else => {
                    continue :state .string;
                },
            }
        },
        .char => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                '\'' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    continue :state .commit;
                },
                '\\' => {
                    continue :state .char_backslash;
                },
                '\n', '\x00'...'\x08', '\x0b', '\x0c', '\x0e'...'\x1f', '\x7f' => {
                    continue :state .invalid;
                },
                else => {
                    continue :state .char;
                },
            }
        },
        .char_backslash => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                '\n', '\x00'...'\x08', '\x0b', '\x0c', '\x0e'...'\x1f', '\x7f' => {
                    continue :state .invalid;
                },
                else => {
                    continue :state .char;
                },
            }
        },
        .comment => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                '\x00' => {
                    if (tokenizer.index + 1 == tokenizer.buffer.len) {
                        continue :state .commit;
                    } else {
                        continue :state .invalid;
                    }
                },
                '\n' => {
                    continue :state .commit;
                },
                '\x01'...'\x08', '\x0b', '\x0c', '\x0e'...'\x1f', '\x7f' => {
                    continue :state .invalid;
                },
                else => {
                    continue :state .comment;
                },
            }
        },
        .integer => {
            switch (tokenizer.buffer[tokenizer.index]) {
                '.' => {
                    continue :state .integer_dot;
                },
                'a'...'d', 'f'...'z', 'A'...'D', 'F'...'Z', '0'...'9', '_' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    continue :state .integer;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .integer_exponent;
                },
                '\n', '\t', '\r', '\x00', ':', ',', ';', ' ', ')' => {
                    continue :state .commit;
                },
                else => {
                    continue :state .invalid;
                },
            }
        },
        .integer_exponent => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                '+', '-' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    continue :state .float;
                },
                else => {
                    continue :state .integer;
                },
            }
        },
        .integer_dot => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                'a'...'d', 'f'...'z', 'A'...'D', 'F'...'Z', '0'...'9', '_' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    continue :state .float;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .float_exponent;
                },
                else => {
                    continue :state .invalid;
                },
            }
        },
        .float => {
            switch (tokenizer.buffer[tokenizer.index]) {
                'a'...'d', 'f'...'z', 'A'...'D', 'F'...'Z', '0'...'9', '_' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                    continue :state .float;
                },
                'e', 'E', 'p', 'P' => {
                    continue :state .float_exponent;
                },
                '\n', '\t', '\r', '\x00', ':', ',', ';', ' ', ')' => {
                    continue :state .commit;
                },
                else => {
                    continue :state .invalid;
                },
            }
        },
        .float_exponent => {
            tokenizer.index += 1;
            tokenizer.pos += 1;

            switch (tokenizer.buffer[tokenizer.index]) {
                '+', '-' => {
                    tokenizer.index += 1;
                    tokenizer.pos += 1;
                },
            }
            continue :state .float;
        },
    }
}
