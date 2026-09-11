const std = @import("std");
const lm = @import("loom");

const Interactable = @import("../components/interaction/Interactable.zig");
const RoomManager = @import("../global/RoomManager.zig");
const AudioManager = @import("../global/audio/AudioManager.zig");

fn onExitDoorInteract(interactable: *Interactable, player: *lm.Entity) void {
    _ = interactable;
    _ = player;
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.9, 0.05);
    RoomManager.enterNextRoom() catch |err| {
        std.log.err("Failed to enter next room: {any}", .{err});
    };
}

pub fn ExitDoor(position: lm.Vector2) !*lm.Entity {
    return try lm.makeEntity("exit-door", .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(96, 96),
        },
        lm.Renderer.sprite("ui/icons/empty_icon.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .static,
            .transform = .{
                .scale = .init(48, 48),
            },
        }),
        Interactable{
            .action_text = "Enter Next Room",
            .interaction_radius = 110.0,
            .prompt_offset = .init(0, -64.0),
            .can_interact = RoomManager.isReplenish,
            .on_interact = onExitDoorInteract,
        },
    });
}
