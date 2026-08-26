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

const Module = @import("module.zig");
const _error = @import("error.zig");
const aslib = @import("aslib");
const std = @import("std");

pub const ASTNode = struct {
    pub const Kind = enum {
        root,
        label_expression,
        block_expression,
        attributed_expression,
        statement,
        assignment_statement,
        expression,
        call_expression,
        call_statement,
        call_parameter,
        comment,
        type_expression,
        type_entry,
        function_expression,
        function_parameter,
        function_attribute,
        match_expression,
        match_case,
        break_statement,
        continue_statement,
        literal_expression,
        assignment_target,
        multiple_expression,
    };

    const Root = struct {
        containor: usize,
    };

    const AssignmentTarget = struct {
        const Name = struct {
            start: usize,
            end: usize,
        };
        const AccessAttribute = enum {
            in,
            out,
            inout,
            none,
        };
        access_attribute: AccessAttribute,
        name: Name,
        next: ?usize,
    };

    const AssignmentStatement = struct {
        target: usize,
        expression: usize,
    };

    const CallStatement = struct {
        call_expression: usize,
    };

    const CallExpression = struct {
        target: usize,
        parameter: ?usize,
    };

    const CallParameter = struct {
        expression: usize,
        next: ?usize,
    };

    const Comment = struct {
        line: usize,
        range: Module.Range,
        next: ?usize,
    };

    const BlockExpression = struct {
        statement: ?usize,
        expression: usize,
    };

    const LiteralExpression = struct {
        const LiteralKind = enum {
            string,
            char,
            integer,
            float,
            nil,
            macro,
            underline,
            identifier,
        };

        kind: LiteralKind,
        position: Module.Range,
    };

    const TypeExpression = struct {
        kind: usize,
        entry: ?usize,
    };

    const TypeEntry = struct {
        name: Module.Range,
        expression: ?usize,
        next: ?usize,
    };

    const AttributedExpression = struct {
        const AttributeKind = enum {
            in,
            out,
            inout,
            ref,
            ptr,
        };

        kind: AttributeKind,
        expression: usize,
    };

    const Statement = struct {
        const StatementKind = enum {
            assignment,
            call,
            commented,
            @"break",
            @"continue",
        };

        kind: StatementKind,
        statement: usize,
        next: ?usize,
    };

    const Expression = struct {
        const ExpressionKind = enum {
            call,
            function,
            type,
            block,
            match,
            literal,
            label,
            attributed,
            commented,
        };

        kind: ExpressionKind,
        expression: usize,
    };

    const FunctionExpression = struct {
        parameter: ?usize,
        expression: ?usize,
        attribute: ?usize,
    };

    const FunctionParameter = struct {
        const AccessAttribute = enum {
            in,
            out,
            inout,
        };

        access_attribute: AccessAttribute,
        name: Module.Range,
        expression: usize,
        next: ?usize,
    };

    const FunctionAttribute = struct {
        const AttributeKind = enum {
            external,
            internal,
        };

        const ExternalAttribute = struct {
            expression: usize,
        };

        const InternalAttribute = struct {
            expression: usize,
        };

        kind: AttributeKind,
        expression: ?usize,
        next: ?usize,
    };

    const LabelExpression = struct {
        label: usize,
        expression: usize,
    };

    const BreakStatement = struct {
        name: Module.Range,
        expression: usize,
    };

    const ContinueStatement = struct {
        name: Module.Range,
        expression: usize,
    };

    const MatchExpression = struct {
        expression: usize,
        case: ?usize,
    };

    const MatchCase = struct {
        expression: usize, // Use label expression
        next: ?usize,
    };

    const MultipleExpression = struct {
        expression: usize,
        next: ?usize,
    };

    kind: Kind,
    data: union {
        root: Root,
        label_expression: LabelExpression,
        block_expression: BlockExpression,
        statement: Statement,
        assignment_statement: AssignmentStatement,
        assignment_target: AssignmentTarget,
        break_statement: BreakStatement,
        continue_statement: ContinueStatement,
        call_statement: CallStatement,
        call_expression: CallExpression,
        call_parameter: CallParameter,
        expression: Expression,
        type_expression: TypeExpression,
        type_entry: TypeEntry,
        literal_expression: LiteralExpression,
        function_expression: FunctionExpression,
        function_parameter: FunctionParameter,
        function_attribute: FunctionAttribute,
        match_expression: MatchExpression,
        match_case: MatchCase,
        attributed_expression: AttributedExpression,
        multiple_expression: MultipleExpression,
        comment: Comment,
    },
    position: Module.Position,
};

