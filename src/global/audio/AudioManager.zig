const std = @import("std");
const lm = @import("loom");

pub var master_volume: f32 = 1.0;
pub var music_volume: f32 = 0.7;
pub var sfx_volume: f32 = 0.8;
pub var mute: bool = false;

pub fn effectiveSfx(base_vol: f32) f32 {
    if (mute) return 0.0;
    return std.math.clamp(master_volume * sfx_volume * base_vol, 0.0, 1.0);
}

pub fn effectiveMusic(base_vol: f32) f32 {
    if (mute) return 0.0;
    return std.math.clamp(master_volume * music_volume * base_vol, 0.0, 1.0);
}

pub fn playSfx(path: []const u8, base_vol: f32) void {
    playSfxPitched(path, base_vol, 0.0);
}

pub fn playSfxPitched(path: []const u8, base_vol: f32, pitch_variance: f32) void {
    const vol = effectiveSfx(base_vol);
    if (vol <= 0.001) return;

    const pitch = if (pitch_variance > 0.0)
        lm.randFloat(f32, 1.0 - pitch_variance, 1.0 + pitch_variance)
    else
        1.0;

    lm.audio.playAdvanced(path, .{
        .volume = vol,
        .pitch = pitch,
        .pan = 0.0,
    }) catch {};
}

pub fn setMasterVolume(vol: f32) void {
    master_volume = std.math.clamp(vol, 0.0, 1.0);
}

pub fn setMusicVolume(vol: f32) void {
    music_volume = std.math.clamp(vol, 0.0, 1.0);
}

pub fn setSfxVolume(vol: f32) void {
    sfx_volume = std.math.clamp(vol, 0.0, 1.0);
}

pub fn toggleMute() void {
    mute = !mute;
}

pub fn setMute(m: bool) void {
    mute = m;
}

test "AudioManager effective volume calculation" {
    master_volume = 1.0;
    music_volume = 0.7;
    sfx_volume = 0.8;
    mute = false;

    try std.testing.expectApproxEqAbs(@as(f32, 0.8), effectiveSfx(1.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), effectiveMusic(1.0), 0.001);

    master_volume = 0.5;
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), effectiveSfx(1.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.35), effectiveMusic(1.0), 0.001);

    setMute(true);
    try std.testing.expectEqual(@as(f32, 0.0), effectiveSfx(1.0));
    try std.testing.expectEqual(@as(f32, 0.0), effectiveMusic(1.0));

    master_volume = 1.0;
    music_volume = 0.7;
    sfx_volume = 0.8;
    mute = false;
}
