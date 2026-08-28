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

/// Type-ereased Stack
/// Caller must remember the sequence of element, and pop them in order.
pub const AnyStackUnmanaged = struct {
    stack: []u8,
    top: usize,

    pub fn init(allocator: std.mem.Allocator, init_size: usize) error{OutOfMemory}!AnyStackUnmanaged {
        const stack = try allocator.alloc(u8, init_size);
        @memset(stack, 0);
        return AnyStackUnmanaged{
            .stack = stack,
            .top = 0,
        };
    }

    pub fn deinit(self: *AnyStackUnmanaged, allocator: std.mem.Allocator) void {
        allocator.free(self.stack);
        self.* = AnyStackUnmanaged{
            .stack = undefined,
            .top = undefined,
        };
    }

    pub fn push(self: *AnyStackUnmanaged, comptime T: type, data: T) error{OutOfCapacity}!void {
        const data_size: usize = comptime @sizeOf(T);

        if (self.stack.len - self.top < data_size) {
            return error.OutOfCapacity;
        }

        const data_ptr: [*]const u8 = @ptrCast(&data);
        const data_array = data_ptr[0..data_size];
        const target = self.stack[self.top .. self.top + data_size];
        @memcpy(target, data_array);
        self.top += data_size;
    }

    pub fn pop(self: *AnyStackUnmanaged, comptime T: type) ?T {
        const data_size: usize = comptime @sizeOf(T);

        if (self.top < data_size) {
            return null;
        }

        const target = self.stack[self.top - data_size .. self.top];
        var data: T = undefined;
        const data_ptr: [*]u8 = @ptrCast(&data);
        const data_array = data_ptr[0..data_size];
        @memcpy(data_array, target);
        self.top -= data_size;
        return data;
    }

    pub fn clear(self: *AnyStackUnmanaged) void {
        self.top = 0;
    }
};

test "AnyStackManaged" {
    const allocator = std.testing.allocator;
    const expectEqual = std.testing.expectEqual;
    const expectError = std.testing.expectError;

    var anystack = try AnyStackUnmanaged.init(allocator, 1);
    try expectError(error.OutOfCapacity, anystack.push(u64, 100));
    anystack.deinit(allocator);

    anystack = try AnyStackUnmanaged.init(allocator, 1024);
    try anystack.push(u8, 1);
    try anystack.push(u64, 2);
    if (anystack.pop(u64)) |data| {
        try expectEqual(2, data);
    }

    if (anystack.pop(u8)) |data| {
        try expectEqual(1, data);
    }

    anystack.deinit(allocator);
}

pub const AnyStackManaged = struct {
    allocator: std.mem.Allocator,
    stack: AnyStackUnmanaged,

    pub fn init(allocator: std.mem.Allocator, init_size: usize) error{OutOfMemory}!AnyStackManaged {
        const stack = try AnyStackUnmanaged.init(allocator, init_size);
        return AnyStackManaged{
            .stack = stack,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnyStackManaged) void {
        self.stack.deinit(self.allocator);
        self.* = AnyStackManaged{
            .stack = undefined,
            .allocator = undefined,
        };
    }

    pub fn push(self: *AnyStackManaged, comptime T: type, data: T) error{OutOfCapacity}!void {
        try self.stack.push(T, data);
    }

    pub fn pop(self: *AnyStackManaged, comptime T: type) ?T {
        return self.stack.pop(T);
    }

    pub fn clear(self: *AnyStackManaged) void {
        self.stack.clear();
    }
};

/// Single type stack
pub fn TypedStackUnmanaged(T: type) type {
    return struct {
        const Self = @This();

        stack: []T,
        top: usize,

        pub fn init(allocator: std.mem.Allocator, init_size: usize) error{OutOfMemory}!Self {
            const stack = try allocator.alloc(T, init_size);
            return Self{
                .stack = stack,
                .top = 0,
            };
        }

        pub fn push(self: *Self, data: T) error{OutOfCapacity}!void {
            if (self.stack.len <= self.top) {
                return error.OutOfCapacity;
            }

            self.stack[self.top] = data;
            self.top += 1;
        }

        pub fn at(self: *const Self, position: usize) ?T {
            if (self.top <= position) {
                return null;
            }

            return self.stack[position];
        }

        pub fn count(self: *const Self) usize {
            return self.top;
        }

        pub fn peek(self: *const Self) ?T {
            if (self.top == 0) {
                return null;
            }
            return self.stack[self.top - 1];
        }

        pub fn pop(self: *Self) ?T {
            if (self.top == 0) {
                return null;
            }
            self.top -= 1;
            const top = self.top;
            return self.stack[top];
        }

        pub fn clear(self: *Self) void {
            self.top = 0;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.stack);
            self.* = Self{
                .stack = undefined,
                .top = 0,
            };
        }
    };
}

pub fn TypedStackManaged(T: type) type {
    return struct {
        const Self = @This();
        const Inner = TypedStackUnmanaged(T);

        allocator: std.mem.Allocator,
        stack: Inner,

        pub fn init(allocator: std.mem.Allocator, init_size: usize) error{OutOfMemory}!Self {
            const stack = try Inner.init(allocator, init_size);
            return Self{
                .stack = stack,
                .allocator = allocator,
            };
        }

        pub fn push(self: *Self, data: T) error{OutOfCapacity}!void {
            try self.stack.push(data);
        }

        pub fn pop(self: *Self) ?T {
            return self.stack.pop();
        }

        pub fn at(self: *const Self, position: usize) ?T {
            return self.stack.at(position);
        }

        pub fn count(self: *const Self) usize {
            return self.stack.count();
        }

        pub fn peek(self: *const Self) ?T {
            return self.stack.peek();
        }

        pub fn clear(self: *Self) void {
            self.stack.clear();
        }

        pub fn deinit(self: *Self) void {
            self.stack.deinit(self.allocator);
            self.* = Self{
                .allocator = undefined,
                .stack = undefined,
            };
        }
    };
}

