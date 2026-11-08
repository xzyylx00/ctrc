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

const Self = @This();
const Pool = @import("Pool.zig").Pool;
const ASTNode = @import("ASTNode.zig");
const StringPool = @import("StringPool.zig");
const Tokenizer = @import("Tokenizer.zig");
const Parser = @import("Parser.zig");
const Error = @import("Error.zig");
const std = @import("std");
pub const ModuleHandle = u32;

pub const ModulePool = Pool(ModuleHandle, Self, 32);

pub const Dependency = struct {
    name: StringPool.StringHandle,
    module: ?ModuleHandle,
    next: ?DependencyHandle,
};

pub const DependencyHandle = u32;

pub const DependencyPool = Pool(DependencyHandle, Dependency, 32);

dependency: ?DependencyHandle,
root_ast_node: ?ASTNode.ASTNodeHandle,
source: [:0]u8,
tokens: []Tokenizer.Token,
filename: u32,

pub fn lex(source: [:0]const u8, filename: u32, allocator: std.mem.Allocator, io: std.Io, reporter: *Error.Reporter) error{ LexedFailed, OutOfMemory }!Self {
    const dupe = try allocator.dupeSentinel(u8, source, 0);
    errdefer allocator.free(dupe);

    var tokenizezr = Tokenizer.init(source);
    const tokens = try tokenizezr.LexedArray(allocator, io, filename, reporter, .{});
    errdefer allocator.free(tokens);

    return Self{
        .root_ast_node = null,
        .dependency = null,
        .filename = filename,
        .source = dupe,
        .tokens = tokens,
    };
}

pub fn parse(module: Self, io: std.Io, reporter: *Error.Reporter, string_pool: *StringPool, parser: *Parser) error{ ParseFailed, OutOfMemory }!void {
    if (module.root_ast_node != null) {
        return error.ParseFailed;
    }

    const root_ast_node = try parser.parse(io, reporter, module.filename, module.tokens, string_pool, module.source);
    module.root_ast_node = root_ast_node;
    module.dependency = null;
}

// pub fn analysis(module: Self, io: std.Io, reportrt)
