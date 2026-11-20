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
} else lm.deps.rl;

const Self = @This();

pub const Phase = enum {
    stopped,
    replenish,
    combat,
};

const MusicChannel = struct {
    stream: ?rl.Music = null,
    volume: f32 = 0.0,

    pub fn stopAndUnload(self: *MusicChannel) void {
        if (self.stream) |stream| {
            rl.stopMusicStream(stream);
            rl.unloadMusicStream(stream);
        }
        self.stream = null;
        self.volume = 0.0;
    }
};

pub const ambient_track = "audio/music/ambient.mp3";
pub const fight_tracks = [_][]const u8{
    "audio/music/fight_0.mp3",
    "audio/music/fight_1.mp3",
    "audio/music/fight_2.mp3",
    "audio/music/fight_3.mp3",
};

current_phase: Phase = .stopped,
current: MusicChannel = .{},
outgoing: MusicChannel = .{},
fade_duration_seconds: f32 = 1.5,
fight_track_index: usize = 0,

pub fn Awake(self: *Self) void {
    self.setPhase(.replenish);
}

pub fn Update(self: *Self) void {
    const delta_seconds = lm.time.deltaTime();
    self.updateOutgoingChannel(delta_seconds);
    self.updateCurrentChannel(delta_seconds);
}

pub fn End(self: *Self) void {
    self.stop();
}

fn updateOutgoingChannel(self: *Self, delta_seconds: f32) void {
    const outgoing_stream = self.outgoing.stream orelse return;
    self.outgoing.volume = @max(0.0, self.outgoing.volume - (delta_seconds / self.fade_duration_seconds));

    if (self.outgoing.volume <= 0.001) {
        self.outgoing.stopAndUnload();
        return;
    }

    rl.setMusicVolume(outgoing_stream, AudioManager.effectiveMusic(self.outgoing.volume));
    rl.updateMusicStream(outgoing_stream);
}

fn updateCurrentChannel(self: *Self, delta_seconds: f32) void {
    const current_stream = self.current.stream orelse return;
    self.current.volume = @min(1.0, self.current.volume + (delta_seconds / self.fade_duration_seconds));
    rl.setMusicVolume(current_stream, AudioManager.effectiveMusic(self.current.volume));
    rl.updateMusicStream(current_stream);
}

pub fn get() ?*Self {
    const scene = lm.activeScene() orelse return null;
    return scene.getGlobalBehaviour(Self);
}

pub fn setGlobalPhase(phase: Phase) void {
    if (get()) |music_manager| music_manager.setPhase(phase);
}

pub fn stopGlobal() void {
    if (get()) |music_manager| music_manager.stop();
}

pub fn setPhase(self: *Self, phase: Phase) void {
    if (phase == self.current_phase) return;
    self.current_phase = phase;

    const next_track = self.selectTrackForPhase(phase);
    self.transitionTo(next_track);
}

fn selectTrackForPhase(self: *Self, phase: Phase) ?[]const u8 {
    return switch (phase) {
        .stopped => null,
        .replenish => ambient_track,
        .combat => blk: {
            const track = fight_tracks[self.fight_track_index % fight_tracks.len];
            self.fight_track_index +%= 1;
            break :blk track;
        },
    };
}

fn transitionTo(self: *Self, next_track: ?[]const u8) void {
    self.outgoing.stopAndUnload();

    if (self.current.stream != null) {
        self.outgoing = self.current;
    }

    self.current = .{};

    const track_path = next_track orelse return;
    const full_path = lm.assets.files.getFilePath(track_path) catch return;
    defer lm.allocators.generic().free(full_path);

    const sentinel_path = lm.allocators.generic().dupeSentinel(u8, full_path, 0) catch return;
    defer lm.allocators.generic().free(sentinel_path);

    var music = rl.loadMusicStream(sentinel_path) catch return;
    music.looping = true;
    rl.setMusicVolume(music, AudioManager.effectiveMusic(0.001));
    rl.playMusicStream(music);
    self.current.stream = music;
}

pub fn stop(self: *Self) void {
    self.outgoing.stopAndUnload();
    self.current.stopAndUnload();
    self.current_phase = .stopped;
}

test "MusicManager phase selection and channel cleanup" {
    var music_manager = Self{};
    try std.testing.expectEqual(Phase.stopped, music_manager.current_phase);

    try std.testing.expect(music_manager.selectTrackForPhase(.stopped) == null);
    try std.testing.expectEqualStrings(ambient_track, music_manager.selectTrackForPhase(.replenish).?);
    try std.testing.expectEqualStrings(fight_tracks[0], music_manager.selectTrackForPhase(.combat).?);
    try std.testing.expectEqualStrings(fight_tracks[1], music_manager.selectTrackForPhase(.combat).?);

    music_manager.fight_track_index = 0;
    music_manager.setPhase(.replenish);
    try std.testing.expectEqual(Phase.replenish, music_manager.current_phase);

    music_manager.current = .{ .stream = .{}, .volume = 0.75 };
    music_manager.setPhase(.combat);
    try std.testing.expectEqual(Phase.combat, music_manager.current_phase);
    try std.testing.expectEqual(@as(usize, 1), music_manager.fight_track_index);
    try std.testing.expect(music_manager.outgoing.stream != null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), music_manager.outgoing.volume, 0.001);

    music_manager.End();
    try std.testing.expectEqual(Phase.stopped, music_manager.current_phase);
    try std.testing.expect(music_manager.current.stream == null);
    try std.testing.expect(music_manager.outgoing.stream == null);
    try std.testing.expectEqual(@as(f32, 0.0), music_manager.current.volume);
    try std.testing.expectEqual(@as(f32, 0.0), music_manager.outgoing.volume);
}
