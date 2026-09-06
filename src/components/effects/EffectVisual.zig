const std = @import("std");
const lm = @import("loom");
const Effect = @import("Effect.zig");
const EffectType = Effect.EffectType;

pub const EffectVisual = struct {
    frames: []const []const u8 = &.{},

    frame_duration: f32 = 0.1,

    offset: lm.Vector2 = .init(0, 32),

    scale: lm.Vector2 = .init(32, 32),

    rotation_speed: f32 = 0,

    tint: lm.Color = lm.Color.white,

    icon: ?[]const u8 = null,

    loop: bool = true,

    pub fn getFrameIndex(self: EffectVisual, elapsed_time: f32) usize {
        if (self.frames.len == 0) return 0;
        if (self.frame_duration <= 0) return 0;
        if (elapsed_time <= 0) return 0;

        const total_frames = @as(usize, @intFromFloat(elapsed_time / self.frame_duration));
        if (!self.loop) {
            return @min(total_frames, self.frames.len - 1);
        }
        return total_frames % self.frames.len;
    }

    pub fn getCurrentFrame(self: EffectVisual, elapsed_time: f32) ?[]const u8 {
        if (self.frames.len == 0) return null;
        return self.frames[self.getFrameIndex(elapsed_time)];
    }
};

pub const EffectVisualRegistry = struct {
    pub fn resolve(effect: Effect) ?EffectVisual {
        if (effect.visual) |v| return v;
        return getDefault(effect.effect_type);
    }

    pub fn getDefault(effect_type: EffectType) ?EffectVisual {
        return switch (effect_type) {
            .stun => EffectVisual{
                .frames = &.{
                    "effects/stun_effect_1.png",
                    "effects/stun_effect_2.png",
                    "effects/stun_effect_3.png",
                    "effects/stun_effect_4.png",
                },
                .frame_duration = 0.1,
                .offset = .init(0, 0),
                .scale = .init(64, 64),
                .icon = "ui/empty_icon.png",
            },
            .sleep, .root => EffectVisual{
                .frames = &.{
                    "effects/sleep_effect.png",
                },
                .frame_duration = 0.2,
                .offset = .init(0, 0),
                .scale = .init(64, 64),
                .loop = true,
                .icon = "ui/sleep_icon.png",
            },
            .regen => EffectVisual{
                .frames = &.{
                    "effects/heal_effect_0.png",
                    "effects/heal_effect_1.png",
                },
                .frame_duration = 0.1,
                .offset = .init(0, 0),
                .scale = .init(64, 64),
                .icon = "ui/heal_icon.png",
            },
            .haste => EffectVisual{
                .icon = "ui/haste_icon.png",
            },
            .goliath => EffectVisual{
                .icon = "ui/goliath_icon.png",
            },
            .slow, .custom => null,
        };
    }
};

test "EffectVisual frame index calculation" {
    const visual = EffectVisual{
        .frames = &.{ "f0.png", "f1.png", "f2.png" },
        .frame_duration = 0.1,
        .loop = true,
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
