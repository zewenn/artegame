const std = @import("std");
const builtin = @import("builtin");
const lm = @import("loom");

const global = @import("global/global.zig");
const prefabs = @import("prefabs/prefabs.zig");
const components = @import("components/components.zig");

pub fn main() !void {
    lm.project(.{
        .window = .{
            .title = "AMRAP",
            .resizable = true,
            .restore_state = false,
            .size = .init(1280, 720),
            .clear_color = lm.Color.init(14, 12, 12, 255),
            .exit_key = .null,
        },
        .asset_paths = .{
            .debug = "src/assets/",
            .release = switch (@import("builtin").target.os.tag) {
                .macos => "../../Resources/assets/",
                else => "../assets/",
            },
        },
    })({
        lm.scene("default")({
            lm.globalBehaviours(.{
                global.Setup{},
            });

            lm.cameras(&.{
                lm.CameraConfig{ .id = "main", .options = .{
                    .display = .fullscreen,
                    .draw_mode = .world,
                    .zoom = 1,
                } },
            });
        });

        lm.scene("main_menu")({
            lm.useMainCamera();

            lm.globalBehaviours(.{
                global.MainMenu{},
                global.MusicManager{},
                global.DevicePrompts{},
            });
        });

        lm.scene("demo_map")({
            lm.useMainCamera();

            lm.globalBehaviours(.{
                global.ProjectileManager{},
                global.RoomManager{},
                global.TutorialManager{},
                global.HUD{},
                global.MusicManager{},
                global.DevicePrompts{},
                global.input.ControlSchemeModule{},
            });
        });

        if (@import("builtin").mode == .debug) {
            lm.scene("map_editor")({
                lm.useMainCamera();

                lm.globalBehaviours(.{
                    global.MapEditor{},
                });
            });
        }
    });
}

fn isExternalNamespaceName(comptime declaration_name: []const u8) bool {
    return std.mem.eql(u8, declaration_name, "lm") or
        std.mem.eql(u8, declaration_name, "rl") or
        std.mem.eql(u8, declaration_name, "clay") or
        std.mem.eql(u8, declaration_name, "std");
}

fn refProjectModulesRecursive(comptime Namespace: type) void {
    if (!builtin.is_test) return;

    inline for (comptime std.meta.declarations(Namespace)) |declaration_name| {
        if (comptime isExternalNamespaceName(declaration_name)) continue;

        const declaration_value = @field(Namespace, declaration_name);
        if (@TypeOf(declaration_value) != type) continue;

        const type_info = @typeInfo(declaration_value);
        if (type_info != .@"struct") continue;

        std.testing.refAllDecls(declaration_value);
        if (type_info.@"struct".field_names.len == 0) {
            refProjectModulesRecursive(declaration_value);
        }
    }
}

test {
    refProjectModulesRecursive(global);
    refProjectModulesRecursive(prefabs.modules);
    refProjectModulesRecursive(components);
}
