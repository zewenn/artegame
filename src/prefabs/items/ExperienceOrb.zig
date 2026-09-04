const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const ExperienceOrbComponent = @import("../../components/items/ExperienceOrb.zig");

var experience_orb_count: u32 = 0;

pub fn ExperienceOrb(position: lm.Vector2, experience_value: usize, initial_velocity: lm.Vector2) !*lm.Entity {
    defer experience_orb_count +%= 1;

    return try lm.makeEntityI("experience-orb", experience_orb_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(24, 24),
        },
        lm.Renderer.sprite("ui/sleep_icon.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .trigger,
            .transform = .{ .scale = .init(24, 24) },
            .onCollision = ExperienceOrbComponent.onCollision,
        }),
        ExperienceOrbComponent{
            .experience_value = experience_value,
            .velocity = initial_velocity,
        },
    });
}
