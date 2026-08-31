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

const ast = @import("ast.zig");
const std = @import("std");

const indent = 4;

inline fn printSpace(_space: u32, writer: *std.Io.Writer) !void {
    for (0.._space) |_| {
        _ = try writer.write(" ");
    }
}

pub fn formatRoot(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    try formatBlockExpressionContent(ast_node_array, source, root_node.data.root.containor, writer, 0);
}

fn formatLabelExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    try formatLiteralExpression(ast_node_array, source, root_node.data.label_expression.label, writer, space + indent);
    _ = try writer.write(": ");
    try formatExpression(ast_node_array, source, root_node.data.label_expression.expression, writer, space);
}

fn formatBlockExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    _ = try writer.write("{\n");
    const root_node = try ast_node_array.get(root_node_index);
    if (root_node.data.block_expression.statement != null) {
        try printSpace(space + indent, writer);
    }
    try formatBlockExpressionContent(ast_node_array, source, root_node_index, writer, space + indent);
    try printSpace(space, writer);
    _ = try writer.write("}");
}

fn formatBlockExpressionContent(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    var current_statement = root_node.data.block_expression.statement;
    while (current_statement) |_current_statement| {
        try formatStatement(ast_node_array, source, _current_statement, writer, space);
        const current_statement_node = try ast_node_array.get(_current_statement);
        current_statement = current_statement_node.data.statement.next;
        if (current_statement != null) {
            try printSpace(space, writer);
        }
    }
    if (indent != 0) {
        try printSpace(space, writer);
    }
    try formatExpression(ast_node_array, source, root_node.data.block_expression.expression, writer, space);
    _ = try writer.write("\n");
}

fn formatAttributedExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write(switch (root_node.data.attributed_expression.kind) {
        .in => "in ",
        .inout => "inout ",
        .out => "out ",
        .ptr => "ptr ",
        .ref => "ref ",
    });

    try formatExpression(ast_node_array, source, root_node.data.attributed_expression.expression, writer, space);
}

fn formatStatement(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    switch (root_node.data.statement.kind) {
        .@"break" => try formatBreakStatement(ast_node_array, source, root_node.data.statement.statement, writer, space),
        .@"continue" => try formatContinueStatement(ast_node_array, source, root_node.data.statement.statement, writer, space),
        .assignment => try formatAssignmentStatement(ast_node_array, source, root_node.data.statement.statement, writer, space),
        .call => try formatCallStatement(ast_node_array, source, root_node.data.statement.statement, writer, space),
        .commented => try formatCommentedStatement(ast_node_array, source, root_node.data.statement.statement, writer, space),
    }
}

fn formatCommentedStatement(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write(source[root_node.data.comment.range.start..root_node.data.comment.range.end]);
    _ = try writer.write("\n");
    if (root_node.data.comment.next) |next| {
        try printSpace(space, writer);
        try formatStatement(ast_node_array, source, next, writer, space);
    }
}

fn formatAssignmentStatement(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    var current_assignment_target: ?usize = root_node.data.assignment_statement.target;
    while (current_assignment_target) |_current_assignment_target| {
        try formatAssignmentTarget(ast_node_array, source, _current_assignment_target, writer, space);
        const currnet_assignment_target_node = try ast_node_array.get(_current_assignment_target);
        current_assignment_target = currnet_assignment_target_node.data.assignment_target.next;
    }
    _ = try writer.write(" = ");
    try formatExpression(ast_node_array, source, root_node.data.assignment_statement.expression, writer, space);
    _ = try writer.write(";\n");
}

fn formatExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    switch (root_node.kind) {
        .expression => try formatSingleExpression(ast_node_array, source, root_node_index, writer, space),
        .multiple_expression => try formatMultipleExpression(ast_node_array, source, root_node_index, writer, space),
        else => unreachable,
    }
}

