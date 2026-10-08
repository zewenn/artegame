const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const TrainingDummyBehaviour = @import("../../components/enemy/TrainingDummyBehaviour.zig");

pub fn TrainingDummy(position: lm.Vector2) !*lm.Entity {
    return try lm.makeEntity("training-dummy", .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(64, 64),
        },
        lm.Renderer.sprite("characters/enemies/dummy.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(56, 56) },
            .weight = 1000.0,
        }),
        Stats.initUnstoppable(.enemy, .{
            .health = 99999.0,
            .attack_speed = 0.0,
            .armour = 0.0,
            .movement_speed = 0.0,
            .aggro_range = 0.0,
        }),
        StatusOverlays{},
        TrainingDummyBehaviour{},
    });
}
