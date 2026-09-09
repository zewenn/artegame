const std = @import("std");
const lm = @import("loom");

const Interactable = @import("../components/interaction/Interactable.zig");
const HUD = @import("../global/HUD.zig");
const DemoMap = @import("../global/DemoMap.zig");
const Stats = @import("../components/Stats.zig");
const Attack = @import("../components/player/Attack.zig");
const BoonPool = @import("../global/boons/BoonPool.zig");
const AudioManager = @import("../global/audio/AudioManager.zig");

var shrine_count: u32 = 0;

fn onShrineInteract(interactable: *Interactable, player: *lm.Entity) void {
    _ = interactable;
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.8, 0.05);
    const stats = player.getComponent(Stats) orelse return;
    const attack = player.getComponent(Attack) orelse return;

    const available_slots = BoonPool.getSlots(stats.*, attack.*);
    HUD.showBoons(available_slots);
}

pub fn Shrine(position: lm.Vector2) !*lm.Entity {
    defer shrine_count +%= 1;

    return try lm.makeEntityI("shrine", shrine_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(128, 128),
        },
        lm.Renderer.sprite("items/bench_press_shrine.png"),
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
