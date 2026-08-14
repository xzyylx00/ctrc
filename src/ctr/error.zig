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
const Module = @import("module.zig");

pub const ErrorReport = struct {
    position: Module.Position,

    kind: ErrorReportKind,
    data: union {
        expected_token: ExpectedToken,
        unexpected_token: UnexpectedToken,
        invalid_character: InvalidCharacter,
    },

    const InvalidCharacter = struct {
        found: [:0]const u8,
    };

    const UnexpectedToken = struct {
        expected: [:0]const u8,
        found: Module.Range,
    };

    const ExpectedToken = struct {
        expected: [:0]const u8,
    };

    const ErrorReportKind = enum {
        // Lexer
        invalid_character,

        // Parser
        unexpected_token,
        expected_token,
        expected_expression,
    };

    pub fn report(error_report: ErrorReport, source: [:0]const u8) void {
        switch (error_report.kind) {
            .unexpected_token => {
                std.log.debug("Unexpected Token at {d}:{d}, expect {s}, found {s}", .{ error_report.position.line, error_report.position.pos, error_report.data.unexpected_token.expected, source[error_report.data.unexpected_token.found.start..error_report.data.unexpected_token.found.end] });
            },
            .expected_token => {
                std.log.debug("Expected Token at {d}:{d}, expect {s}", .{ error_report.position.line, error_report.position.pos, error_report.data.expected_token.expected });
            },
            .expected_expression => {
                std.log.debug("Expected Expression at {d}:{d}", .{ error_report.position.line, error_report.position.pos });
            },
            .invalid_character => {
                std.log.debug("Invalid Character at {d}:{d}", .{ error_report.position.line, error_report.position.pos });
            },
        }
    }
};

pub const ErrorReportArray = struct {
    error_reports: []ErrorReport,
    used: usize,

    pub fn init(allocator: std.mem.Allocator, size: usize) error{OutOfMemory}!ErrorReportArray {
        const error_reports = try allocator.alloc(ErrorReport, size);
        return ErrorReportArray{
            .error_reports = error_reports,
            .used = 0,
        };
    }

    pub fn deinit(error_report_array: *ErrorReportArray, allocator: std.mem.Allocator) void {
        allocator.free(error_report_array.error_reports);

        error_report_array.* = ErrorReportArray{
            .error_reports = undefined,
            .used = 0,
        };
    }

    pub fn clear(error_report_array: *ErrorReportArray) void {
        error_report_array.used = 0;
    }

    pub fn raw(error_report_array: *const ErrorReportArray) []ErrorReport {
        return error_report_array.error_reports[0..error_report_array.used];
    }

    pub fn addReport(error_report_array: *ErrorReportArray, error_report: ErrorReport) error{OutOfCapacity}!void {
        if (error_report_array.used == error_report_array.error_reports.len) {
            return error.OutOfCapacity;
        }

        error_report_array.error_reports[error_report_array.used] = error_report;
        error_report_array.used += 1;
    }

    pub fn addUnexpectedTokenReport(error_report_array: *ErrorReportArray, expected: [:0]const u8, found: Module.Range, position: Module.Position) error{OutOfCapacity}!void {
        try error_report_array.addReport(.{
            .kind = .unexpected_token,
            .data = .{
                .unexpected_token = .{
                    .found = found,
                    .expected = expected,
                },
            },
            .position = position,
        });
    }

    pub fn addExpectedTokenReport(error_report_array: *ErrorReportArray, expected: [:0]const u8, position: Module.Position) error{OutOfCapacity}!void {
        try error_report_array.addReport(.{
            .kind = .expected_token,
            .data = .{
                .expected_token = .{
                    .expected = expected,
                },
            },
            .position = position,
        });
    }

    pub fn addExpectedExpressionReport(error_report_array: *ErrorReportArray, position: Module.Position) error{OutOfCapacity}!void {
        try error_report_array.addReport(.{
            .kind = .expected_expression,
            .data = undefined,
            .position = position,
        });
    }

    pub fn report(error_report_array: *const ErrorReportArray, source: [:0]const u8) void {
        for (error_report_array.raw()) |error_report| {
            ErrorReport.report(error_report, source);
        }
    }
};
