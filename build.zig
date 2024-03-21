const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "nonogram-zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const puzzle = b.addModule("puzzle", .{ .source_file = .{ .path = "src/puzzle.zig" } });
    exe.addModule("puzzle", puzzle);

    const gui = b.addModule("gui", .{ .source_file = .{ .path = "src/gui.zig" }, .dependencies = &.{.{ .name = "puzzle", .module = puzzle }} });
    exe.addModule("gui", gui);

    const maths = b.addModule("maths", .{ .source_file = .{ .path = "src/maths.zig" } });
    exe.addModule("maths", maths);

    const prob = b.addModule("prob", .{ .source_file = .{ .path = "src/prob.zig" } });
    exe.addModule("prob", prob);

    exe.linkLibC();
    exe.linkSystemLibrary("raylib");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
