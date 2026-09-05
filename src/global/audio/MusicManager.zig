const std = @import("std");
const builtin = @import("builtin");
const lm = @import("loom");
const AudioManager = @import("AudioManager.zig");

const rl = if (builtin.is_test) struct {
    pub const Music = struct {
        looping: bool = false,
    };
    pub fn loadMusicStream(_: [:0]const u8) !Music {
        return Music{};
    }
    pub fn unloadMusicStream(_: Music) void {}
    pub fn playMusicStream(_: Music) void {}
    pub fn updateMusicStream(_: Music) void {}
    pub fn stopMusicStream(_: Music) void {}
    pub fn setMusicVolume(_: Music, _: f32) void {}
    pub fn isMusicStreamPlaying(_: Music) bool {
        return false;
    }
} else lm.deps.rl;

const Self = @This();

pub const Phase = enum {
    stopped,
    replenish,
    combat,
};

pub const ambient_track = "audio/audio__ambient.mp3";
pub const fight_tracks = [_][]const u8{
    "audio/audio__fight_0.mp3",
    "audio/audio__fight_1.mp3",
    "audio/audio__fight_2.mp3",
    "audio/audio__fight_3.mp3",
};

pub var current_phase: Phase = .stopped;
pub var current_track_path: ?[]const u8 = null;
pub var outgoing_track_path: ?[]const u8 = null;

var current_music: ?rl.Music = null;
var outgoing_music: ?rl.Music = null;

pub var current_vol: f32 = 0.0;
pub var outgoing_vol: f32 = 0.0;
pub var fade_duration: f32 = 1.5;

var fight_track_index: usize = 0;

pub fn Awake(self: *Self) void {
    _ = self;
    setPhase(.replenish);
}

pub fn Update(self: *Self) void {
    _ = self;
    const dt = lm.time.deltaTime();

    if (outgoing_music) |out| {
        outgoing_vol = @max(0.0, outgoing_vol - (dt / fade_duration));
        if (outgoing_vol <= 0.001) {
            rl.stopMusicStream(out);
            rl.unloadMusicStream(out);
            outgoing_music = null;
            outgoing_track_path = null;
            outgoing_vol = 0.0;
        } else {
            rl.setMusicVolume(out, AudioManager.effectiveMusic(outgoing_vol));
            rl.updateMusicStream(out);
        }
    }

    if (current_music) |curr| {
        current_vol = @min(1.0, current_vol + (dt / fade_duration));
        rl.setMusicVolume(curr, AudioManager.effectiveMusic(current_vol));
        rl.updateMusicStream(curr);
    }
}

pub fn End(self: *Self) void {
    _ = self;
    stop();
}

pub fn setPhase(phase: Phase) void {
    if (phase == current_phase) return;
    current_phase = phase;

    const next_track: ?[]const u8 = switch (phase) {
        .stopped => null,
        .replenish => ambient_track,
        .combat => blk: {
            const track = fight_tracks[fight_track_index % fight_tracks.len];
            fight_track_index +%= 1;
            break :blk track;
        },
    };

    transitionTo(next_track);
}

fn transitionTo(next_track: ?[]const u8) void {
    if (outgoing_music) |out| {
        rl.stopMusicStream(out);
        rl.unloadMusicStream(out);
        outgoing_music = null;
        outgoing_track_path = null;
    }

    if (current_music) |curr| {
        outgoing_music = curr;
        outgoing_track_path = current_track_path;
        outgoing_vol = current_vol;
    }

    current_music = null;
    current_track_path = next_track;
    current_vol = 0.0;

    if (next_track) |track_path| {
        const full_path = lm.assets.files.getFilePath(track_path) catch return;
        defer lm.allocators.generic().free(full_path);

        const path_z = lm.allocators.generic().dupeZ(u8, full_path) catch return;
        defer lm.allocators.generic().free(path_z);

        var music = rl.loadMusicStream(path_z) catch return;
        music.looping = true;
        rl.setMusicVolume(music, AudioManager.effectiveMusic(0.001));
        rl.playMusicStream(music);
        current_music = music;
    }
}

pub fn stop() void {
    if (outgoing_music) |out| {
        rl.stopMusicStream(out);
        rl.unloadMusicStream(out);
        outgoing_music = null;
        outgoing_track_path = null;
        outgoing_vol = 0.0;
    }

    if (current_music) |curr| {
        rl.stopMusicStream(curr);
        rl.unloadMusicStream(curr);
        current_music = null;
        current_track_path = null;
        current_vol = 0.0;
    }

    current_phase = .stopped;
}

test "MusicManager phase selection and transition logic" {
    current_phase = .stopped;
    current_track_path = null;
    outgoing_track_path = null;
    current_vol = 0.0;
    outgoing_vol = 0.0;

    // Transition to replenish
    setPhase(.replenish);
    try std.testing.expectEqual(Phase.replenish, current_phase);
    try std.testing.expect(current_track_path != null);
    try std.testing.expectEqualStrings(ambient_track, current_track_path.?);

    // Transition to combat
    setPhase(.combat);
    try std.testing.expectEqual(Phase.combat, current_phase);
    try std.testing.expect(outgoing_track_path != null);
    try std.testing.expectEqualStrings(ambient_track, outgoing_track_path.?);
    try std.testing.expect(current_track_path != null);
    try std.testing.expect(std.mem.startsWith(u8, current_track_path.?, "audio/audio__fight_"));

    // Reset
    current_phase = .stopped;
    current_track_path = null;
    outgoing_track_path = null;
}
