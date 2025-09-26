const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");

var basic_enemy_count: u32 = 0;

pub fn BasicEnemy(position: lm.Vector2) !*lm.Entity {
    return try lm.makeEntityI("basic-enemy", basic_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
        },
        lm.Renderer.sprite("enemy_melee_left_1.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),

        Stats{
            .team = .enemy,
            .current = .{
                .attack_speed = 2,
                .armour = 30,
                .movement_speed = 125,
                .aggro_range = 900,
            },
        },
        Dashing{},

        Enemy.Movement{},
        Enemy.Death{},
        Enemy.Attack.init(.{
            .lifetime = 5,
        }),
        Enemy.HealthBar{},
    });
}
