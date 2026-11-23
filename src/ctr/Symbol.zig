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
const StringPool = @import("StringPool.zig");
const ASTNode = @import("ASTNode.zig");
const Pool = @import("Pool.zig").Pool;

// Here is a lot of pools:
// StringPool - Standalone
// FunctionParameterPool
// FunctionReturnPool
// MatchCasePool
// SymbolPool

pub const FunctionParameterPool = Pool(FunctionParameterHandle, FunctionParameter, 1024, null);
pub const MatchCasePool = Pool(MatchCaseHandle, MatchCase, 2048, null);
pub const SymbolPool = Pool(SymbolHandle, Self, 8192, null);
pub const TypeConstructEntryPool = Pool(TypeConstructEntryHandle, TypeConstructEntry, 1024, null);
pub const SymbolHandle = u32;

pub const FunctionParameter = struct {
    access: Access,
    next: ?FunctionParameterHandle,
    expression: SymbolHandle,
    name: StringPool.StringHandle,
};

pub const FunctionParameterHandle = u32;

pub const FunctionAttribute = struct {
    external: ?StringPool.StringHandle,
    internal: ?StringPool.StringHandle,
};

pub const MatchCase = struct {
    next: ?MatchCaseHandle,
    condition: SymbolHandle,
    expression: SymbolHandle,
};

pub const MatchCaseHandle = u32;

pub const TypeConstructEntry = struct {
    name: ?StringPool.StringHandle,
    expression: ?SymbolHandle,
};
pub const TypeConstructEntryHandle = u32;

pub const Kind = enum {
    literal,
    function,
    match,
    type,
    label,
    block,
};

const Data = union(Kind) {
    literal: ASTNode.ASTNodeHandle,
    function: struct {
        parameter: ?FunctionParameter,
        attribute: ?FunctionAttribute,
        @"return": ?SymbolHandle,
        expression: ?SymbolHandle,
    },
    match: struct {
        case: ?MatchCaseHandle,
        expression: SymbolHandle,
    },
    type: struct {
        constructor: SymbolHandle,
        list: TypeConstructEntryHandle,
    },
    label: struct {
        name: StringPool.StringHandle,
        expression: SymbolHandle,
    },
    block: void,
    // ?
};

pub const Access = enum {
    in,
    out,
    inout,
    none,
};

name: StringPool.StringHandle,
type: ?SymbolHandle,
data: Data,
access: Access,
runtime: bool,
