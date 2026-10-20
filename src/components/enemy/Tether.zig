const std = @import("std");
const lm = @import("loom");

const Self = @This();

const Textures = struct {
    right: *lm.Texture,
    middle: []*lm.Texture,
    left: *lm.Texture,

    pub fn load(right: []const u8, left: []const u8, middle: []const []const u8) !Textures {
        var middle_sprites: lm.List(*lm.Texture) = .init(lm.allocators.generic());
        defer middle_sprites.deinit();

        for (middle) |img_path| {
            const texture = lm.assets.texture.get(img_path, &.{ 64, 64 }) orelse {
                std.log.err("Failed to load asset: {s}", .{img_path});
                continue;
            };

            try middle_sprites.append(texture);
        }

        return Textures{
            .right = lm.assets.texture.get(right, &.{ 64, 64 }) orelse return error.AssetNotFound,
            .middle = try middle_sprites.toOwnedSlice(),
            .left = lm.assets.texture.get(left, &.{ 64, 64 }) orelse return error.AssetNotFound,
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
anim_start: f32 = 0,
last_frame_change_time: f32 = 0,
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

pub fn startAnim(self: *Self) void {
    self.anim_start = lm.time.gameTime();
    self.last_frame_change_time = lm.time.gameTime();
}

pub fn render(self: *Self, start: lm.Vector2, end: lm.Vector2, distance: f32) !void {
    const textures = self.textures;
    const anim_percent = @min(1, (lm.time.gameTime() - self.anim_start) / self.build_time_seconds);

    if (anim_percent == 1 and !self.is_active) return;

    const start_vector = if (self.is_active) start else start.lerp(end, anim_percent);
    const end_vector = if (self.is_active) start.lerp(end, anim_percent) else end;

    const current_distance = if (self.is_active) distance * anim_percent else distance * (1.0 - anim_percent);

    const base_vector = lm.Vec2(1, 0);
    const delta_vector = end.subtract(start);
    const angle = std.math.radiansToDegrees(base_vector.angle(delta_vector));

    const middle_point = start_vector.lerp(end_vector, 0.5);
    const middle_width = @max(0.0, current_distance - 64.0);

    if (lm.time.gameTime() - self.last_frame_change_time >= self.frame_change_time_seconds) {
        self.last_frame_change_time = lm.time.gameTime();
        self.current_frame_index += 1;
        if (self.current_frame_index >= textures.middle.len) {
            self.current_frame_index = 0;
        }
    }

    try lm.display.add(.{
        .texture = textures.left.*,
        .transform = .{
            .position = .init(start_vector.x, start_vector.y, -100),
            .rotation = angle,
        },
        .display = .{
            .fill_color = null,
            .img_path = "",
            .tint = lm.Color.white,
        },
    });

    try lm.display.add(.{
        .texture = textures.right.*,
        .transform = .{
            .position = .init(end_vector.x, end_vector.y, -100),
            .rotation = angle,
        },
        .display = .{
            .fill_color = null,
            .img_path = "",
            .tint = lm.Color.white,
        },
    });

    if (textures.middle.len <= self.current_frame_index) return;

    const middle_texture = textures.middle[self.current_frame_index];
    try lm.display.add(.{
        .texture = middle_texture.*,
        .transform = .{
            .position = .init(middle_point.x, middle_point.y, -100),
            .rotation = angle,
            .scale = .init(middle_width, 64),
        },
        .display = .{
            .fill_color = null,
            .img_path = "",
            .tint = lm.Color.white,
        },
    });
}
