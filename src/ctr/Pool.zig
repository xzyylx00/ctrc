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

pub fn Pool(comptime Handle: type, comptime Data: type, comptime default_size: usize, comptime ctx: anytype) type {
    return struct {
        const Self = @This();

        const Map = blk: {
            if (@backingInt(@typeInfo(@TypeOf(ctx))) != @backingInt(std.lang.Type.null)) {
                break :blk std.HashMapUnmanaged(Data, Handle, ctx, 80);
            } else {
                break :blk std.AutoArrayHashMapUnmanaged(Data, Handle);
            }
        };
        const Back = []Data;
        map: Map,
        back: Back,
        used: Handle,
        allocator: std.mem.Allocator,
        lock: std.atomic.Mutex,

        pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!Self {
            var map = Map.empty;
            try map.ensureTotalCapacity(allocator, default_size);
            errdefer map.clearAndFree(allocator);
            const back = try allocator.alloc(Data, default_size);
            errdefer allocator.free(back);

            return Self{
                .allocator = allocator,
                .map = map,
                .back = back,
                .lock = .unlocked,
                .used = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            while (!self.lock.tryLock()) {}
            self.map.clearAndFree(self.allocator);
            self.allocator.free(self.back);
            self.* = Self{
                .allocator = undefined,
                .back = undefined,
                .lock = .unlocked,
                .map = undefined,
                .used = undefined,
            };
        }

        pub fn put(self: *Self, data: Data) error{OutOfMemory}!Handle {
            while (!self.lock.tryLock()) {}
            defer self.lock.unlock();
            const check = try self.map.getOrPut(self.allocator, data);
            if (check.found_existing) {
                return check.value_ptr.*;
            } else {
                if (self.used >= self.back.len) {
                    self.back = try self.allocator.realloc(self.back, @trunc(@as(f32, @floatFromInt(self.used)) * @as(f32, 1.5)));
                }

                self.back[self.used] = check.key_ptr.*;
                check.value_ptr.* = self.used;
                self.used += 1;
                return self.used - 1;
            }
        }

        pub fn get(self: *const Self, index: Handle) error{OutOfRange}!Data {
            if (self.used <= index or index < 0) {
                return error.OutOfRange;
            }

            return self.back[index];
        }
    };
}
