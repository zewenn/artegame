const Weapon = @import("Weapon.zig");

pub const fists: Weapon = .{
    .id = "Fists",
    .light_attack = .{
        .projectile_options = .{
            .damage = 0.91,
            .lifetime = 0.45,
            .size = .init(32, 64),
            .knockback_duration = 0.25,
            .knockback_strength = 1,
            .speed = 750,
        },
    },
    .heavy_attack = .{
        .shooting_degrees = &.{ -15, 0, 15 },
        .projectile_options = .{
            .damage = 1.25,
            .size = .init(16, 64),
            .lifetime = 0.65,
            .speed = 500,

            .onhit_effect = .stun,
            .onhit_duration = 1,
            .onhit_strength = 2,
            .override_sprite = "projectiles/player/heavy.png",
        },
    },
    .dash_attack = .{
        .shooting_degrees = &.{ -10, 0, 10 },
        .projectile_options = .{
            .damage = 0.534,
            .speed = 1200,
            .size = .init(128, 64),
            .passtrough = true,
        },
    },

    .type = .close,

    .sprite_right = "weapons/gloves/gloves_0.png",
    .sprite_left = "weapons/gloves/gloves_1.png",
};

pub const goliath: Weapon = .{
    .id = "Goliath",
    .light_attack = .{
        .shooting_degrees = &.{ 0, 10, -10 },
        .projectile_options = .{
            .damage = 0.4,
            .passtrough = true,
            .size = .init(96, 64),
            .lifetime = 0.45,
            .speed = 450,
        },
    },
    .heavy_attack = .{
        .projectile_options = .{
            .damage = 1.2,
            .onhit_effect = .stun,
            .onhit_duration = 1,
            .onhit_strength = 1,
            .lifetime = 0.55,
            .size = .init(86, 64),
            .speed = 550,
            .override_sprite = "projectiles/player/heavy.png",
        },
    },
    .dash_attack = .{
        .shooting_degrees = &.{ 0, -180, 45, -45, 90, -90, 135, -135 },
        .projectile_options = .{
            .size = .init(96, 64),
            .damage = 0.225,
            .passtrough = true,
            .onhit_effect = .slow,
            .onhit_duration = 1,
            .onhit_strength = 80,
            .lifetime = 0.5,
            .speed = 660,
        },
    },

    .type = .wide,

    .sprite_left = "weapons/plates/plates_1.png",
    .sprite_right = "weapons/plates/plates_0.png",
};
