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

const Lexer = @import("lexer.zig");

pub const TokenArray = struct {
    tokens: []Lexer.Token,
    _current: ?usize,

    pub fn peek(token_array: *const TokenArray) ?Lexer.Token {
        var local_token_array = token_array.*;
        const token = local_token_array.next();
        if (token.kind == .eof) {
            return null;
        }
        return token;
    }

    pub fn next(token_array: *TokenArray) Lexer.Token {
        if (token_array._current == null) {
            token_array._current = 0;
        } else {
            token_array._current = token_array._current.? + 1;
        }

        if (token_array.tokens[token_array._current.?].kind == .eof) {
            token_array._current = token_array._current.? - 1;
            return token_array.tokens[token_array._current.? + 1];
        } else if (token_array.tokens[token_array._current.?].kind == .invalid) {
            return token_array.tokens[token_array._current.?];
        } else {
            return token_array.tokens[token_array._current.?];
        }
    }

    pub fn skipUntil(lexer: *TokenArray, comptime until: []const Lexer.Token.Kind) void {
        while (true) {
            const token = lexer.next();
            inline for (until) |until_kind| {
                if (token.kind == until_kind or token.kind == .eof) {
                    return;
                }
            }
        }
    }

    pub fn current(lexer: *const TokenArray) ?Lexer.Token {
        if (lexer._current) |__current| {
            return lexer.tokens[__current];
        } else {
            return null;
        }
    }
};
