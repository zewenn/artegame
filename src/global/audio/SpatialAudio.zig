const std = @import("std");
const lm = @import("loom");
const AudioManager = @import("AudioManager.zig");

pub const SpatialParams = struct {
    falloff: f32,
    pan: f32,
};

pub fn calculateSpatialParams(source_position: lm.Vector2, listener_position: lm.Vector2, max_distance_pixels: f32) ?SpatialParams {
    if (max_distance_pixels <= 0.0) return null;

    const delta_x = source_position.x - listener_position.x;
    const delta_y = source_position.y - listener_position.y;
    const distance_pixels = std.math.hypot(delta_x, delta_y);

    if (distance_pixels >= max_distance_pixels) return null;

    const normalized_distance = distance_pixels / max_distance_pixels;
    const falloff = (1.0 - normalized_distance) * (1.0 - normalized_distance);

    const pan_span_pixels = @max(1.0, max_distance_pixels * 0.5);
    const pan = std.math.clamp(delta_x / pan_span_pixels, -1.0, 1.0);

    return SpatialParams{
        .falloff = falloff,
        .pan = pan,
    };
}

pub fn playSpatial(
    path: []const u8,
    source_position: lm.Vector2,
    listener_position: lm.Vector2,
    max_distance_pixels: f32,
    base_volume: f32,
) void {
    playSpatialPitched(path, source_position, listener_position, max_distance_pixels, base_volume, 0.0);
}

pub fn playSpatialPitched(
    path: []const u8,
    source_position: lm.Vector2,
    listener_position: lm.Vector2,
    max_distance_pixels: f32,
    base_volume: f32,
    pitch_variance: f32,
) void {
    const params = calculateSpatialParams(source_position, listener_position, max_distance_pixels) orelse return;

    const volume = AudioManager.effectiveSfx(base_volume * params.falloff);
    if (volume <= 0.001) return;

    const pitch = if (pitch_variance > 0.0)
        lm.randFloat(f32, 1.0 - pitch_variance, 1.0 + pitch_variance)
    else
        1.0;

    lm.audio.playAdvanced(path, .{
        .volume = volume,
        .pitch = pitch,
        .pan = params.pan,
    }) catch {};
}

test "calculateSpatialParams distance and panning" {
    const listener_position = lm.Vector2.init(0, 0);

    const center = calculateSpatialParams(.init(0, 0), listener_position, 100.0);
    try std.testing.expect(center != null);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), center.?.falloff, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), center.?.pan, 0.01);

    const left = calculateSpatialParams(.init(-50, 0), listener_position, 100.0);
    try std.testing.expect(left != null);
    try std.testing.expect(left.?.pan < -0.9);
    try std.testing.expect(left.?.falloff < 1.0 and left.?.falloff > 0.0);

    const right = calculateSpatialParams(.init(50, 0), listener_position, 100.0);
    try std.testing.expect(right != null);
    try std.testing.expect(right.?.pan > 0.9);

    const outside = calculateSpatialParams(.init(150, 0), listener_position, 100.0);
    try std.testing.expectEqual(@as(?SpatialParams, null), outside);
}