pub const ASTNodeArray = aslib.array.StableIndexArrayUnmanaged(ASTNode);

pub fn dump(ast_node_array: *ASTNodeArray, source: [:0]const u8, root_node_index: usize, space: u32) error{OutOfRange}!void {
    const indent = 2;
    // @breakpoint();
    const root_node = try ast_node_array.get(root_node_index);

    const printSpace = struct {
        pub fn printSpace(_space: u32) void {
            for (0.._space) |_| {
                std.debug.print(" ", .{});
            }
        }
    }.printSpace;

    printSpace(space);

    // std.debug.print("{d}:{any}", .{ root_node_index, root_node.kind });

    switch (root_node.kind) {
        .assignment_statement => {
            std.debug.print("Assignment Statement:\n", .{});
            try dump(ast_node_array, source, root_node.data.assignment_statement.target, space + indent);
            try dump(ast_node_array, source, root_node.data.assignment_statement.expression, space + indent);
        },
        .assignment_target => {
            std.debug.print("Assignment Target:\n", .{});
            printSpace(space + indent);
            std.debug.print("Access Attribute: {s}\n", .{
                switch (root_node.data.assignment_target.access_attribute) {
                    .in => "in",
                    .inout => "inout",
                    .out => "out",
                    .none => "none",
                },
            });
            printSpace(space + indent);
            std.debug.print("Name: {s}\n", .{source[root_node.data.assignment_target.name.start..root_node.data.assignment_target.name.end]});
            if (root_node.data.assignment_target.next) |next| {
                return try dump(ast_node_array, source, next, space);
            }
        },
        .block_expression => {
            std.debug.print("Block Expression:\n", .{});
            var current_statement = root_node.data.block_expression.statement;
            while (current_statement) |_current_statement| {
                const current_statement_node = try ast_node_array.get(_current_statement);
                try dump(ast_node_array, source, _current_statement, space + indent);
                current_statement = current_statement_node.data.statement.next;
            }
            try dump(ast_node_array, source, root_node.data.block_expression.expression, space + indent);
        },
        .call_expression => {
            std.debug.print("Call Expression:\n", .{});
            printSpace(space + indent);
            std.debug.print("Target:\n", .{});
            try dump(ast_node_array, source, root_node.data.call_expression.target, space + indent * 2);
            var current_parameter = root_node.data.call_expression.parameter;
            while (current_parameter) |_current_parameter| {
                const current_parameter_node = try ast_node_array.get(_current_parameter);
                try dump(ast_node_array, source, _current_parameter, space + indent);
                current_parameter = current_parameter_node.data.call_parameter.next;
            }
        },
        .call_parameter => {
            std.debug.print("Call Parameter:\n", .{});
            try dump(ast_node_array, source, root_node.data.call_parameter.expression, space + indent);
        },
        .call_statement => {
            std.debug.print("Call Statement:\n", .{});
            try dump(ast_node_array, source, root_node.data.call_statement.call_expression, space + indent);
        },
        .expression => {
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, root_node.data.expression.expression, space + indent);
        },
        .literal_expression => {
            std.debug.print("Literal Expression:\n", .{});
            printSpace(space + indent);
            std.debug.print("{s}: {s}\n", .{
                switch (root_node.data.literal_expression.kind) {
                    .char => "char",
                    .float => "float",
                    .identifier => "identifier",
                    .integer => "integer",
                    .string => "string",
                    .macro => "macro",
                    .underline => "underline",
                    .nil => "nil",
                },
                source[root_node.data.literal_expression.position.start..root_node.data.literal_expression.position.end],
            });
        },
        .root => {
            std.debug.print("Root:\n", .{});
            try dump(ast_node_array, source, root_node.data.root.containor, space + indent);
        },
        .statement => {
            std.debug.print("Statement:\n", .{});
            try dump(ast_node_array, source, root_node.data.statement.statement, space + indent);
        },
        .function_expression => {
            std.debug.print("Function Expression:\n", .{});
            var current_parameter = root_node.data.function_expression.parameter;
            while (current_parameter) |_current_parameter| {
                const current_parameter_node = try ast_node_array.get(_current_parameter);
                try dump(ast_node_array, source, _current_parameter, space + indent);
                current_parameter = current_parameter_node.data.function_parameter.next;
            }

            if (root_node.data.function_expression.expression) |expression| {
                try dump(ast_node_array, source, expression, space + indent);
            }

            var current_attribute = root_node.data.function_expression.attribute;
            while (current_attribute) |_current_attribute| {
                const current_attribute_node = try ast_node_array.get(_current_attribute);
                try dump(ast_node_array, source, _current_attribute, space + indent);
                current_attribute = current_attribute_node.data.function_attribute.next;
            }

            if (root_node.data.function_expression.expression) |expression| {
                try dump(ast_node_array, source, expression, space + indent);
            }
        },
        .function_parameter => {
            std.debug.print("Function Parameter:\n", .{});
            printSpace(space + indent);
            std.debug.print("Access Attribute: {s}\n", .{
                switch (root_node.data.function_parameter.access_attribute) {
                    .in => "in",
                    .inout => "inout",
                    .out => "out",
                },
            });
            printSpace(space + indent);
            std.debug.print("Name: {s}\n", .{source[root_node.data.function_parameter.name.start..root_node.data.function_parameter.name.end]});
            try dump(ast_node_array, source, root_node.data.function_parameter.expression, space + indent * 2);
        },
        .function_attribute => {
            std.debug.print("Function Attribute: ", .{});
            std.debug.print("{s}\n", .{
                switch (root_node.data.function_attribute.kind) {
                    .internal => "internal",
                    .external => "external",
                },
            });

            if (root_node.data.function_attribute.expression) |expression| {
                try dump(ast_node_array, source, expression, space + indent * 2);
            }
        },
        .type_entry => {
            std.debug.print("Type Entry:\n", .{});

            printSpace(space + indent);
            std.debug.print("Name: {s}\n", .{source[root_node.data.type_entry.name.start..root_node.data.type_entry.name.end]});

            if (root_node.data.type_entry.expression) |expression| {
                printSpace(space + indent);
                std.debug.print("Expression:\n", .{});
                try dump(ast_node_array, source, expression, space + indent * 2);
            }

            if (root_node.data.type_entry.next) |next| {
                return try dump(ast_node_array, source, next, space);
            }
        },
        .type_expression => {
            std.debug.print("Type Expression:\n", .{});

            printSpace(space + indent);
            std.debug.print("Type Constuctor:\n", .{});
            try dump(ast_node_array, source, root_node.data.type_expression.kind, space + indent * 2);
            if (root_node.data.type_expression.entry) |entry| {
                printSpace(space + indent);
                std.debug.print("Entry:\n", .{});
                try dump(ast_node_array, source, entry, space + indent * 2);
            }
        },
        .break_statement => {
            std.debug.print("Break Statement:\n", .{});

            printSpace(space + indent);
            std.debug.print("Target: {s}\n", .{source[root_node.data.break_statement.name.start..root_node.data.break_statement.name.end]});
            printSpace(space + indent);
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, root_node.data.break_statement.expression, space + indent * 2);
        },
        .continue_statement => {
            std.debug.print("Continue Statement:\n", .{});

            printSpace(space + indent);
            std.debug.print("Target: {s}\n", .{source[root_node.data.continue_statement.name.start..root_node.data.continue_statement.name.end]});
            printSpace(space + indent);
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, root_node.data.continue_statement.expression, space + indent * 2);
        },
        .label_expression => {
            std.debug.print("Label Expression:\n", .{});

            printSpace(space + indent);
            std.debug.print("Label:\n", .{});
            try dump(ast_node_array, source, root_node.data.label_expression.label, space + indent * 2);
            printSpace(space + indent);
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, root_node.data.label_expression.expression, space + indent * 2);
        },
        .match_case => {
            std.debug.print("Match Case:\n", .{});

            const internal_label_expression = try ast_node_array.get(root_node.data.match_case.expression);
            // XXX Don't forget Match Case use Label Expression's internal data!

            printSpace(space + indent);
            std.debug.print("Case:\n", .{});
            try dump(ast_node_array, source, internal_label_expression.data.label_expression.label, space + indent * 2);
            printSpace(space + indent);
            std.debug.print("Expression:\n", .{});
            try dump(ast_node_array, source, internal_label_expression.data.label_expression.expression, space + indent * 2);
        },
        .match_expression => {
            std.debug.print("Match Expression:\n", .{});

            printSpace(space + indent);
            std.debug.print("Condition:\n", .{});
            try dump(ast_node_array, source, root_node.data.match_expression.expression, space + indent * 2);

            var current_case_node_index = root_node.data.match_expression.case;
            while (current_case_node_index) |_current_case_node_index| {
                const current_case_node = try ast_node_array.get(_current_case_node_index);
                try dump(ast_node_array, source, _current_case_node_index, space + indent * 2);
                current_case_node_index = current_case_node.data.match_case.next;
            }
        },
        .attributed_expression => {
            std.debug.print("Attributed Expression:\n", .{});
            printSpace(space + indent);
            std.debug.print("Attrubute: {s}\n", .{
                switch (root_node.data.attributed_expression.kind) {
                    .in => "in",
                    .inout => "inout",
                    .out => "out",
                    .ptr => "ptr",
                    .ref => "ref",
                },
            });

            try dump(ast_node_array, source, root_node.data.attributed_expression.expression, space + indent);
        },
        .multiple_expression => {
            std.debug.print("Multiple Expression:\n", .{});

            var current_expression_node_index: ?usize = root_node_index;
            while (current_expression_node_index) |_current_expression_node_index| {
                const current_expression_node = try ast_node_array.get(_current_expression_node_index);
                try dump(ast_node_array, source, current_expression_node.data.multiple_expression.expression, space + indent);
                current_expression_node_index = current_expression_node.data.multiple_expression.next;
            }
        },
        .comment => {
            std.debug.print("Comment: {s}\n", .{source[root_node.data.comment.range.start..root_node.data.comment.range.end]});
            if (root_node.data.comment.next) |next| {
                try dump(ast_node_array, source, next, space);
            }
        },
    }
}

