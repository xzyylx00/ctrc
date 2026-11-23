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

ast_node_pool: ASTNode.ASTNodePool,
string_pool: StringPool,
symbol_pool: Symbol.SymbolPool,
function_parameter_pool: Symbol.FunctionParameterPool,
module_pool: Module.ModulePool,
dependency_pool: Module.DependencyPool,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!Self {
    var ast_node_pool = try ASTNode.ASTNodePool.init(allocator);
    errdefer ast_node_pool.deinit();

    var string_pool = try StringPool.init(allocator, 1024);
    errdefer string_pool.deinit();

    var symbol_pool = try Symbol.SymbolPool.init(allocator);
    errdefer symbol_pool.deinit();

    var module_pool = try Module.ModulePool.init(allocator);
    errdefer module_pool.deinit();

    var dependency_pool = try Module.DependencyPool.init(allocator);
    errdefer dependency_pool.deinit();

    var function_parameter_pool = try Symbol.FunctionParameterPool.init(allocator);
    errdefer function_parameter_pool.deinit();

    return Self{
        .string_pool = string_pool,
        .symbol_pool = symbol_pool,
        .module_pool = module_pool,
        .dependency_pool = dependency_pool,
        .ast_node_pool = ast_node_pool,
        .function_parameter_pool = function_parameter_pool,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.string_pool.deinit();
    self.symbol_pool.deinit();
    self.module_pool.deinit();
    self.dependency_pool.deinit();
    self.function_parameter_pool.deinit();
    self.ast_node_pool.deinit();

    self.* = undefined;
    return;
}

pub fn resolveModule(self: *Self, root_module: Module.ModuleHandle) error{OutOfMemory}!void {
    _ = root_module;
    _ = self;
}