fn formatCallExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    try formatLiteralExpression(ast_node_array, source, root_node.data.call_expression.target, writer, space);
    _ = try writer.write("(");
    var current_call_parameter = root_node.data.call_expression.parameter;
    while (current_call_parameter) |_current_call_parameter| {
        try formatCallParameter(ast_node_array, source, _current_call_parameter, writer, space);
        const current_call_parameter_node = try ast_node_array.get(_current_call_parameter);
        current_call_parameter = current_call_parameter_node.data.call_parameter.next;
    }
    _ = try writer.write(")");
}

fn formatCallStatement(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    try formatCallExpression(ast_node_array, source, root_node.data.call_statement.call_expression, writer, space);
    _ = try writer.write(";\n");
}

fn formatCallParameter(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    try formatExpression(ast_node_array, source, root_node.data.call_parameter.expression, writer, space + indent);
    if (root_node.data.call_parameter.next != null) {
        _ = try writer.write(", ");
    }
}

fn formatTypeExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write("type (");
    try formatExpression(ast_node_array, source, root_node.data.type_expression.kind, writer, space + indent);
    _ = try writer.write(") {\n");
    var current_type_entry = root_node.data.type_expression.entry;
    if (current_type_entry != null) {
        try printSpace(space + indent, writer);
        while (current_type_entry) |_current_type_entry| {
            try formatTypeEntry(ast_node_array, source, _current_type_entry, writer, space + indent);
            const current_type_entry_node = try ast_node_array.get(_current_type_entry);
            current_type_entry = current_type_entry_node.data.type_entry.next;
        }
    }
    try printSpace(space, writer);
    _ = try writer.write("}");
}

fn formatTypeEntry(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write(source[root_node.data.type_entry.name.start..root_node.data.type_entry.name.end]);
    if (root_node.data.type_entry.expression) |expression| {
        _ = try writer.write(": ");
        try formatExpression(ast_node_array, source, expression, writer, space);
    }
    _ = try writer.write(",\n");
    if (root_node.data.type_entry.next != null) {
        try printSpace(space, writer);
    }
}

fn formatFunctionExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write("function (");
    var current_function_parameter = root_node.data.function_expression.parameter;
    while (current_function_parameter) |_current_function_parameter| {
        try formatFunctionParameter(ast_node_array, source, _current_function_parameter, writer, space + indent);
        const current_function_parameter_node = try ast_node_array.get(_current_function_parameter);
        current_function_parameter = current_function_parameter_node.data.function_parameter.next;
    }
    _ = try writer.write(")");

    var current_attribute = root_node.data.function_expression.attribute;
    while (current_attribute) |_current_attribute| {
        try formatFunctionAttribute(ast_node_array, source, _current_attribute, writer, space + indent);
        const current_attribute_node = try ast_node_array.get(_current_attribute);
        current_attribute = current_attribute_node.data.function_attribute.next;
    }

    if (root_node.data.function_expression.expression) |expression| {
        try formatExpression(ast_node_array, source, expression, writer, space);
    }
}

fn formatFunctionParameter(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write(switch (root_node.data.function_parameter.access_attribute) {
        .in => "in ",
        .inout => "inout ",
        .out => "out ",
    });
    _ = try writer.write(source[root_node.data.function_parameter.name.start..root_node.data.function_parameter.name.end]);
    _ = try writer.write(": ");
    try formatExpression(ast_node_array, source, root_node.data.function_parameter.expression, writer, space + indent);
    if (root_node.data.function_parameter.next != null) {
        _ = try writer.write(", ");
    }
}

fn formatFunctionAttribute(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write(switch (root_node.data.function_attribute.kind) {
        .external => " external(",
        .internal => " internal(",
    });
    if (root_node.data.function_attribute.expression) |expression| {
        try formatSingleExpression(ast_node_array, source, expression, writer, space);
    }
    _ = try writer.write(") ");
}

