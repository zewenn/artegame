const std = @import("std");
const lm = @import("loom");

const Interactable = @import("../../components/interaction/Interactable.zig");
const HUD = @import("../../global/HUD.zig");
const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const BoonPool = @import("../../global/boons/BoonPool.zig");
const AudioManager = @import("../../global/audio/AudioManager.zig");

var boon_drop_count: u32 = 0;

fn onBoonDropInteract(interactable: *Interactable, player: *lm.Entity) void {
    _ = interactable;
    AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);
    const stats = player.getComponent(Stats) orelse return;
    const attack = player.getComponent(Attack) orelse return;

    const available_slots = BoonPool.getSlots(stats.*, attack.*);
    HUD.showBoons(available_slots);
}

pub fn BoonDrop(position: lm.Vector2) !*lm.Entity {
    defer boon_drop_count +%= 1;

    return try lm.makeEntityI("boon-drop", boon_drop_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(48, 48),
        },
        lm.Renderer.sprite("ui/icons/empty_icon.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .trigger,
            .transform = .{ .scale = .init(48, 48) },
        }),
        Interactable{
            .action_text = "Choose Boons",
            .interaction_radius = 90.0,
            .prompt_offset = .init(0, -48.0),
            .on_interact = onBoonDropInteract,
        },
    });
}
