const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "nonogramz",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Prepare all of NonogramZ's modules
    const puzzle = b.addModule("puzzle", .{ .root_source_file = .{ .path = "src/puzzle.zig" } });
    exe.root_module.addImport("puzzle", puzzle);

    const gui = b.addModule("gui", .{ .root_source_file = .{ .path = "src/gui.zig" }, .imports = &.{.{ .name = "puzzle", .module = puzzle }} });
    exe.root_module.addImport("gui", gui);

    const maths = b.addModule("maths", .{ .root_source_file = .{ .path = "src/maths.zig" } });
    exe.root_module.addImport("maths", maths);

    const prob = b.addModule("prob", .{ .root_source_file = .{ .path = "src/prob.zig" } });
    exe.root_module.addImport("prob", prob);

    // Prepare the inclusion of raylib
    const raylib_dep = b.dependency("raylib", .{ .target = target, .optimize = optimize });
    exe.linkLibrary(raylib_dep.artifact("raylib"));

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
