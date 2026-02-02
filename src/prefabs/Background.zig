const lm = @import("loom");
const std = @import("std");

pub fn Background(w: i32, h: i32) !*lm.Entity {
    const width = w * 128;
    const height = h * 128;
    const COLLIDER_SIZE = 128;

    return try lm.makeEntity("background", .{
        lm.Transform{
            .position = lm.Vec3(0, 0, -100),
            .scale = lm.Vec2(width, height),
        },
        lm.Renderer.tile("bakcground_tile_2_32x32.png", .init(128, 128)),

        lm.RectangleCollider.initConfig(.{
            .transform = .{
                .position = lm.Vec3(-1 * w * 64, 0, 0),
                .scale = lm.Vec2(COLLIDER_SIZE, height),
            },
            .type = .dynamic,
            .weight = std.math.floatMax(f32),
        }),
        lm.RectangleCollider.initConfig(.{
            .transform = .{
                .position = lm.Vec3(w * 64, 0, 0),
                .scale = lm.Vec2(COLLIDER_SIZE, height),
            },
            .type = .dynamic,
            .weight = std.math.floatMax(f32),
        }),
        lm.RectangleCollider.initConfig(.{
            .transform = .{
                .position = lm.Vec3(0, -1 * h * 64, 0),
                .scale = lm.Vec2(width, COLLIDER_SIZE),
            },
            .type = .dynamic,
            .weight = std.math.floatMax(f32),
        }),
        lm.RectangleCollider.initConfig(.{
            .transform = .{
                .position = lm.Vec3(0, h * 64, 0),
                .scale = lm.Vec2(width, COLLIDER_SIZE),
            },
            .type = .dynamic,
            .weight = std.math.floatMax(f32),
        }),
    });
}
