const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Effect = @import("Effect.zig");
const EffectType = Effect.EffectType;
const EffectVisual = @import("EffectVisual.zig").EffectVisual;
const EffectVisualRegistry = @import("EffectVisual.zig").EffectVisualRegistry;

const Self = @This();

pub const CachedTexture = struct {
    path: []const u8,
    scale: lm.Vector2,
    texture: *lm.Texture,
};

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
textures: ?lm.List(CachedTexture) = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    if (self.textures == null) {
        self.textures = lm.List(CachedTexture).init(lm.allocators.scene());
    }
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    _ = entity;
    const stats = self.stats orelse return;
    const base_transform = self.transform orelse return;
    const effects_list = stats.effects orelse return;

    var rendered_effect_types: std.EnumSet(EffectType) = .empty;
    var layer_index: usize = 0;

    for (effects_list.items()) |effect| {
        const visual = EffectVisualRegistry.resolve(effect) orelse continue;
        const current_frame_path = visual.getCurrentFrame(effect.anim_time) orelse continue;

        if (effect.effect_type != .custom) {
            if (rendered_effect_types.contains(effect.effect_type)) continue;
            rendered_effect_types.insert(effect.effect_type);
        }

        self.renderEffectOverlay(base_transform, effect, visual, current_frame_path, layer_index);
        layer_index += 1;
    }

    self.pruneUnusedTextures(effects_list.items());
}

pub fn End(self: *Self) void {
    if (self.textures) |*texture_list| {
        for (texture_list.items()) |cached_texture| {
            lm.assets.texture.release(cached_texture.path, &.{ lm.toi32(cached_texture.scale.x), lm.toi32(cached_texture.scale.y) });
        }
        texture_list.deinit();
        self.textures = null;
    }
}

fn renderEffectOverlay(
    self: *Self,
    base_transform: *lm.Transform,
    effect: Effect,
    visual: EffectVisual,
    frame_path: []const u8,
    layer_index: usize,
) void {
    const texture = self.getOrLoadTexture(frame_path, visual.scale) orelse return;
    const rotation = visual.getRotation(effect.anim_time);

    const layer_z_offset = 1.0 + @as(f32, @floatFromInt(layer_index));
    const overlay_position = base_transform.position
        .add(lm.vec2ToVec3(visual.offset))
        .add(.init(0, 0, layer_z_offset));

    lm.display.addRenderer(.{
        .renderer = .{ .texture = .{
            .texture = texture.*,
            .transform = lm.Transform{
                .position = overlay_position,
                .rotation = rotation,
                .scale = visual.scale,
            },
            .tint = visual.tint,
            .fill_color = null,
        } },
        .index = lm.toisize(overlay_position.z),
    }) catch return;
}

pub fn getOrLoadTexture(self: *Self, path: []const u8, scale: lm.Vector2) ?*lm.Texture {
    const texture_list = &(self.textures orelse return null);
    for (texture_list.items()) |cached_texture| {
        const is_same_path = std.mem.eql(u8, cached_texture.path, path);
        const is_same_scale = cached_texture.scale.x == scale.x and cached_texture.scale.y == scale.y;
        if (is_same_path and is_same_scale) {
            return cached_texture.texture;
        }
    }

    const texture = lm.assets.texture.get(path, &.{ lm.toi32(scale.x), lm.toi32(scale.y) }) orelse return null;
    texture_list.append(.{
        .path = path,
        .scale = scale,
        .texture = texture,
    }) catch {
        lm.assets.texture.releasePtr(texture);
        return null;
    };

    return texture;
}

fn pruneUnusedTextures(self: *Self, active_effects: []const Effect) void {
    const texture_list = &(self.textures orelse return);
    const texture_count = texture_list.len();

    for (1..texture_count + 1) |step| {
        const index = texture_count - step;
        const cached_texture = texture_list.items()[index];

        if (!isTextureUsedByEffects(cached_texture, active_effects)) {
            lm.assets.texture.release(cached_texture.path, &.{ lm.toi32(cached_texture.scale.x), lm.toi32(cached_texture.scale.y) });
            _ = texture_list.swapRemove(index);
        }
    }
}

fn isTextureUsedByVisual(cached_texture: CachedTexture, visual: EffectVisual) bool {
    const is_same_scale = cached_texture.scale.x == visual.scale.x and cached_texture.scale.y == visual.scale.y;
    if (!is_same_scale) return false;

    for (visual.frames) |frame_path| {
        if (std.mem.eql(u8, cached_texture.path, frame_path)) {
            return true;
        }
    }

    return false;
}

pub fn isTextureUsedByEffects(cached_texture: CachedTexture, active_effects: []const Effect) bool {
    for (active_effects) |effect| {
        const visual = EffectVisualRegistry.resolve(effect) orelse continue;
        if (isTextureUsedByVisual(cached_texture, visual)) {
            return true;
        }
    }

    return false;
}

test "isTextureUsedByEffects returns true for active effect texture and false for unrelated" {
    var dummy_texture: lm.Texture = undefined;
    const stun_texture = CachedTexture{
        .path = "effects/stun/stun_1.png",
        .scale = .init(64, 64),
        .texture = &dummy_texture,
    };
    const sleep_texture = CachedTexture{
        .path = "effects/sleep/sleep_1.png",
        .scale = .init(64, 64),
        .texture = &dummy_texture,
    };

    const active_effects = [_]Effect{
        .{
            .id = "stun",
            .effect_type = .stun,
        },
        .{
            .id = "root",
            .effect_type = .root,
            .visual = EffectVisual{
                .frames = &.{},
            },
        },
    };

    try std.testing.expect(isTextureUsedByEffects(stun_texture, &active_effects));
    try std.testing.expect(!isTextureUsedByEffects(sleep_texture, &active_effects));
}

test "isTextureUsedByEffects checks scale match" {
    var dummy_texture: lm.Texture = undefined;
    const wrong_scale_texture = CachedTexture{
        .path = "effects/stun/stun_1.png",
        .scale = .init(32, 32),
        .texture = &dummy_texture,
    };
    const active_effects = [_]Effect{
        .{
            .id = "stun",
            .effect_type = .stun,
        },
    };

    try std.testing.expect(!isTextureUsedByEffects(wrong_scale_texture, &active_effects));
}

test "isTextureUsedByEffects matches when second effect has the texture" {
    var dummy_texture: lm.Texture = undefined;
    const root_texture = CachedTexture{
        .path = "effects/root.png",
        .scale = .init(64, 64),
        .texture = &dummy_texture,
    };
    const active_effects = [_]Effect{
        .{
            .id = "stun",
            .effect_type = .stun,
        },
        .{
            .id = "root",
            .effect_type = .root,
        },
    };

    try std.testing.expect(isTextureUsedByEffects(root_texture, &active_effects));
}
