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

pub const Reporter = struct {
    lock: std.Io.Mutex,
    allocator: std.mem.Allocator,
    list: std.ArrayList(Error),

    pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!Reporter {
        return Reporter{
            .lock = .init,
            .allocator = allocator,
            .list = try .initCapacity(allocator, 128),
        };
    }

    pub fn deinit(self: *Reporter) void {
        for (self.list.items) |_error| {
            self.allocator.free(_error.reason);
        }
        self.list.clearAndFree(self.allocator);
        self.* = undefined;
    }

    pub fn add(self: *Reporter, io: std.Io, level: Level, filename: u32, line: u32, pos: u32, comptime fmt: []const u8, args: anytype) error{OutOfMemory}!void {
        self.lock.lock(io) catch unreachable;
        defer self.lock.unlock(io);

        const reason = try std.fmt.allocPrint(self.allocator, fmt, args);
        errdefer self.allocator.free(reason);
        self.list.append(self.allocator, Error{
            .filename = filename,
            .line = line,
            .position = pos,
            .reason = reason,
            .level = level,
        });
    }

    pub fn report(self: *Reporter, io: std.Io, string_pool: *StringPool, writer: std.Io.Writer) error{WriteFailed}!void {
        self.lock.lock(io) catch unreachable;
        defer self.lock.unlock(io);

        for (self.list.items) |_error| {
            try writer.print("{s} {s}:{d}:{d}: {s}\n", .{ switch (_error.level) {
                .tips => "[TIPS]",
                .panic => "[PANIC]",
                .@"error" => "[ERROR]",
                .warning => "[WARNING]",
                .info => "[INFO]",
                .debug => "[DEBUG]",
                .trace => "[TRACE]",
            }, string_pool.get(_error.filename) catch "unnamed", _error.line, _error.position, _error.reason });
        }
    }
};

pub const Error = struct {
    filename: u32,
    line: u32,
    position: u32,
    reason: []const u8,
    level: Level,
};

pub const Level = enum {
    tips,
    panic,
    @"error",
    warning,
    info,
    debug,
    trace,
};
