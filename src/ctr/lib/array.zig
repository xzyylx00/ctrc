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

pub fn StableIndexArrayUnmanaged(T: type) type {
    return struct {
        used: usize,
        dindex: []usize,
        data: []T,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, size: usize) error{OutOfMemory}!Self {
            const dindex = try allocator.alloc(usize, size);
            errdefer allocator.free(dindex);

            const data = try allocator.alloc(T, size);
            errdefer allocator.free(data);

            @memset(dindex, 0);

            return Self{
                .data = data,
                .dindex = dindex,
                .used = 0,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.dindex);
            allocator.free(self.data);

            self.* = Self{
                .data = undefined,
                .dindex = undefined,
                .used = 0,
            };
        }

        pub fn get(self: *const Self, i: usize) error{OutOfRange}!T {
            if (self.dindex.len <= i) {
                return error.OutOfRange;
            }

            return self.data[self.dindex[i]];
        }

        pub fn set(self: *Self, i: usize, data: T) error{OutOfRange}!void {
            if (self.dindex.len <= i) {
                return error.OutOfRange;
            }

            self.data[self.dindex[i]] = data;
        }

        // a: Outer index
        // b: Outer index
        pub fn swap(self: *Self, a: usize, b: usize) void {
            const aindex = self.dindex[a];
            const bindex = self.dindex[b];

            {
                const data = self.data[aindex];
                self.data[aindex] = self.data[bindex];
                self.data[bindex] = data;
            }

            {
                self.dindex[a] = bindex;
                self.dindex[b] = aindex;
            }
        }

        // pub fn alloc(self: *Self, allocator: std.mem.Allocator) error{OutOfMemory}!usize {
        pub fn alloc(self: *Self) error{OutOfCapacity}!usize {
            if (self.used == self.dindex.len) {
                // var new = try Self.init(allocator, 2 * self.dindex.len);
                // @memcpy(new.data[0..self.dindex.len], self.data);
                // @memcpy(new.dindex[0..self.dindex.len], self.dindex);
                // new.used = self.used;
                // allocator.free(self.data);
                // allocator.free(self.dindex);
                // self.* = new;

                return error.OutOfCapacity;
            }

            self.dindex[self.used] = self.used;

            defer self.used += 1;
            return self.used;
        }

        pub fn free(self: *Self, index: usize) error{OutOfRange}!void {
            if (self.dindex.len <= index or self.used == 0) {
                return error.OutOfRange;
            }

            self.used -= 1;
            self.swap(index, self.used);
        }

        pub fn raw(self: *const Self) []const T {
            return self.data[0..self.used];
        }

        pub fn length(self: *const Self) usize {
            return self.used;
        }

        pub fn total(self: *const Self) usize {
            return self.dindex.len;
        }

        pub fn clear(self: *Self) void {
            @memset(self.dindex, 0);
            self.used = 0;
        }
    };
}

pub fn StableIndexArrayManaged(T: type) type {
    return struct {
        array: Unmanaged,
        allocator: std.mem.Allocator,

        const Self = @This();
        const Unmanaged = StableIndexArrayUnmanaged(T);

        pub fn init(allocator: std.mem.Allocator, size: usize) error{OutOfMemory}!Self {
            return Self{
                .allocator = allocator,
                .array = try Unmanaged.init(allocator, size),
            };
        }

        pub fn deinit(self: *Self) void {
            self.array.deinit(self.allocator);
            self.* = .{
                .allocator = undefined,
                .array = undefined,
            };
        }

        pub fn get(self: *const Self, index: usize) error{OutOfRange}!T {
            return try self.array.get(index);
        }

        pub fn set(self: *Self, index: usize, data: T) error{OutOfRange}!void {
            return try self.array.set(index, data);
        }

        pub fn swap(self: *Self, a: usize, b: usize) void {
            self.array.swap(a, b);
        }

        // pub fn alloc(self: *Self) error{OutOfMemory}!usize {
        pub fn alloc(self: *Self) error{OutOfCapacity}!usize {
            // return try self.array.alloc(self.allocator);
            return try self.array.alloc();
        }

        pub fn free(self: *Self, index: usize) error{OutOfRange}!void {
            return try self.array.free(index);
        }

        pub fn raw(self: *Self) []const T {
            return self.array.raw();
        }

        pub fn length(self: *const Self) usize {
            return self.array.length();
        }

        pub fn total(self: *const Self) usize {
            return self.total();
        }

        pub fn clear(self: *Self) void {
            return self.allocator.clear();
        }
    };
}

pub const StableIndexArray = StableIndexArrayManaged;

