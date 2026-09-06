const std = @import("std");
const lm = @import("loom");

const prefabs = @import("../prefabs/prefabs.zig");
const player_components = @import("../components/player/export.zig");
const Stats = @import("../components/Stats.zig");
const BoonPool = @import("boons/BoonPool.zig");
const MusicManager = @import("audio/MusicManager.zig");
const RoundSpawner = @import("spawner/RoundSpawner.zig");

const Self = @This();

pub const RoundState = enum {
    replenish,
    combat,
};

pub var state: RoundState = .replenish;
var instance: ?*Self = null;

player: ?*lm.Entity = null,
player_objectives: ?*player_components.Objectives = null,
round: u32 = 0,
spawner: RoundSpawner = undefined,

pub fn Awake(self: *Self) !void {
    instance = self;
    state = .replenish;
    MusicManager.setPhase(.replenish);
    BoonPool.reset();
    self.spawner = RoundSpawner.init(lm.allocators.scene());

    try lm.summoning.entities(&.{
        try prefabs.Player(.init(0, 0)),
        try prefabs.Background(20, 10),
        try prefabs.Shrine(.init(-96, -200)),
        try prefabs.RoundActivator(.init(96, -200)),
    });
}

pub fn Update(self: *Self, scene: *lm.Scene) !void {
    if (self.player == null or self.player_objectives == null) {
        const player = scene.getEntityById("player") orelse {
            self.player = null;
            self.player_objectives = null;
            return;
        };

        self.player = player;
        self.player_objectives = player.getComponent(player_components.Objectives);
        if (self.player_objectives) |objectives| {
            objectives.tracking = try objectives.addObjective(.init("Replenish", "Visit Boon Shrine to upgrade | Activate Round Shrine to fight"));
        }
    }

    const player_pos: lm.Vector2 = player_pos: {
        const player = self.player orelse break :player_pos lm.Vec2(0, 0);
        const transform = player.getComponent(lm.Transform) orelse break :player_pos lm.Vec2(0, 0);
        break :player_pos lm.vec3ToVec2(transform.position);
    };

    const dt = lm.time.deltaTime();
    try self.spawner.update(dt, scene, player_pos);

    if (state == .combat and self.spawner.isWaveFinished()) {
        state = .replenish;
        self.spawner.finishWave();
        MusicManager.setPhase(.replenish);
        if (self.player_objectives) |objectives| {
            objectives.tracking = try objectives.addObjective(.init("Replenish", "Visit Boon Shrine to upgrade | Activate Round Shrine to fight"));
        }
        if (self.player) |player| {
            if (player.getComponent(Stats)) |stats| {
                if (player.getComponent(player_components.Attack)) |attack| {
                    BoonPool.reroll(stats.*, attack.*);
                }
            }
        }
    }
}

pub fn End(self: *Self) !void {
    instance = null;
    MusicManager.stop();
    self.spawner.deinit();
    BoonPool.reset();
}

pub fn isReplenish() bool {
    return state == .replenish;
}

pub fn startRound() !void {
    const self = instance orelse return;
    if (state != .replenish) return;

    state = .combat;
    self.round += 1;
    MusicManager.setPhase(.combat);

    if (self.player_objectives) |objectives| {
        objectives.tracking = try objectives.addObjective(.init("FIGHT TILL DEATH", "Kill all enemies"));
    }

    try self.spawner.startWave(self.round);
}

pub fn getWaveProgress() ?RoundSpawner.WaveProgress {
    const self = instance orelse return null;
    return self.spawner.getProgress();
}
