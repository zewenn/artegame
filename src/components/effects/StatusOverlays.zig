const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Effect = @import("Effect.zig");
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
    const stats = self.stats orelse return;
    const transform = self.transform orelse return;
    const effects_list = stats.effects orelse return;

    for (effects_list.items()) |effect| {
        const visual = EffectVisualRegistry.resolve(effect) orelse continue;
        if (visual.frames.len == 0) continue;

        const current_frame_path = visual.getCurrentFrame(effect.anim_time) orelse continue;
        const texture = self.getOrLoadTexture(current_frame_path, visual.scale) orelse continue;

        const rotation = if (visual.rotation_speed != 0)
            @mod(effect.anim_time * visual.rotation_speed, 360.0)
        else
            0;

        const overlay_pos = transform.position
            .add(lm.vec2ToVec3(visual.offset))
            .add(.init(0, 0, 1.0));

        try lm.display.add(.{
            .texture = texture.*,
            .transform = lm.Transform{
                .position = overlay_pos,
                .rotation = rotation,
                .scale = visual.scale,
            },
            .display = .{
                .img_path = current_frame_path,
                .tint = visual.tint,
                .fill_color = null,
            },
            .entity = entity,
        });
    }

    self.pruneUnusedTextures(effects_list.items());
}

pub fn End(self: *Self) void {
    if (self.textures) |*tex_list| {
        for (tex_list.items()) |cached| {
            lm.assets.texture.release(cached.path, &.{ lm.toi32(cached.scale.x), lm.toi32(cached.scale.y) });
        }
        tex_list.deinit();
        self.textures = null;
    }
}

pub fn getOrLoadTexture(self: *Self, path: []const u8, scale: lm.Vector2) ?*lm.Texture {
    const tex_list = &(self.textures orelse return null);
    for (tex_list.items()) |cached| {
        if (std.mem.eql(u8, cached.path, path) and cached.scale.x == scale.x and cached.scale.y == scale.y) {
            return cached.texture;
        }
    }

    const tex = lm.assets.texture.get(path, &.{ lm.toi32(scale.x), lm.toi32(scale.y) }) orelse return null;
    tex_list.append(.{
        .path = path,
        .scale = scale,
        .texture = tex,
    }) catch return null;

    return tex;
}

fn pruneUnusedTextures(self: *Self, active_effects: []const Effect) void {
    const tex_list = &(self.textures orelse return);
    const len = tex_list.len();

    for (1..len + 1) |j| {
        const index = len - j;

        const cached = tex_list.items()[index];
        var is_used = false;

        for (active_effects) |eff| active: {
            const visual = EffectVisualRegistry.resolve(eff) orelse continue;

            for (visual.frames) |frame_path| {
                is_used =
                    std.mem.eql(u8, cached.path, frame_path) and
                    cached.scale.x == visual.scale.x and
                    cached.scale.y == visual.scale.y;

                if (is_used) break :active;
            }
        }

        if (!is_used) {
            lm.assets.texture.release(cached.path, &.{ lm.toi32(cached.scale.x), lm.toi32(cached.scale.y) });
            _ = tex_list.swapRemove(index);
        }
    }
}
