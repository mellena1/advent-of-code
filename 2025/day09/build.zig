const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("day08", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const advent_of_code_utils = b.dependency("advent_of_code_utils", .{
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("advent_of_code_utils", advent_of_code_utils.module("advent_of_code_utils"));

    const zbench = b.dependency("zbench", .{
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("zbench", zbench.module("zbench"));

    const exe = b.addExecutable(.{
        .name = "day08",
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

    const bench_mod = b.addModule("bench", .{
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = optimize,
    });

    bench_mod.addImport("day08", mod);
    bench_mod.addImport("zbench", zbench.module("zbench"));

    const bench_exe = b.addExecutable(.{
        .name = "bench",
        .root_module = bench_mod,
    });

    const run_bench = b.addRunArtifact(bench_exe);

    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);
}
