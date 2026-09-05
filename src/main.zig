const lm = @import("loom");
const std = @import("std");

const gbl = @import("global/global.zig");

pub fn main() !void {
    lm.project(.{
        .window = .{
            .title = "artegame",
            .resizable = true,
            .restore_state = true,
            .size = .init(1280, 720),
            .clear_color = lm.Color.black,
            .exit_key = .null,
        },
        .asset_paths = .{
            .debug = "src/assets/",
        },
    })({
        lm.scene("default")({
            lm.globalBehaviours(.{
                gbl.Setup{},
                gbl.HUD{},
            });

            lm.cameras(&.{
                lm.CameraConfig{ .id = "main", .options = .{
                    .display = .fullscreen,
                    .draw_mode = .world,
                    .zoom = 1,
                } },
            });
        });

        lm.scene("demo_map")({
            lm.useMainCamera();

            lm.globalBehaviours(.{
                gbl.DemoMap{},
                gbl.HUD{},
            });
        });
    });
}

test {
    _ = @import("global/boons/BoonPool.zig");
    _ = @import("components/Weapons/Spell.zig");
    _ = @import("components/effects/Effect.zig");
    _ = @import("components/effects/EffectVisual.zig");
    _ = @import("components/Stats.zig");
}