pub fn simplify(ast_node_array: *ASTNodeArray, error_report_array: *_error.ErrorReportArray, root_node_index: ?usize) error{ OutOfRange, OutOfCapacity }!?usize {
    if (root_node_index == null) {
        return null;
    }
    const root_node = try ast_node_array.get(root_node_index.?);
    var invalid = false;
    switch (root_node.kind) {
        .assignment_statement => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.assignment_statement.expression);
            const target = try simplify(ast_node_array, error_report_array, root_node.data.assignment_statement.target);

            if (expression == null) {
                try error_report_array.addExpectedLiteralExpressionReport(root_node.position);
                invalid = true;
            } else if (target == null) {
                try error_report_array.addExpectedLiteralExpressionReport(root_node.position);
                invalid = true;
            }

            if (invalid == true) {
                return null;
            }

            const new_node = ASTNode{
                .data = .{
                    .assignment_statement = .{
                        .expression = expression.?,
                        .target = target.?,
                    },
                },
                .kind = .assignment_statement,
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .assignment_target => {
            const new_node = ASTNode{
                .data = .{
                    .assignment_target = .{
                        .access_attribute = root_node.data.assignment_target.access_attribute,
                        .name = root_node.data.assignment_target.name,
                        .next = try simplify(ast_node_array, error_report_array, root_node.data.assignment_target.next),
                    },
                },
                .kind = .assignment_target,
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .attributed_expression => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.attributed_expression.expression);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .attributed_expression,
                .data = .{
                    .attributed_expression = .{
                        .expression = expression.?,
                        .kind = root_node.data.attributed_expression.kind,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .block_expression => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.block_expression.expression);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .block_expression,
                .data = .{
                    .block_expression = .{
                        .expression = expression.?,
                        .statement = try simplify(ast_node_array, error_report_array, root_node.data.block_expression.statement),
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .break_statement => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.break_statement.expression);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .break_statement,
                .data = .{
                    .break_statement = .{
                        .expression = expression.?,
                        .name = root_node.data.break_statement.name,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .call_expression => {
            const target = try simplify(ast_node_array, error_report_array, root_node.data.call_expression.target);
            if (target == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .call_expression,
                .data = .{
                    .call_expression = .{
                        .parameter = try simplify(ast_node_array, error_report_array, root_node.data.call_expression.parameter),
                        .target = target.?,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .call_parameter => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.call_parameter.expression);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .call_parameter,
                .data = .{
                    .call_parameter = .{
                        .expression = expression.?,
                        .next = try simplify(ast_node_array, error_report_array, root_node.data.call_parameter.next),
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .call_statement => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.call_statement.call_expression);
            if (expression == null) {
                // error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .call_statement,
                .data = .{
                    .call_statement = .{
                        .call_expression = expression.?,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .comment => {
            return try simplify(ast_node_array, error_report_array, root_node.data.comment.next);
        },
        .continue_statement => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.continue_statement.expression);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .continue_statement,
                .data = .{
                    .continue_statement = .{
                        .expression = expression.?,
                        .name = root_node.data.continue_statement.name,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .expression => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.expression.expression);
            if (expression == null) {
                return null;
            }
            const expression_node = try ast_node_array.get(expression.?);
            const kind: ASTNode.Expression.ExpressionKind = switch (expression_node.kind) {
                .call_expression => .call,
                .type_expression => .type,
                .block_expression => .block,
                .label_expression => .label,
                .match_expression => .match,
                .literal_expression => .literal,
                .function_expression => .function,
                .attributed_expression => .attributed,
                else => {
                    try error_report_array.addUnexpectedNodeReport("Expression", expression_node.kind, root_node.position);
                    return null;
                },
            };
            const new_node = ASTNode{
                .kind = .expression,
                .data = .{
                    .expression = .{
                        .expression = expression.?,
                        .kind = kind,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .function_attribute => {
            const new_node = ASTNode{
                .kind = .function_attribute,
                .data = .{
                    .function_attribute = .{
                        .expression = try simplify(ast_node_array, error_report_array, root_node.data.function_attribute.expression),
                        .kind = root_node.data.function_attribute.kind,
                        .next = try simplify(ast_node_array, error_report_array, root_node.data.function_attribute.next),
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .function_expression => {
            const new_node = ASTNode{
                .kind = .function_expression,
                .data = .{
                    .function_expression = .{
                        .attribute = try simplify(ast_node_array, error_report_array, root_node.data.function_expression.attribute),
                        .expression = try simplify(ast_node_array, error_report_array, root_node.data.function_expression.expression),
                        .parameter = try simplify(ast_node_array, error_report_array, root_node.data.function_expression.parameter),
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .function_parameter => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.function_parameter.expression);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .function_parameter,
                .data = .{
                    .function_parameter = .{
                        .access_attribute = root_node.data.function_parameter.access_attribute,
                        .expression = expression.?,
                        .name = root_node.data.function_parameter.name,
                        .next = try simplify(ast_node_array, error_report_array, root_node.data.function_parameter.next),
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .label_expression => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.label_expression.expression);
            const label = try simplify(ast_node_array, error_report_array, root_node.data.label_expression.label);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                invalid = true;
            } else if (label == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                invalid = true;
            }

            if (invalid) {
                return null;
            }

            const new_node = ASTNode{
                .kind = .label_expression,
                .data = .{
                    .label_expression = .{
                        .expression = expression.?,
                        .label = label.?,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .literal_expression => {
            return root_node_index;
        },
        .match_case => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.match_case.expression);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .match_case,
                .data = .{
                    .match_case = .{
                        .expression = expression.?,
                        .next = try simplify(ast_node_array, error_report_array, root_node.data.match_case.next),
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .match_expression => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.match_expression.expression);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .match_expression,
                .data = .{
                    .match_expression = .{
                        .case = try simplify(ast_node_array, error_report_array, root_node.data.match_expression.case),
                        .expression = expression.?,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .multiple_expression => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.multiple_expression.expression);
            if (expression == null) {
                try error_report_array.addExpectedExpressionReport(root_node.position);
                return null;
            }
            const new_node = ASTNode{
                .kind = .multiple_expression,
                .data = .{
                    .multiple_expression = .{
                        .expression = expression.?,
                        .next = try simplify(ast_node_array, error_report_array, root_node.data.multiple_expression.next),
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .root => {
            const expression = try simplify(ast_node_array, error_report_array, root_node.data.root.containor);
            if (expression == null) {
                return null;
            }
            const new_node = ASTNode{
                .kind = .root,
                .data = .{
                    .root = .{
                        .containor = expression.?,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .statement => {
            const getStatement = struct {
                pub fn getStatement(index: usize, _ast_node_array: *const ASTNodeArray, _error_report_array: *_error.ErrorReportArray) error{ OutOfRange, OutOfCapacity }!struct { usize, ?ASTNode } {
                    const node = try _ast_node_array.get(index);
                    return switch (node.kind) {
                        .assignment_statement, .call_statement, .break_statement, .continue_statement => .{ index, node },
                        .statement => return getStatement(node.data.statement.statement, _ast_node_array, _error_report_array),
                        else => {
                            try _error_report_array.addUnexpectedNodeReport("statement", node.kind, node.position);
                            return .{ 0, null };
                        },
                    };
                }
            }.getStatement;
            const statement = try simplify(ast_node_array, error_report_array, root_node.data.statement.statement);
            if (statement == null) {
                return null;
            }
            const next = try simplify(ast_node_array, error_report_array, root_node.data.statement.next);
            if (statement == null) {
                return null;
            }
            const statement_node = try getStatement(statement.?, ast_node_array, error_report_array);

            const new_node = ASTNode{
                .kind = .statement,
                .data = .{
                    .statement = .{
                        .next = next,
                        .kind = switch (statement_node.@"1".?.kind) {
                            .assignment_statement => .assignment,
                            .break_statement => .@"break",
                            .call_statement => .call,
                            .continue_statement => .@"continue",
                            else => unreachable,
                        },
                        .statement = statement_node.@"0",
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .type_entry => {
            const new_node = ASTNode{
                .kind = .type_entry,
                .data = .{
                    .type_entry = .{
                        .expression = try simplify(ast_node_array, error_report_array, root_node.data.type_entry.expression),
                        .name = root_node.data.type_entry.name,
                        .next = try simplify(ast_node_array, error_report_array, root_node.data.type_entry.next),
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
        .type_expression => {
            const new_node = ASTNode{
                .kind = .type_expression,
                .data = .{
                    .type_expression = .{
                        .entry = try simplify(ast_node_array, error_report_array, root_node.data.type_expression.entry),
                        .kind = root_node.data.type_expression.kind,
                    },
                },
                .position = root_node.position,
            };
            try ast_node_array.set(root_node_index.?, new_node);
            return root_node_index;
        },
    }
}
