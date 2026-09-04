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

const StableIndexArrayUnmanaged = @import("lib/array.zig").StableIndexArrayUnmanaged;
const std = @import("std");

pub const StringPool = struct {
    array: StableIndexArrayUnmanaged([]const u8),
    index: std.StringHashMapUnmanaged(usize),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, size: usize) error{OutOfMemory}!StringPool {
        const array = try StableIndexArrayUnmanaged([]const u8).init(allocator, size);
        errdefer array.deinit(allocator);

        const index: std.StringHashMapUnmanaged(usize) = .empty;
        errdefer index.deinit(allocator);
        try index.ensureTotalCapacity(allocator, size);

        return StringPool{
            .array = array,
            .index = index,
            .allocator = allocator,
        };
    }

    pub fn deinit(pool: *StringPool) void {
        pool.index.deinit(pool.allocator);

        const array = pool.array.raw();
        for (array) |string| {
            pool.allocator.free(string);
        }

        pool.array.deinit(pool.allocator);

        pool.* = .{
            .array = undefined,
            .index = undefined,
            .allocator = undefined,
        };
    }

    pub fn putOrReuse(pool: *StringPool, string: []const u8, outer_allocator: std.mem.Allocator) error{ OutOfMemory, OutOfCapacity }!usize {
        const reuse = pool.index.get(string);
        if (reuse) |_reuse| {
            outer_allocator.free(string);
            return _reuse;
        } else {
            const position = try pool.array.alloc();
            errdefer pool.array.free(position) catch unreachable;

            const stored = try pool.allocator.dupe(u8, string);
            pool.array.set(position, stored) catch unreachable;
            pool.index.putAssumeCapacityNoClobber(stored, position);
            return position;
        }
    }

    pub fn get(pool: *const StringPool, pos: usize) error{OutOfRange}![]const u8 {
        return pool.array.get(pos);
    }
};
