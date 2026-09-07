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
                gbl.MainMenu{},
                gbl.MusicManager{},
            });
        });

        lm.scene("demo_map")({
            lm.useMainCamera();

            lm.globalBehaviours(.{
                gbl.DemoMap{},
                gbl.HUD{},
                gbl.MusicManager{},
            });
        });
    });
}

test {
    _ = @import("global/ui/MainMenu.zig");
    _ = @import("global/ui/PauseMenu.zig");
    _ = @import("global/ui/OptionsMenu.zig");
    _ = @import("global/ui/BoonMenu.zig");
    _ = @import("global/ui/GameOverMenu.zig");
    _ = @import("global/DemoMap.zig");
    _ = @import("global/boons/BoonPool.zig");
    _ = @import("components/Weapons/Weapon.zig");
    _ = @import("components/Weapons/spells.zig");
    _ = @import("components/Weapons/Spell.zig");
    _ = @import("global/save/SaveData.zig");
    _ = @import("global/save/SaveSystem.zig");
    _ = @import("components/effects/Effect.zig");
    _ = @import("components/effects/EffectVisual.zig");
    _ = @import("components/Stats.zig");
    _ = @import("global/audio/AudioManager.zig");
    _ = @import("global/audio/MusicManager.zig");
    _ = @import("global/audio/SpatialAudio.zig");
    _ = @import("components/enemy/Ability.zig");
    _ = @import("components/enemy/OverheadUI.zig");
    _ = @import("global/spawner/RoundSpawner.zig");
}
