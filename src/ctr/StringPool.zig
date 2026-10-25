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
pub const StringHandle = u32;
const Self = @This();

const Map = std.StringHashMap(StringHandle);
const Back = [][]const u8;
map: Map,
back: Back,
used: StringHandle,
allocator: std.mem.Allocator,
lock: std.atomic.Mutex,

pub fn init(allocator: std.mem.Allocator, default_size: usize) error{OutOfMemory}!Self {
    const map = Map.init(allocator);
    const back = try allocator.alloc([]const u8, default_size);
    errdefer allocator.free(back);

    try map.ensureTotalCapacity(default_size);

    return Self{
        .allocator = allocator,
        .map = map,
        .back = back,
        .lock = .unlocked,
        .used = 0,
    };
}

pub fn deinit(self: *Self) void {
    self.lock.tryLock();
    self.map.clearAndFree();
    for (self.back) |key| {
        self.allocator.free(key);
    }
    self.allocator.free(self.back);
    self.* = Self{
        .allocator = undefined,
        .back = undefined,
        .lock = undefined,
        .map = undefined,
        .used = undefined,
    };
}

pub fn put(self: *Self, string: []const u8) error{OutOfMemory}!StringHandle {
    self.lock.tryLock();
    defer self.lock.unlock();
    const check = try self.map.getOrPut(string);
    if (check.found_existing) {
        return *check.value_ptr;
    } else {
        const dupe = try self.allocator.dupe(u8, string);
        errdefer self.allocator.free(dupe);

        if (self.used >= self.back.len) {
            errdefer _ = self.map.remove(string);

            self.map = try self.allocator.realloc(self.back, @trunc(self.used * 1.5));
        }

        check.key_ptr.* = dupe;
        self.back[self.used] = *check.key_ptr;
        check.value_ptr.* = self.used;
        self.used += 1;
        return self.used - 1;
    }
}

pub fn get(self: *const Self, index: StringHandle) error{OutOfRange}![]const u8 {
    if (self.used >= index or index < 0) {
        return error.OutOfRange;
    }

    return self.back[index];
}
