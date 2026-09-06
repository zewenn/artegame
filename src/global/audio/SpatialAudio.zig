const std = @import("std");
const lm = @import("loom");
const AudioManager = @import("AudioManager.zig");

pub const SpatialParams = struct {
    falloff: f32,
    pan: f32,
};

pub fn calculateSpatialParams(source_pos: lm.Vector2, listener_pos: lm.Vector2, max_dist: f32) ?SpatialParams {
    if (max_dist <= 0.0) return null;

    const dx = source_pos.x - listener_pos.x;
    const dy = source_pos.y - listener_pos.y;
    const dist = std.math.hypot(dx, dy);

    if (dist >= max_dist) return null;

    const normalized_dist = dist / max_dist;
    const falloff = (1.0 - normalized_dist) * (1.0 - normalized_dist);

    const pan_span = @max(1.0, max_dist * 0.5);
    const pan = std.math.clamp(dx / pan_span, -1.0, 1.0);

    return SpatialParams{
        .falloff = falloff,
        .pan = pan,
    };
}

pub fn playSpatial(path: []const u8, source_pos: lm.Vector2, listener_pos: lm.Vector2, max_dist: f32, base_vol: f32) void {
    playSpatialPitched(path, source_pos, listener_pos, max_dist, base_vol, 0.0);
}

pub fn playSpatialPitched(path: []const u8, source_pos: lm.Vector2, listener_pos: lm.Vector2, max_dist: f32, base_vol: f32, pitch_variance: f32) void {
    const params = calculateSpatialParams(source_pos, listener_pos, max_dist) orelse return;

    const vol = AudioManager.effectiveSfx(base_vol * params.falloff);
    if (vol <= 0.001) return;

    const pitch = if (pitch_variance > 0.0)
        lm.randFloat(f32, 1.0 - pitch_variance, 1.0 + pitch_variance)
    else
        1.0;

    lm.audio.playAdvanced(path, .{
        .volume = vol,
        .pitch = pitch,
        .pan = params.pan,
    }) catch {};
}

test "calculateSpatialParams distance and panning" {
    const listener = lm.Vector2.init(0, 0);

    const center = calculateSpatialParams(.init(0, 0), listener, 100.0);
    try std.testing.expect(center != null);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), center.?.falloff, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), center.?.pan, 0.01);

    const left = calculateSpatialParams(.init(-50, 0), listener, 100.0);
    try std.testing.expect(left != null);
    try std.testing.expect(left.?.pan < -0.9);
    try std.testing.expect(left.?.falloff < 1.0 and left.?.falloff > 0.0);

    const right = calculateSpatialParams(.init(50, 0), listener, 100.0);
    try std.testing.expect(right != null);
    try std.testing.expect(right.?.pan > 0.9);

    const outside = calculateSpatialParams(.init(150, 0), listener, 100.0);
    try std.testing.expectEqual(@as(?SpatialParams, null), outside);
}
