const Weapon = @import("Weapon.zig");

pub const fists: Weapon = .{
    .id = "Fists",
    .light_attack = .{
        .projectile_options = .{
            .damage_multiplier = 0.5,
        },
    },
    .heavy_attack = .{
        .projectile_options = .{ .damage_multiplier = 1.2, .is_crit = true, .size = .init(96, 64) },
    },
    .dash_attack = .{
        .projectile_options = .{
            .damage_multiplier = 2,
            .size = .init(128, 64),
            .passtrough = true,
        },
    },
};

pub const goliath: Weapon = .{
    .id = "Goliath",
    .light_attack = .{
        .shooting_degrees = &.{ -10, 0, 10 },
        .projectile_options = .{
            .damage_multiplier = 0.3,
        },
    },
};
