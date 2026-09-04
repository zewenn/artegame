const std = @import("std");
const lm = @import("loom");

const Interactable = @import("../components/interaction/Interactable.zig");
const HUD = @import("../global/HUD.zig");
const boons = @import("../global/boons/boons.zig");
const DemoMap = @import("../global/DemoMap.zig");

var shrine_count: u32 = 0;

fn onShrineInteract(interactable: *Interactable, player: *lm.Entity) void {
    _ = interactable;
    _ = player;
    HUD.showBoons(&.{ boons.all_boons[2], boons.all_boons[14], boons.all_boons[47] });
}

pub fn Shrine(position: lm.Vector2) !*lm.Entity {
    defer shrine_count +%= 1;

    return try lm.makeEntityI("shrine", shrine_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(48, 96),
        },
        lm.Renderer.sprite("items/turmix2000.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .static,
        }),
        Interactable{
            .action_text = "Choose Boons",
            .interaction_radius = 110.0,
            .prompt_offset = .init(0, -64.0),
            .can_interact = DemoMap.isReplenish,
            .on_interact = onShrineInteract,
        },
    });
}
