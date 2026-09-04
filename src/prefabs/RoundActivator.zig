const std = @import("std");
const lm = @import("loom");

const Interactable = @import("../components/interaction/Interactable.zig");
const DemoMap = @import("../global/DemoMap.zig");

var round_activator_count: u32 = 0;

fn onRoundActivatorInteract(interactable: *Interactable, player: *lm.Entity) void {
    _ = interactable;
    _ = player;
    DemoMap.startRound() catch |err| {
        std.log.err("Failed to start round from activator: {any}", .{err});
    };
}

pub fn RoundActivator(position: lm.Vector2) !*lm.Entity {
    defer round_activator_count +%= 1;

    return try lm.makeEntityI("round-activator", round_activator_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(48, 96),
        },
        lm.Renderer.sprite("items/mixer.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .static,
        }),
        Interactable{
            .action_text = "Start Next Round",
            .interaction_radius = 110.0,
            .prompt_offset = .init(0, -64.0),
            .can_interact = DemoMap.isReplenish,
            .on_interact = onRoundActivatorInteract,
        },
    });
}
