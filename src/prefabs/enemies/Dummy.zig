const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Enemy = @import("../../components/enemy/export.zig");

var dummy_enemy_count: u32 = 0;

pub fn DummyEnemy(position: lm.Vector2) !*lm.Entity {
    defer dummy_enemy_count +%= 1;

    return try lm.makeEntityI("dummy-enemy", dummy_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(64, 64),
        },
        lm.Renderer.sprite("characters/enemies/dummy.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(56, 56) },
            .weight = 100.0,
        }),
        Stats.init(.enemy, .{
            .health = 150,
            .attack_speed = 0,
            .armour = 0,
            .movement_speed = 0,
            .aggro_range = 0,
        }),
        StatusOverlays{},
        Enemy.Death{ .enemy_type = .dummy },
    });
}
