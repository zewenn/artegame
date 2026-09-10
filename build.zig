const std = @import("std");

const app_version = "3.0.1";

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
        const info_plist = write_files.add("Info.plist", b.fmt(
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
            \\    <key>CFBundleDisplayName</key>
            \\    <string>Artegame</string>
            \\    <key>CFBundlePackageType</key>
            \\    <string>APPL</string>
            \\    <key>CFBundleShortVersionString</key>
            \\    <string>{s}</string>
            \\    <key>CFBundleVersion</key>
            \\    <string>{s}</string>
            \\    <key>CFBundleSupportedPlatforms</key>
            \\    <array>
            \\        <string>MacOSX</string>
            \\    </array>
            \\    <key>LSMinimumSystemVersion</key>
            \\    <string>11.0</string>
            \\    <key>NSHighResolutionCapable</key>
            \\    <true/>
            \\</dict>
            \\</plist>
        , .{ app_version, app_version }));

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

        if (@import("builtin").os.tag == .macos) {
            const sign_cmd = b.addSystemCommand(&.{
                "codesign",
                "--force",
                "--deep",
                "--sign",
                "-",
                b.fmt("{s}/artegame.app", .{b.getInstallPath(.bin, "")}),
            });
            sign_cmd.step.dependOn(b.getInstallStep());
            const sign_step = b.step("sign", "Sign the macOS app bundle with an ad-hoc signature");
            sign_step.dependOn(&sign_cmd.step);
        }
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

    const installer_step = b.step("installer", "Build Windows installer with NSIS (requires makensis)");
    const makensis_cmd = b.addSystemCommand(&.{"makensis"});
    makensis_cmd.addArg(b.fmt("-DVERSION={s}", .{app_version}));
    makensis_cmd.addArg(b.fmt("-DBIN_DIR={s}", .{b.getInstallPath(.bin, "")}));
    makensis_cmd.addArg(b.fmt("-DOUTPUT_DIR={s}", .{b.getInstallPath(.bin, "")}));
    makensis_cmd.addArg("-DOUTPUT_NAME=artegame-windows-x86_64-setup.exe");
    makensis_cmd.addArg(b.fmt("-DICON_PATH={s}", .{b.pathFromRoot("src/assets/ui/branding/icon.ico")}));
    makensis_cmd.addFileArg(b.path("packaging/windows/installer.nsi"));

    makensis_cmd.step.dependOn(b.getInstallStep());
    installer_step.dependOn(&makensis_cmd.step);

    const dmg_step = b.step("dmg", "Build macOS drag-and-drop DMG disk image (requires macOS)");
    const create_dmg_cmd = b.addSystemCommand(&.{"python3"});
    create_dmg_cmd.addFileArg(b.path("packaging/macos/create_dmg.py"));
    create_dmg_cmd.addArgs(&.{
        "--app",
        b.fmt("{s}/artegame.app", .{b.getInstallPath(.bin, "")}),
        "--out",
        b.fmt("{s}/artegame-macos.dmg", .{b.getInstallPath(.bin, "")}),
        "--volname",
        "Artegame",
    });
    create_dmg_cmd.step.dependOn(b.getInstallStep());
    dmg_step.dependOn(&create_dmg_cmd.step);
}


