const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // wmpartinfo executable
    const wmpartinfo = b.addExecutable(.{
        .name = "wmpartinfo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wmpartinfo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(wmpartinfo);

    // wmnkextract executable
    const wmnkextract = b.addExecutable(.{
        .name = "wmnkextract",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wmnkextract.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(wmnkextract);
}

