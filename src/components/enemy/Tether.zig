const std = @import("std");
const lm = @import("loom");

const Self = @This();

const Textures = struct {
    right: *lm.Texture,
    middle: []*lm.Texture,
    left: *lm.Texture,

    pub fn load(right_path: []const u8, left_path: []const u8, middle_paths: []const []const u8) !Textures {
        var middle_sprites: lm.List(*lm.Texture) = .init(lm.allocators.generic());
        defer middle_sprites.deinit();

        for (middle_paths) |image_path| {
            const texture = lm.assets.texture.get(image_path, &.{ 64, 64 }) orelse {
                std.log.err("Failed to load asset: {s}", .{image_path});
                continue;
            };

            try middle_sprites.append(texture);
        }

        const right_texture = lm.assets.texture.get(right_path, &.{ 64, 64 }) orelse return error.AssetNotFound;
        const left_texture = lm.assets.texture.get(left_path, &.{ 64, 64 }) orelse return error.AssetNotFound;

        return Textures{
            .right = right_texture,
            .middle = try middle_sprites.toOwnedSlice(),
            .left = left_texture,
        };
    }

    pub fn unload(self: Textures) void {
        lm.assets.texture.releasePtr(self.right);
        lm.assets.texture.releasePtr(self.left);

        for (self.middle) |texture| {
            lm.assets.texture.releasePtr(texture);
        }
        lm.allocators.generic().free(self.middle);
    }
};

build_time_seconds: f32 = 0.15,
frame_change_time_seconds: f32 = 0.1,

textures: Textures,

is_active: bool = false,
animation_start_seconds: f32 = 0,
last_frame_change_seconds: f32 = 0,
current_frame_index: usize = 0,

pub fn init(
    textures: Textures,
    config: struct { build_time_seconds: f32 = 0.15, frame_change_time_seconds: f32 = 0.1 },
) Self {
    return Self{
        .textures = textures,
        .build_time_seconds = config.build_time_seconds,
        .frame_change_time_seconds = config.frame_change_time_seconds,
    };
}

pub fn deinit(self: *Self) void {
    self.textures.unload();
    self.* = undefined;
}

/// Updates activation state and starts the build/retract transition when toggled.
pub fn setActive(self: *Self, active: bool) void {
    if (self.is_active == active) return;
    self.is_active = active;
    self.startAnim();
}

pub fn startAnim(self: *Self) void {
    const now_seconds = lm.time.gameTime();
    self.animation_start_seconds = now_seconds;
    self.last_frame_change_seconds = now_seconds;
}

pub fn render(self: *Self, start_position: lm.Vector2, end_position: lm.Vector2, distance_pixels: f32) !void {
    const textures = self.textures;
    const now_seconds = lm.time.gameTime();
    const animation_progress = @min(1, (now_seconds - self.animation_start_seconds) / self.build_time_seconds);

    if (animation_progress == 1 and !self.is_active) return;

    const start_vector = if (self.is_active) start_position else start_position.lerp(end_position, animation_progress);
    const end_vector = if (self.is_active) start_position.lerp(end_position, animation_progress) else end_position;
    const current_distance_pixels = if (self.is_active) distance_pixels * animation_progress else distance_pixels * (1.0 - animation_progress);

    const base_vector = lm.Vec2(1, 0);
    const delta_vector = end_position.subtract(start_position);
    const angle_degrees = std.math.radiansToDegrees(base_vector.angle(delta_vector));

    const middle_point = start_vector.lerp(end_vector, 0.5);
    const middle_width_pixels = @max(0.0, current_distance_pixels - 64.0);

    if (now_seconds - self.last_frame_change_seconds >= self.frame_change_time_seconds) {
        self.last_frame_change_seconds = now_seconds;
        self.current_frame_index += 1;
        if (self.current_frame_index >= textures.middle.len) {
            self.current_frame_index = 0;
        }
    }

    try submitEndpointRenderer(textures.left.*, start_vector, angle_degrees);
    try submitEndpointRenderer(textures.right.*, end_vector, angle_degrees);

    if (textures.middle.len <= self.current_frame_index) return;

    const middle_texture = textures.middle[self.current_frame_index];
    try lm.display.addRenderer(.{
        .renderer = .{ .texture = .{
            .texture = middle_texture.*,
            .transform = .{
                .position = .init(middle_point.x, middle_point.y, -100),
                .rotation = angle_degrees,
                .scale = .init(middle_width_pixels, 64),
            },
            .tint = lm.Color.white,
            .fill_color = null,
        } },
        .index = -100,
    });
}

fn submitEndpointRenderer(texture: lm.Texture, position: lm.Vector2, angle_degrees: f32) !void {
    try lm.display.addRenderer(.{
        .renderer = .{ .texture = .{
            .texture = texture,
            .transform = .{
                .position = .init(position.x, position.y, -100),
                .rotation = angle_degrees,
            },
            .tint = lm.Color.white,
            .fill_color = null,
        } },
        .index = -100,
    });
}
