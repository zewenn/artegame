const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const loom_dep = b.dependency("loom", .{
        .target = target,
        .optimize = optimize,
    });
    const loom_mod = loom_dep.module("loom");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe_mod.addImport("loom", loom_mod);

    if (target.result.os.tag == .windows) {
        exe_mod.addWin32ResourceFile(.{
            .file = b.path("src/assets/ui/branding/icon.rc"),
            .include_paths = &.{
                b.path("src/assets/ui/branding"),
            },
        });
    }

    const exe = b.addExecutable(.{
        .name = "artegame",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    b.installDirectory(.{
        .source_dir = b.path("src/assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });

    if (target.result.os.tag.isDarwin()) {
        const app_dir = "artegame.app";
        const write_files = b.addWriteFiles();
        const info_plist = write_files.add("Info.plist",
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\    <key>CFBundleDevelopmentRegion</key>
            \\    <string>en</string>
            \\    <key>CFBundleExecutable</key>
            \\    <string>artegame</string>
            \\    <key>CFBundleIconFile</key>
            \\    <string>icon.icns</string>
            \\    <key>CFBundleIdentifier</key>
            \\    <string>com.zewenn.artegame</string>
            \\    <key>CFBundleInfoDictionaryVersion</key>
            \\    <string>6.0</string>
            \\    <key>CFBundleName</key>
            \\    <string>Artegame</string>
            \\    <key>CFBundlePackageType</key>
            \\    <string>APPL</string>
            \\    <key>CFBundleShortVersionString</key>
            \\    <string>3.0.0</string>
            \\    <key>CFBundleVersion</key>
            \\    <string>1</string>
            \\    <key>LSMinimumSystemVersion</key>
            \\    <string>11.0</string>
            \\    <key>NSHighResolutionCapable</key>
            \\    <true/>
            \\</dict>
            \\</plist>
        );

        b.getInstallStep().dependOn(&b.addInstallFileWithDir(
            info_plist,
            .bin,
            b.fmt("{s}/Contents/Info.plist", .{app_dir}),
        ).step);

        b.getInstallStep().dependOn(&b.addInstallFileWithDir(
            b.path("src/assets/ui/branding/icon.icns"),
            .bin,
            b.fmt("{s}/Contents/Resources/icon.icns", .{app_dir}),
        ).step);

        const install_app_bin = b.addInstallArtifact(exe, .{
            .dest_dir = .{ .override = .{ .custom = b.fmt("bin/{s}/Contents/MacOS", .{app_dir}) } },
        });
        b.getInstallStep().dependOn(&install_app_bin.step);

        b.installDirectory(.{
            .source_dir = b.path("src/assets"),
            .install_dir = .bin,
            .install_subdir = b.fmt("{s}/Contents/Resources/assets", .{app_dir}),
        });
    }

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
