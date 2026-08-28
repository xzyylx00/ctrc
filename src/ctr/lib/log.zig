// aslibrary
// Copyright (C) 2026 asAsadwS
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

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    const prefix = switch (comptime level) {
        .debug => "[DEBUG]",
        .err => "[ERROR]",
        .info => "[INFO ]",
        .warn => "[WARN ]",
    };
    var buffer: [128]u8 = undefined;

    const io = std.Options.debug_io;
    const prev = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(prev);

    const stderr = std.debug.lockStderr(&buffer).terminal();
    defer std.debug.unlockStderr();

    const clock = std.Io.Clock.boot;

    const time = std.Io.Timestamp.now(io, clock).toMicroseconds();

    nosuspend stderr.writer.print(prefix ++ "[{x: >16}]: ", .{time}) catch return;
    nosuspend stderr.writer.print(format ++ "\n", args) catch return;
}

pub const debug = std.log.debug;
pub const warn = std.log.warn;
pub const info = std.log.info;
pub const err = std.log.err;
