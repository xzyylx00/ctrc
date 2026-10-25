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
const StringPool = @import("StringPool.zig");
const ASTNode = @import("ASTNode.zig");
const Symbol = @import("Symbol.zig");
const Tokenizer = @import("Tokenizer.zig");
const Module = @import("Module.zig");

string_pool: StringPool,
symbol_pool: Symbol.SymbolPool,
function_parameter_pool: Symbol.FunctionParameterPool,
module_pool: Module.ModulePool,
dependency_pool: Module.DependencyPool,

pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!Self {
    const string_pool = try StringPool.init(allocator);
    errdefer string_pool.deinit();

    const symbol_pool = try Symbol.SymbolPool.init(allocator);
    errdefer symbol_pool.deinit();

    const module_pool = try Module.ModulePool.init(allocator);
    errdefer module_pool.deinit();

    const dependency_pool = try Module.DependencyPool.init(allocator);
    errdefer dependency_pool.deinit();

    return Self{
        .string_pool = string_pool,
        .symbol_pool = symbol_pool,
        .module_pool = module_pool,
        .dependency_pool = dependency_pool,
    };
}

pub fn deinit(self: *Self) void {
    self.string_pool.deinit();
    self.symbol_pool.deinit();
    self.module_pool.deinit();
    self.dependency_pool.deinit();

    self.* = undefined;
    return;
}

pub fn loadModule(self: *Self, source: [:0]const u8) error{OutOfMemory}!void {}

pub fn resolveModule(self: *Self) error{OutOfMemory}!void {}
