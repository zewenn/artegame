const lm = @import("loom");
const std = @import("std");

const Setup = @import("global/setup.zig");
const HUD = @import("global/HUD.zig");

pub fn main() !void {
    lm.project(.{
        .window = .{
            .title = "artegame",
            .resizable = true,
            .restore_state = true,
            .size = .init(1280, 720),
        },
        .asset_paths = .{
            .debug = "src/assets/",
        },
    })({
        lm.scene("default")({
            lm.globalBehaviours(.{
                Setup{},
                HUD{},
            });

            lm.cameras(&.{
                lm.CameraConfig{ .id = "main", .options = .{
                    .display = .fullscreen,
                    .draw_mode = .world,
                    .zoom = 1,
                } },
            });
        });
    });
}