fn formatMatchExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write("match (");
    try formatExpression(ast_node_array, source, root_node.data.match_expression.expression, writer, space + indent);
    _ = try writer.write(") {\n");
    var current_case = root_node.data.match_expression.case;
    while (current_case) |_current_case| {
        try printSpace(space + indent, writer);
        try formatMatchCase(ast_node_array, source, _current_case, writer, space + indent);
        const current_case_node = try ast_node_array.get(_current_case);
        current_case = current_case_node.data.match_case.next;
    }
    try printSpace(space, writer);
    _ = try writer.write("}");
}

fn formatMatchCase(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write("case ");
    try formatLabelExpression(ast_node_array, source, root_node.data.match_case.expression, writer, space + indent);
    _ = try writer.write(";\n");
}

fn formatBreakStatement(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write("break ");
    _ = try writer.write(source[root_node.data.break_statement.name.start..root_node.data.break_statement.name.end]);
    _ = try writer.write(" ");
    try formatExpression(ast_node_array, source, root_node.data.break_statement.expression, writer, space + indent);
    _ = try writer.write(";\n");
}

fn formatContinueStatement(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write("continue ");
    _ = try writer.write(source[root_node.data.continue_statement.name.start..root_node.data.continue_statement.name.end]);
    _ = try writer.write(" ");
    try formatExpression(ast_node_array, source, root_node.data.continue_statement.expression, writer, space + indent);
    _ = try writer.write(";\n");
}

fn formatLiteralExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    _ = space;
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write(source[root_node.data.literal_expression.position.start..root_node.data.literal_expression.position.end]);
}

fn formatAssignmentTarget(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    _ = space;
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write(switch (root_node.data.assignment_target.access_attribute) {
        .in => "in ",
        .inout => "inout ",
        .none => "",
        .out => "out ",
    });
    _ = try writer.write(source[root_node.data.assignment_target.name.start..root_node.data.assignment_target.name.end]);
    if (root_node.data.assignment_target.next != null) {
        _ = try writer.write(", ");
    }
}

fn formatSingleExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    switch (root_node.data.expression.kind) {
        .attributed => try formatAttributedExpression(ast_node_array, source, root_node.data.expression.expression, writer, space),
        .block => try formatBlockExpression(ast_node_array, source, root_node.data.expression.expression, writer, space),
        .call => try formatCallExpression(ast_node_array, source, root_node.data.expression.expression, writer, space),
        .commented => try formatCommentedSingleExpression(ast_node_array, source, root_node.data.expression.expression, writer, space),
        .function => try formatFunctionExpression(ast_node_array, source, root_node.data.expression.expression, writer, space),
        .label => try formatLabelExpression(ast_node_array, source, root_node.data.expression.expression, writer, space),
        .literal => try formatLiteralExpression(ast_node_array, source, root_node.data.expression.expression, writer, space),
        .match => try formatMatchExpression(ast_node_array, source, root_node.data.expression.expression, writer, space),
        .type => try formatTypeExpression(ast_node_array, source, root_node.data.expression.expression, writer, space),
    }
}

fn formatMultipleExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    try formatSingleExpression(ast_node_array, source, root_node.data.multiple_expression.expression, writer, space);
    if (root_node.data.multiple_expression.next) |next| {
        _ = try writer.write(", ");
        try formatMultipleExpression(ast_node_array, source, next, writer, space);
    }
}

fn formatCommentedSingleExpression(ast_node_array: *const ast.ASTNodeArray, source: []const u8, root_node_index: usize, writer: *std.Io.Writer, space: u32) anyerror!void {
    const root_node = try ast_node_array.get(root_node_index);
    _ = try writer.write(source[root_node.data.comment.range.start..root_node.data.comment.range.end]);
    _ = try writer.write("\n");
    try printSpace(space, writer);
    if (root_node.data.comment.next) |next| {
        try formatSingleExpression(ast_node_array, source, next, writer, space);
    }
}
