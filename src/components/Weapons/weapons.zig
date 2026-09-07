const Weapon = @import("Weapon.zig");

pub const fists: Weapon = .{
    .id = "Fists",
    .light_attack = .{
        .projectile_options = .{
            .damage = 0.85,
            .size = .init(32, 64),
            .knockback_duration = 0.2,
            .knockback_strength = 0.5,
        },
    },
    .heavy_attack = .{
        .projectile_options = .{
            .damage = 1.2,
            .is_crit = true,
            .size = .init(96, 64),

            .onhit_effect = .stun,
            .onhit_duration = 1,
            .onhit_strength = 2,
        },
    },
    .dash_attack = .{
        .shooting_degrees = &.{ -2, 0, 2 },
        .projectile_options = .{
            .damage = 20,
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
        .projectile_options = .{
            .damage = 0.3,
            .knockback_duration = 0.25,
            .knockback_strength = -0.05,
            .passtrough = true,
        },
    },

    .type = .wide,

    .sprite_left = "weapons/plates/plates_1.png",
    .sprite_right = "weapons/plates/plates_0.png",
};
