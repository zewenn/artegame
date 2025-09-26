const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const Dashing = @import("../components/Dashing.zig");
const player = @import("../components/player/export.zig");

var anchors: u32 = 0;
pub fn Anchor(position: lm.Vector2) !*lm.Entity {
    anchors += 1;

    return try lm.makeEntityI("anchor", anchors, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(64, 64),
        },
        lm.Renderer.sprite("empty_icon.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .static,
        }),
    });
}
