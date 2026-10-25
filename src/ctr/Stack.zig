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

pub fn Stack(T: type, comptime default_size: usize) type {
    return struct {
        const Self = @This();

        data: []T,
        used: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!Self {
            const stack = try allocator.alloc(T, default_size);
            errdefer allocator.free(stack);

            return Self{
                .data = stack,
                .used = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
            self.* = undefined;
        }

        pub fn push(self: *Self, data: T) error{OutOfMemory}!void {
            if (self.data.len == self.used + 1) {
                self.data = try self.allocator.realloc(self.data, self.used * 2);
            }

            self.data[self.used] = data;
            self.used += 1;
        }

        pub fn pop(self: *Self) ?T {
            if (self.data.len >= self.used * 2) {
                self.data = try self.allocator.realloc(self.data, self.used / 2 + 1);
            }

            if (self.used == 0) {
                return null;
            }

            self.used -= 1;
            return self.data[self.used];
        }

        pub fn top(self: *const Self) ?T {
            return self.at(if (self.used != 0) self.used - 1 else 0);
        }

        pub fn at(self: *const Self, index: usize) ?T {
            if (self.used > index) {
                return self.data[index];
            }
            return null;
        }

        pub fn count(self: *const Self) usize {
            return self.used;
        }

        pub fn clear(self: *Self) void {
            self.used = 0;
        }
    };
}
