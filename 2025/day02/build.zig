const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("day02", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const advent_of_code_utils = b.dependency("advent_of_code_utils", .{
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("advent_of_code_utils", advent_of_code_utils.module("advent_of_code_utils"));

    const exe = b.addExecutable(.{
        .name = "day02",
        .root_module = mod,
    });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
