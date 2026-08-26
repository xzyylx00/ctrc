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

pub const Lexer = @import("lexer.zig");
pub const Module = @import("module.zig");
pub const ErrorReport = @import("error.zig").ErrorReport;
pub const ErrorReportArray = @import("error.zig").ErrorReportArray;

pub const ast = @import("ast.zig");
pub const parser = @import("parser.zig");
pub const format = @import("format.zig");
