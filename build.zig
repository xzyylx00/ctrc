const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/ctrc.zig"),
    });

    const executable = b.addExecutable(.{
        .name = "ctrc",
        .root_module = module,
    });

    b.installArtifact(executable);
}
