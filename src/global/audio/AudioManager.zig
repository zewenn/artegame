const std = @import("std");
const lm = @import("loom");

pub const Sfx = enum {
    punch,
    click,
    boom,
    coin,
    pickup,
    dash,
    walking,

    const paths = std.EnumArray(Sfx, []const u8).init(.{
        .punch = "audio/sfx/punch.mp3",
        .click = "audio/sfx/click.wav",
        .boom = "audio/sfx/boom.wav",
        .coin = "audio/sfx/coin.wav",
        .pickup = "audio/sfx/pickup.mp3",
        .dash = "audio/sfx/dash.wav",
        .walking = "audio/sfx/walking.mp3",
    });

    pub fn path(self: Sfx) []const u8 {
        return paths.get(self);
    }
};

pub var master_volume: f32 = 1.0;
pub var music_volume: f32 = 0.7;
pub var sfx_volume: f32 = 0.8;
pub var mute: bool = false;

fn effectiveChannelVolume(channel_volume: f32, base_volume: f32) f32 {
    if (mute) return 0.0;
    return std.math.clamp(master_volume * channel_volume * base_volume, 0.0, 1.0);
}

pub fn effectiveSfx(base_volume: f32) f32 {
    return effectiveChannelVolume(sfx_volume, base_volume);
}

pub fn effectiveMusic(base_volume: f32) f32 {
    return effectiveChannelVolume(music_volume, base_volume);
}

pub fn playSfxPitched(sound_path: []const u8, base_volume: f32, pitch_variance: f32) void {
    const volume = effectiveSfx(base_volume);
    if (volume <= 0.001) return;

    const pitch = if (pitch_variance > 0.0)
        lm.randFloat(f32, 1.0 - pitch_variance, 1.0 + pitch_variance)
    else
        1.0;

    lm.audio.playAdvanced(sound_path, .{
        .volume = volume,
        .pitch = pitch,
        .pan = 0.0,
    }) catch {};
}

pub fn setMasterVolume(volume: f32) void {
    master_volume = std.math.clamp(volume, 0.0, 1.0);
}

pub fn setMusicVolume(volume: f32) void {
    music_volume = std.math.clamp(volume, 0.0, 1.0);
}

pub fn setSfxVolume(volume: f32) void {
    sfx_volume = std.math.clamp(volume, 0.0, 1.0);
}

pub fn toggleMute() void {
    mute = !mute;
}

pub fn setMute(muted: bool) void {
    mute = muted;
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

test "AudioManager Sfx enum resolves expected asset paths" {
    try std.testing.expectEqualStrings("audio/sfx/punch.mp3", Sfx.punch.path());
    try std.testing.expectEqualStrings("audio/sfx/click.wav", Sfx.click.path());
    try std.testing.expectEqualStrings("audio/sfx/dash.wav", Sfx.dash.path());
}
