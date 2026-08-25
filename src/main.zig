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
