const Weapon = @import("Weapon.zig");

pub const fists: Weapon = .{
    .id = "Fists",
    .light_attack = .{
        .projectile_options = .{
            .damage_multiplier = 0.5,
            .size = .init(32, 64),
        },
    },
    .heavy_attack = .{
        .projectile_options = .{ .damage_multiplier = 1.2, .is_crit = true, .size = .init(96, 64) },
    },
    .dash_attack = .{
        .shooting_degrees = &.{ -2, 0, 2 },
        .projectile_options = .{
            .damage_multiplier = 2,
            .speed = 1200,
            .size = .init(128, 64),
            .passtrough = true,
        },
    },

    .type = .close,

    .sprite_right = "gloves_0.png",
    .sprite_left = "gloves_1.png",
};

pub const goliath: Weapon = .{
    .id = "Goliath",
    .light_attack = .{
        .shooting_degrees = &.{ -10, 0, 10 },
        .projectile_options = .{
            .damage_multiplier = 0.3,
        },
    },

    .type = .wide,

    .sprite_left = "plates_1.png",
    .sprite_right = "plates_0.png",
};
