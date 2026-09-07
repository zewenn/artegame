const std = @import("std");
const lm = @import("loom");

const prefabs = @import("../prefabs/prefabs.zig");
const player_components = @import("../components/player/export.zig");
const Stats = @import("../components/Stats.zig");
const BoonPool = @import("boons/BoonPool.zig");
const MusicManager = @import("audio/MusicManager.zig");
const RoundSpawner = @import("spawner/RoundSpawner.zig");
const SaveSystem = @import("save/SaveSystem.zig");
const spells = @import("../components/Weapons/spells.zig");

const Self = @This();

pub var resume_saved_run: bool = false;

pub const RoundState = enum {
    replenish,
    combat,
};

pub const RunStats = struct {
    rounds_survived: u32 = 0,
    current_round: u32 = 0,
    enemies_defeated: u32 = 0,
    experience_collected: usize = 0,
};

state: RoundState = .replenish,
player: ?*lm.Entity = null,
player_objectives: ?*player_components.Objectives = null,
round: u32 = 0,
rounds_survived: u32 = 0,
enemies_defeated: u32 = 0,
spawner: RoundSpawner = undefined,

pub fn get() ?*Self {
    const scene = lm.activeScene() orelse return null;
    return scene.getGlobalBehaviour(Self);
}

pub fn Awake(self: *Self) !void {
    if (resume_saved_run and SaveSystem.hasActiveRun()) {
        if (SaveSystem.getSavedRun()) |saved| {
            self.round = saved.round;
            self.rounds_survived = saved.rounds_survived;
            self.enemies_defeated = saved.enemies_defeated;
            self.state = .replenish;
        }
    } else {
        self.state = .replenish;
        self.round = 0;
        self.rounds_survived = 0;
        self.enemies_defeated = 0;
    }
    MusicManager.setGlobalPhase(.replenish);
    BoonPool.reset();
    self.spawner = RoundSpawner.init(lm.allocators.scene());
    self.spawner.spawn_area = .{
        .min_x = -1100.0,
        .max_x = 1100.0,
        .min_y = -520.0,
        .max_y = 520.0,
        .min_player_dist = 420.0,
        .exclusion_zones = &.{
            .{ .min = .init(-160, -280), .max = .init(160, -120) },
        },
    };

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
            _ = try objectives.setSingleObjective("Replenish", " - Visit Boon Shrine to upgrade \n - Activate Round Shrine to fight");
        }

        load_saved_run: {
            if (!resume_saved_run or !SaveSystem.hasActiveRun()) break :load_saved_run;
            resume_saved_run = false;

            const saved = SaveSystem.getSavedRun() orelse break :load_saved_run;
            if (player.getComponent(Stats)) |stats| saved.player_stats.applyToStats(stats);

            const attack = player.getComponent(player_components.Attack) orelse break :load_saved_run;
            attack.equipped_weapons = saved.equipped_weapons;
            attack.current_weapon_number = saved.current_weapon_number;

            for (0..2, saved.equipped_spells) |i, maybe_spell| {
                const spell = maybe_spell orelse {
                    attack.equipped_spells[i] = null;
                    continue;
                };
                const base_spell = spells.getById(spell.id) orelse {
                    attack.equipped_spells[i] = null;
                    continue;
                };

                var s = base_spell;
                s.level = spell.level;
                attack.equipped_spells[i] = s;
            }
        }
    }

    const player_pos: lm.Vector2 = player_pos: {
        const player = self.player orelse break :player_pos lm.Vec2(0, 0);
        const transform = player.getComponent(lm.Transform) orelse break :player_pos lm.Vec2(0, 0);
        break :player_pos lm.vec3ToVec2(transform.position);
    };

    if (lm.time.paused()) return;

    const dt = lm.time.deltaTime();
    try self.spawner.update(dt, scene, player_pos);

    if (self.state == .combat and self.spawner.isWaveFinished()) {
        self.state = .replenish;
        self.rounds_survived += 1;
        self.spawner.finishWave();
        MusicManager.setGlobalPhase(.replenish);
        if (self.player_objectives) |objectives| {
            _ = try objectives.setSingleObjective("Replenish", "Visit Boon Shrine to upgrade | Activate Round Shrine to fight");
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
    MusicManager.stopGlobal();
    self.spawner.deinit();
    BoonPool.reset();
}

pub fn isReplenish() bool {
    const self = get() orelse return false;
    return self.state == .replenish;
}

pub fn getState() ?RoundState {
    const self = get() orelse return null;
    return self.state;
}

pub fn startRound() !void {
    const self = get() orelse return;
    if (self.state != .replenish) return;

    self.state = .combat;
    self.round += 1;
    MusicManager.setGlobalPhase(.combat);

    if (self.player_objectives) |objectives| {
        _ = try objectives.setSingleObjective("FIGHT TILL DEATH", "Kill all enemies");
    }

    // Auto-save when round starts
    saveCurrentRun();

    try self.spawner.startWave(self.round);
}

pub fn saveCurrentRun() void {
    const self = get() orelse return;
    const player = self.player orelse return;
    const stats = player.getComponent(Stats) orelse return;
    const attack = player.getComponent(player_components.Attack) orelse return;
    SaveSystem.saveRun(self.round, self.rounds_survived, self.enemies_defeated, stats.*, attack.*);
}

pub fn getWaveProgress() ?RoundSpawner.WaveProgress {
    const self = get() orelse return null;
    return self.spawner.getProgress();
}

pub fn removeDefeatedEnemy(uuid: u128) void {
    const self = get() orelse return;
    self.enemies_defeated += 1;
    self.spawner.removeDefeatedEnemy(uuid);
}

pub fn getRunStats() RunStats {
    const self = get() orelse return .{};
    const xp = if (self.player) |p|
        if (p.getComponent(Stats)) |s| s.current.experience else 0
    else
        0;
    return .{
        .rounds_survived = self.rounds_survived,
        .current_round = self.round,
        .enemies_defeated = self.enemies_defeated,
        .experience_collected = xp,
    };
}

// --------------------------------------------------------------------------------------------------
// Unit Tests
// --------------------------------------------------------------------------------------------------

test "DemoMap RunStats defaults" {
    const stats = RunStats{};
    try std.testing.expectEqual(@as(u32, 0), stats.rounds_survived);
    try std.testing.expectEqual(@as(u32, 0), stats.current_round);
    try std.testing.expectEqual(@as(u32, 0), stats.enemies_defeated);
    try std.testing.expectEqual(@as(usize, 0), stats.experience_collected);
}