test "TypedStackManaged(u64)" {
    const allocator = std.testing.allocator;
    var stack = try TypedStackManaged(u64).init(allocator, 1024);
    defer stack.deinit();

    for (0..1000) |i| {
        const u64_data: u64 = @truncate(i);

        try stack.push(u64_data);
    }

    for (0..1000) |i| {
        const u64_data: u64 = @truncate(999 - i);

        if (stack.pop()) |data| {
            try std.testing.expectEqual(u64_data, data);
        }
    }
}

/// Typed stack with layer support
/// All pushs/pops operates on current layer.
pub fn TypedLayeredStackUnmanaged(T: type) type {
    return struct {
        data: []T,
        stack: TypedStackUnmanaged(usize),
        current: usize,
        top: usize,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, total_size: usize, layer_count: usize) error{OutOfMemory}!Self {
            const data = try allocator.alloc(T, total_size);
            errdefer allocator.free(data);

            const stack = try TypedStackUnmanaged(usize).init(allocator, layer_count);
            errdefer stack.deinit(allocator);

            return Self{
                .data = data,
                .stack = stack,
                .current = 0,
                .top = 0,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
            self.stack.deinit(allocator);

            self.* = .{
                .current = undefined,
                .data = undefined,
                .stack = undefined,
                .top = 0,
            };
        }

        /// Create a new layer
        /// All pushs/pops later without another newLayer will operate on this layer
        pub fn newLayer(self: *Self) error{OutOfCapacity}!void {
            try self.stack.push(self.current);
            self.current = 0;
        }

        /// Delete a new layer
        /// All pushs/pops later without another newLayer will operate on previous layer.
        /// Current layer will be deleted.
        pub fn deleteLayer(self: *Self) void {
            self.top -= self.current;
            const prev_count = self.stack.pop();
            if (prev_count) |real_count| {
                self.current = real_count;
            } else {
                self.current = 0;
            }
        }

        /// push operates on current layer
        pub fn push(self: *Self, data: T) error{OutOfCapacity}!void {
            if (self.data.len <= self.top) {
                return error.OutOfCapacity;
            }

            self.data[self.top] = data;
            self.top += 1;
            self.current += 1;
        }

        /// pop operates on current layer
        pub fn pop(self: *Self) ?T {
            if (self.top == 0 or self.current == 0) {
                return null;
            }

            self.top -= 1;
            self.current -= 1;
            return self.data[self.top];
        }

        pub fn peek(self: *const Self) ?T {
            if (self.current == 0) {
                return null;
            }

            return self.data[self.top - 1];
        }

        pub fn count(self: *const Self) usize {
            return self.current;
        }

        pub fn total(self: *const Self) usize {
            return self.top;
        }
    };
}

pub fn TypedLayeredStackManaged(T: type) type {
    return struct {
        stack: TypedLayeredStackUnmanaged(T),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, total_size: usize, layer_count: usize) error{OutOfMemory}!Self {
            return Self{
                .allocator = allocator,
                .stack = try TypedLayeredStackUnmanaged(T).init(allocator, total_size, layer_count),
            };
        }

        pub fn deinit(self: *Self) void {
            self.stack.deinit(self.allocator);
            self.* = .{
                .allocator = undefined,
                .stack = undefined,
            };
        }

        /// Create a new layer
        /// All pushs/pops later without another newLayer will operate on this layer
        pub fn newLayer(self: *Self) error{OutOfCapacity}!void {
            return try self.stack.newLayer();
        }

        /// Delete a new layer
        /// All pushs/pops later without another newLayer will operate on previous layer. Current layer will be deleted.
        pub fn deleteLayer(self: *Self) void {
            self.stack.deleteLayer();
        }

        /// push operates on current layer
        pub fn push(self: *Self, data: T) error{OutOfCapacity}!void {
            return try self.stack.push(data);
        }

        /// pop operates on current layer
        pub fn pop(self: *Self) ?T {
            return self.stack.pop();
        }

        pub fn count(self: *const Self) usize {
            return self.stack.count();
        }

        pub fn total(self: *const Self) usize {
            return self.stack.total();
        }
    };
}

test "TypedLayeredStackManaged(u64)" {
    const allocator = std.testing.allocator;
    const expectEqual = std.testing.expectEqual;

    var stack = try TypedLayeredStackManaged(u64).init(allocator, 16384, 128);
    defer stack.deinit();

    try stack.newLayer();
    for (0..64) |i| {
        try stack.push(i);
    }
    for (0..64) |_| {
        try stack.newLayer();
    }

    try expectEqual(64, stack.total());
    try expectEqual(0, stack.count());

    for (0..64) |_| {
        stack.deleteLayer();
    }

    try expectEqual(64, stack.total());
    try expectEqual(64, stack.count());

    stack.deleteLayer();

    try expectEqual(0, stack.total());
    try expectEqual(0, stack.count());
}
