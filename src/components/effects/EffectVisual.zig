const std = @import("std");
const lm = @import("loom");
const Effect = @import("Effect.zig");
const EffectType = Effect.EffectType;

pub const EffectVisual = struct {
    frames: []const []const u8 = &.{},
    frame_duration: f32 = 0.1,
    offset: lm.Vector2 = .init(0, 32),
    scale: lm.Vector2 = .init(32, 32),
    icon: ?[]const u8 = null,

    pub fn getFrameIndex(self: EffectVisual, animation_elapsed_seconds: f32) usize {
        if (self.frames.len == 0) return 0;
        if (self.frame_duration <= 0) return 0;
        if (animation_elapsed_seconds <= 0) return 0;

        const total_frames = @as(usize, @intFromFloat(animation_elapsed_seconds / self.frame_duration));
        return total_frames % self.frames.len;
    }

    pub fn getCurrentFrame(self: EffectVisual, animation_elapsed_seconds: f32) ?[]const u8 {
        if (self.frames.len == 0) return null;
        const frame_index = self.getFrameIndex(animation_elapsed_seconds);
        return self.frames[frame_index];
    }
};

pub const EffectVisualRegistry = struct {
    const default_visuals = std.EnumArray(EffectType, ?EffectVisual).init(.{
        .stun = .{
            .icon = "ui/icons/stun_icon.png",
            .frames = &.{
                "effects/stun/stun_1.png",
                "effects/stun/stun_2.png",
                "effects/stun/stun_3.png",
                "effects/stun/stun_4.png",
            },
            .frame_duration = 0.1,
            .offset = .init(0, 0),
            .scale = .init(64, 64),
        },
        .sleep = .{
            .frames = &.{"effects/sleep_effect.png"},
            .frame_duration = 0.2,
            .offset = .init(0, 0),
            .scale = .init(64, 64),
            .icon = "ui/icons/sleep_icon.png",
        },
        .root = .{
            .icon = "ui/icons/root_icon.png",
            .frames = &.{"effects/root.png"},
            .frame_duration = 0.2,
            .offset = .init(0, 0),
            .scale = .init(64, 64),
        },
        .regen = .{
            .frames = &.{
                "effects/heal_effect_0.png",
                "effects/heal_effect_1.png",
            },
            .frame_duration = 0.1,
            .offset = .init(0, 0),
            .scale = .init(64, 64),
            .icon = "ui/icons/heal_icon.png",
        },
        .haste = .{
            .icon = "ui/icons/haste_icon.png",
        },
        .goliath = .{
            .icon = "ui/icons/goliath_icon.png",
        },
        .slow = .{
            .frames = &.{
                "effects/slow/slow_1.png",
                "effects/slow/slow_2.png",
            },
            .icon = "ui/icons/slow_icon.png",
            .scale = .init(64, 64),
            .offset = .init(0, 0),
            .frame_duration = 0.1,
        },
        .stasis = .{
            .icon = "ui/icons/stasis_icon.png",
            .frames = &.{"effects/stasis.png"},
            .scale = .init(64, 64),
            .offset = .init(0, 0),
        },
        .bond_of_life = .{
            .icon = "ui/icons/bond_of_life.png",
            .frame_duration = 0.2,
            .frames = &.{
                "effects/bond_of_life/bond_of_life_1.png",
                "effects/bond_of_life/bond_of_life_2.png",
            },
            .scale = .init(64, 64),
            .offset = .init(0, 0),
        },
        .weaken = null,
        .custom = null,
    });

    pub fn resolve(effect: Effect) ?EffectVisual {
        if (effect.visual) |visual| return visual;
        return getDefault(effect.effect_type);
    }

    pub fn getDefault(effect_type: EffectType) ?EffectVisual {
        return default_visuals.get(effect_type);
    }
};

test "EffectVisual frame index calculation" {
    const visual = EffectVisual{
        .frames = &.{ "f0.png", "f1.png", "f2.png" },
        .frame_duration = 0.1,
    };

    try std.testing.expectEqual(@as(usize, 0), visual.getFrameIndex(0.0));
    try std.testing.expectEqual(@as(usize, 0), visual.getFrameIndex(0.05));
    try std.testing.expectEqual(@as(usize, 1), visual.getFrameIndex(0.15));
    try std.testing.expectEqual(@as(usize, 2), visual.getFrameIndex(0.25));

    try std.testing.expectEqual(@as(usize, 0), visual.getFrameIndex(0.30));
    try std.testing.expectEqual(@as(usize, 1), visual.getFrameIndex(0.40));
}

test "EffectVisualRegistry resolve precedence" {
    const default_stun = Effect{
        .id = "stun",
        .effect_type = .stun,
    };
    const resolved_default = EffectVisualRegistry.resolve(default_stun);
    try std.testing.expect(resolved_default != null);
    try std.testing.expectEqual(@as(usize, 4), resolved_default.?.frames.len);

    const custom_stun = Effect{
        .id = "custom_stun",
        .effect_type = .stun,
        .visual = EffectVisual{
            .frames = &.{"custom_star.png"},
            .offset = .init(0, 50),
        },
    };
    const resolved_custom = EffectVisualRegistry.resolve(custom_stun);
    try std.testing.expect(resolved_custom != null);
    try std.testing.expectEqual(@as(usize, 1), resolved_custom.?.frames.len);
    try std.testing.expectEqualStrings("custom_star.png", resolved_custom.?.frames[0]);
    try std.testing.expectEqual(@as(f32, 50), resolved_custom.?.offset.y);
}

test "EffectVisualRegistry weaken default is null and explicit empty visual suppresses regen default" {
    const weaken_effect = Effect{
        .id = "test_weaken",
        .effect_type = .weaken,
    };
    try std.testing.expect(EffectVisualRegistry.resolve(weaken_effect) == null);

    const silent_regen = Effect{
        .id = "silent_regen",
        .effect_type = .regen,
        .visual = .{},
    };
    const resolved_silent = EffectVisualRegistry.resolve(silent_regen);
    try std.testing.expect(resolved_silent != null);
    try std.testing.expect(resolved_silent.?.getCurrentFrame(0.0) == null);
    try std.testing.expect(resolved_silent.?.icon == null);
}
