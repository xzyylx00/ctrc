const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/ctrc.zig"),
    });

    const aslibrary = b.dependency("aslibrary", .{
        .target = target,
        .optimize = optimize,
    });

    module.addImport("aslib", aslibrary.module("aslibrary"));

    const executable = b.addExecutable(.{
        .name = "ctrc",
        .root_module = module,
    });

    const @"test" = b.addTest(.{
        .root_module = module,
    });

    b.installArtifact(executable);

    b.installArtifact(@"test");
}
