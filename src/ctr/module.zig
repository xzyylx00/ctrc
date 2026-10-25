const Self = @This();
const Pool = @import("Pool.zig").Pool;
pub const ModuleHandle = u32;

pub const ModulePool = Pool(ModuleHandle, Self, 32);

pub const Dependency = struct {};

pub const DependencyHandle = u32;

pub const DependencyPool = Pool(DependencyHandle, Dependency);

dependency: DependencyHandle,
