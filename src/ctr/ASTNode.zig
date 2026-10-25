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

const Pool = @import("Pool.zig").Pool;

pub const ASTNodeHandle = u32;
const StringPool = @import("StringPool.zig");
const Self = @This();
pub const ASTNodePool = Pool(ASTNodeHandle, Self);

pub const Kind = enum(u8) {
    module = 0,
    expressions,
    non_attributed_expression,
    wrapped_expressions,
    expression,
    block,
    block_body,
    match_expression,
    match_cases,
    match_case,
    function,
    function_parameters,
    function_parameter,
    function_attributes,
    function_attribute,
    function_internal_attribute,
    function_external_attribute,
    function_body,
    call,
    runtime_expression,
    literal,
    identifier,
    type,
    statements,
    statement,
    call_statement,
    assignment_statement,
    assignment_target,
    continue_statement,
    break_statement,
    label_statement,
    type_attribute_optional,
    type_attribute,
    type_entries,
    type_entry,
    access_attribute,
    pointer_attribute,
    attributed_expression,
};

const Data = union {
    module: struct {
        body: ASTNodeHandle,
    },
    expressions: struct {
        prev: ?ASTNodeHandle,
        expression: ASTNodeHandle,
    },
    non_attributed_expressions: struct {
        expressions: ASTNodeHandle,
    },
    wrapped_expressions: struct {
        expressions: ASTNodeHandle,
    },
    expression: struct {
        expression: ASTNodeHandle,
    },
    block: struct {
        body: ASTNodeHandle,
    },
    block_body: struct {
        statements: ?ASTNodeHandle,
        expression: ASTNodeHandle,
    },
    match_expression: struct {
        expression: ASTNodeHandle,
        cases: ASTNodeHandle,
    },
    match_cases: struct {
        cases: ASTNodeHandle,
        case: ASTNodeHandle,
    },
    match_case: struct {
        expression: ASTNodeHandle,
        body: ASTNodeHandle,
    },
    function: struct {
        parameters: ASTNodeHandle,
        attributes: ASTNodeHandle,
        body: ASTNodeHandle,
    },
    function_parameters: struct {
        prev: ASTNodeHandle,
        parameter: ASTNodeHandle,
    },
    function_parameter: struct {
        access: ASTNodeHandle,
        name: StringPool.StringHandle,
        attribute: ASTNodeHandle,
    },
    function_attributes: struct {
        prev: ASTNodeHandle,
        attribute: ASTNodeHandle,
    },
    function_attribute: struct {
        attribute: ASTNodeHandle,
    },
    function_external_attribute: struct {
        expression: ASTNodeHandle,
    },
    function_internal_attribute: struct {
        expression: ASTNodeHandle,
    },
    function_body: struct {
        expression: ?ASTNodeHandle,
    },
    call: struct {
        target: ASTNodeHandle,
        arguments: ASTNodeHandle,
    },
    runtime_expression: struct {
        expression: ASTNodeHandle,
    },
    literal: struct {
        kind: enum {
            string,
            integer,
            float,
            char,
            identifier,
            macro,
            nil,
        },
        data: union {
            string: StringPool.StringHandle,
            integer: usize,
            float: f64,
            char: u8,
            identifier: ASTNodeHandle,
            macro: StringPool.StringHandle,
            nil: void,
        },
    },
    identifier: struct {
        prev: ?ASTNodeHandle,
        name: StringPool.StringHandle,
    },
    type: struct {
        expression: ASTNodeHandle,
        entries: ASTNodeHandle,
    },
    statements: struct {
        prev: ?ASTNodeHandle,
        statement: ASTNodeHandle,
    },
    statement: struct {
        statement: ASTNodeHandle,
    },
    call_statement: struct {
        call: ASTNodeHandle,
    },
    assignment_statement: struct {
        target: ASTNodeHandle,
        expressions: ASTNodeHandle,
    },
    assignment_target: struct {
        kind: enum {
            literal,
            identifier,
        },
        access: ?ASTNodeHandle,
        name: usize,
        attribute: ?ASTNodeHandle,
    },
    continue_statement: struct {
        target: StringPool.StringHandle,
        expressions: ASTNodeHandle,
    },
    break_statement: struct {
        target: StringPool.StringHandle,
        expressions: ASTNodeHandle,
    },
    label_statement: struct {
        name: StringPool.StringHandle,
        expression: ?ASTNodeHandle,
    },
    type_attribute_optional: struct {
        attribute: ASTNodeHandle,
    },
    type_attribute: struct {
        expression: ASTNodeHandle,
    },
    type_entries: struct {
        prev: ?ASTNodeHandle,
        entry: ASTNodeHandle,
    },
    type_entry: struct {
        name: StringPool.StringHandle,
        expression: ASTNodeHandle,
    },
    access_attribute: struct {
        direction: enum {
            in,
            out,
            inout,
        },
    },
    pointer_attribute: struct {
        kind: enum {
            ptr,
            ref,
        },
    },
    attributed_expression: struct {
        attribute: ASTNodeHandle,
        expression: ASTNodeHandle,
    },
};

kind: Kind,
data: Data,
