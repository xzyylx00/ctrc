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
const aslib = @import("aslib");

string_pool: aslib.pool.StringPool,
allocator: std.mem.Allocator,

const Self = @This();

const Config = struct {
    string_pool_size: u32 = 65536,
};

pub fn init(allocator: std.mem.Allocator, config: Config) error{OutOfMemory}!Self {
    const string_pool = try aslib.pool.StringPoolUnmanaged.init(allocator, config.string_pool_size);
    errdefer string_pool.deinit(allocator);

    return Self{
        .allocator = allocator,
        .string_pool = string_pool,
    };
}

pub fn deinit(self: *Self) void {
    self.string_pool.deinit(self.allocator);
    self.* = .{
        .allocator = undefined,
        .string_pool = undefined,
    };
}
