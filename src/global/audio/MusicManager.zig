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

current_phase: Phase = .stopped,
current_track_path: ?[]const u8 = null,
outgoing_track_path: ?[]const u8 = null,

current_music: ?rl.Music = null,
outgoing_music: ?rl.Music = null,

current_vol: f32 = 0.0,
outgoing_vol: f32 = 0.0,
fade_duration: f32 = 1.5,

fight_track_index: usize = 0,

pub fn get() ?*Self {
    const scene = lm.activeScene() orelse return null;
    return scene.getGlobalBehaviour(Self);
}

pub fn setGlobalPhase(phase: Phase) void {
    if (get()) |mgr| mgr.setPhase(phase);
}

pub fn stopGlobal() void {
    if (get()) |mgr| mgr.stop();
}

pub fn Awake(self: *Self) void {
    self.setPhase(.replenish);
}

pub fn Update(self: *Self) void {
    const dt = lm.time.deltaTime();

    if (self.outgoing_music) |out| {
        self.outgoing_vol = @max(0.0, self.outgoing_vol - (dt / self.fade_duration));
        if (self.outgoing_vol <= 0.001) {
            rl.stopMusicStream(out);
            rl.unloadMusicStream(out);
            self.outgoing_music = null;
            self.outgoing_track_path = null;
            self.outgoing_vol = 0.0;
        } else {
            rl.setMusicVolume(out, AudioManager.effectiveMusic(self.outgoing_vol));
            rl.updateMusicStream(out);
        }
    }

    if (self.current_music) |curr| {
        self.current_vol = @min(1.0, self.current_vol + (dt / self.fade_duration));
        rl.setMusicVolume(curr, AudioManager.effectiveMusic(self.current_vol));
        rl.updateMusicStream(curr);
    }
}

pub fn End(self: *Self) void {
    self.stop();
}

pub fn setPhase(self: *Self, phase: Phase) void {
    if (phase == self.current_phase) return;
    self.current_phase = phase;

    const next_track: ?[]const u8 = switch (phase) {
        .stopped => null,
        .replenish => ambient_track,
        .combat => blk: {
            const track = fight_tracks[self.fight_track_index % fight_tracks.len];
            self.fight_track_index +%= 1;
            break :blk track;
        },
    };

    self.transitionTo(next_track);
}

fn transitionTo(self: *Self, next_track: ?[]const u8) void {
    if (self.outgoing_music) |out| {
        rl.stopMusicStream(out);
        rl.unloadMusicStream(out);
        self.outgoing_music = null;
        self.outgoing_track_path = null;
    }

    if (self.current_music) |curr| {
        self.outgoing_music = curr;
        self.outgoing_track_path = self.current_track_path;
        self.outgoing_vol = self.current_vol;
    }

    self.current_music = null;
    self.current_track_path = next_track;
    self.current_vol = 0.0;

    if (next_track) |track_path| {
        const full_path = lm.assets.files.getFilePath(track_path) catch return;
        defer lm.allocators.generic().free(full_path);

        const path_z = lm.allocators.generic().dupeZ(u8, full_path) catch return;
        defer lm.allocators.generic().free(path_z);

        var music = rl.loadMusicStream(path_z) catch return;
        music.looping = true;
        rl.setMusicVolume(music, AudioManager.effectiveMusic(0.001));
        rl.playMusicStream(music);
        self.current_music = music;
    }
}

pub fn stop(self: *Self) void {
    if (self.outgoing_music) |out| {
        rl.stopMusicStream(out);
        rl.unloadMusicStream(out);
        self.outgoing_music = null;
        self.outgoing_track_path = null;
        self.outgoing_vol = 0.0;
    }

    if (self.current_music) |curr| {
        rl.stopMusicStream(curr);
        rl.unloadMusicStream(curr);
        self.current_music = null;
        self.current_track_path = null;
        self.current_vol = 0.0;
    }

    self.current_phase = .stopped;
}

test "MusicManager phase selection and transition logic" {
    var mgr = Self{};
    try std.testing.expectEqual(Phase.stopped, mgr.current_phase);

    mgr.setPhase(.replenish);
    try std.testing.expectEqual(Phase.replenish, mgr.current_phase);
    try std.testing.expect(mgr.current_track_path != null);
    try std.testing.expectEqualStrings(ambient_track, mgr.current_track_path.?);

    mgr.setPhase(.combat);
    try std.testing.expectEqual(Phase.combat, mgr.current_phase);
    try std.testing.expect(mgr.outgoing_track_path != null);
    try std.testing.expectEqualStrings(ambient_track, mgr.outgoing_track_path.?);
    try std.testing.expect(mgr.current_track_path != null);
    try std.testing.expect(std.mem.startsWith(u8, mgr.current_track_path.?, "audio/audio__fight_"));

    mgr.End();
    try std.testing.expectEqual(Phase.stopped, mgr.current_phase);
    try std.testing.expect(mgr.current_music == null);
    try std.testing.expect(mgr.outgoing_music == null);
    try std.testing.expect(mgr.current_track_path == null);
    try std.testing.expect(mgr.outgoing_track_path == null);
}

