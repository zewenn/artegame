const std = @import("std");
const lm = @import("loom");

const Interactable = @import("../components/interaction/Interactable.zig");
const DemoMap = @import("../global/DemoMap.zig");
const AudioManager = @import("../global/audio/AudioManager.zig");

fn onRoundActivatorInteract(interactable: *Interactable, player: *lm.Entity) void {
    _ = interactable;
    _ = player;
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.9, 0.05);
    DemoMap.startRound() catch |err| {
        std.log.err("Failed to start round from activator: {any}", .{err});
    };

    const activator = lm.getEntity(.{ .id = "round-activator" }) orelse return;
    const renderer = activator.getComponent(lm.Renderer) orelse return;

    renderer.img_path = "items/activator_shrine2.png";
}

pub fn RoundActivator(position: lm.Vector2) !*lm.Entity {
    return try lm.makeEntity("round-activator", .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(128, 128),
        },
        lm.Renderer.sprite("items/activator_shrine1.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .static,
            .transform = .{
                .scale = .init(32, 64),
            },
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