pub fn StableLookupArrayUnmanaged(T: type) type {
    return struct {
        used: usize,
        dindex: []usize,
        reindex: []usize,
        data: []T,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, size: usize) error{OutOfMemory}!Self {
            const dindex = try allocator.alloc(usize, size);
            errdefer allocator.free(dindex);

            const reindex = try allocator.alloc(usize, size);
            errdefer allocator.free(reindex);

            const data = try allocator.alloc(T, size);
            errdefer allocator.free(data);

            @memset(dindex, 0);
            @memset(reindex, 0);

            return Self{
                .data = data,
                .dindex = dindex,
                .reindex = reindex,
                .used = 0,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.dindex);
            allocator.free(self.reindex);
            allocator.free(self.data);

            self.* = Self{
                .data = undefined,
                .dindex = undefined,
                .reindex = undefined,
                .used = 0,
            };
        }

        pub fn get(self: *const Self, i: usize) error{OutOfRange}!T {
            if (self.dindex.len <= i) {
                return error.OutOfRange;
            }

            return self.data[self.dindex[i]];
        }

        pub fn set(self: *Self, i: usize, data: T) error{OutOfRange}!void {
            if (self.dindex.len <= i) {
                return error.OutOfRange;
            }

            self.data[self.dindex[i]] = data;
        }

        // a: Outer index
        // b: Outer index
        pub fn swap(self: *Self, a: usize, b: usize) void {
            const aindex = self.dindex[a];
            const bindex = self.dindex[b];

            {
                const data = self.data[aindex];
                self.data[aindex] = self.data[bindex];
                self.data[bindex] = data;
            }

            {
                self.dindex[a] = bindex;
                self.dindex[b] = aindex;
            }

            {
                const index = self.reindex[aindex];
                self.reindex[aindex] = self.reindex[bindex];
                self.reindex[bindex] = index;
            }
        }

        pub fn lookup(self: *Self, data: T, comptime equal_func: fn (T, T) bool) ?usize {
            for (self.data, 0..) |d, i| {
                if (equal_func(d, data)) {
                    return self.reindex[i];
                }
            }
            return null;
        }

        // pub fn alloc(self: *Self, allocator: std.mem.Allocator) error{OutOfMemory}!usize {
        pub fn alloc(self: *Self) error{OutOfCapacity}!usize {
            if (self.used == self.dindex.len) {
                // var new = try Self.init(allocator, 2 * self.dindex.len);
                // @memcpy(new.data[0..self.dindex.len], self.data);
                // @memcpy(new.dindex[0..self.dindex.len], self.dindex);
                // @memcpy(new.reindex[0..self.dindex.len], self.reindex);
                // new.used = self.used;
                // allocator.free(self.data);
                // allocator.free(self.dindex);
                // allocator.free(self.reindex);
                // self.* = new;
                return error.OutOfCapacity;
            }

            self.reindex[self.used] = self.used;
            self.dindex[self.used] = self.used;

            defer self.used += 1;
            return self.used;
        }

        pub fn free(self: *Self, index: usize) error{OutOfRange}!void {
            if (self.dindex.len <= index or self.used == 0) {
                return error.OutOfRange;
            }

            self.used -= 1;
            self.swap(index, self.used);
        }

        pub fn raw(self: *const Self) []const T {
            return self.data[0..self.used];
        }

        pub fn length(self: *const Self) usize {
            return self.used;
        }

        pub fn total(self: *const Self) usize {
            return self.dindex.len;
        }
    };
}

pub fn StableLookupArrayManaged(T: type) type {
    return struct {
        array: Unmanaged,
        allocator: std.mem.Allocator,

        const Self = @This();
        const Unmanaged = StableLookupArrayUnmanaged(T);

        pub fn init(allocator: std.mem.Allocator, size: usize) error{OutOfMemory}!Self {
            return Self{
                .allocator = allocator,
                .array = try Unmanaged.init(allocator, size),
            };
        }

        pub fn deinit(self: *Self) void {
            self.array.deinit(self.allocator);
            self.* = .{
                .allocator = undefined,
                .array = undefined,
            };
        }

        pub fn get(self: *const Self, index: usize) error{OutOfRange}!T {
            return try self.array.get(index);
        }

        pub fn set(self: *Self, index: usize, data: T) error{OutOfRange}!void {
            return try self.array.set(index, data);
        }

        pub fn swap(self: *Self, a: usize, b: usize) void {
            self.array.swap(a, b);
        }

        pub fn lookup(self: *Self, data: T, comptime equal_func: fn (T, T) bool) ?usize {
            return self.array.lookup(data, equal_func);
        }

        // pub fn alloc(self: *Self) error{OutOfMemory}!usize {
        pub fn alloc(self: *Self) error{OutOfCapacity}!usize {
            // return try self.array.alloc(self.allocator);
            return try self.array.alloc();
        }

        pub fn free(self: *Self, index: usize) error{OutOfRange}!void {
            return try self.array.free(index);
        }

        pub fn raw(self: *Self) []const T {
            return self.array.raw();
        }

        pub fn length(self: *const Self) usize {
            return self.array.length();
        }

        pub fn total(self: *const Self) usize {
            return self.total();
        }
    };
}

test "StableIndexArray(u16)" {
    const Array = StableIndexArrayManaged(u16);

    const allocator = std.testing.allocator;

    var array = try Array.init(allocator, 8192);
    defer array.deinit();

    var handle: [16384]usize = undefined;

    @memset(handle[0..], 0);

    for (0..1000) |i| {
        const index = try array.alloc();
        try array.set(index, @intCast(1000 - i));
        handle[i] = index;
    }

    for (0..100) |i| {
        try array.free(handle[i]);
        handle[i] = 0;
    }

    for (100..1000) |i| {
        const data = try array.get(handle[i]);
        try std.testing.expectEqual(1000 - i, data);
    }
}
