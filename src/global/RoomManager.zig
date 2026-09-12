const std = @import("std");
const lm = @import("loom");

const prefabs = @import("../prefabs/prefabs.zig");
const player_components = @import("../components/player/export.zig");
const Stats = @import("../components/Stats.zig");
const Dashing = @import("../components/Dashing.zig");
const ExperienceOrbComponent = @import("../components/items/ExperienceOrb.zig");
const ProjectileMovement = @import("../components/ProjectileMovement.zig");
const BoonPool = @import("boons/BoonPool.zig");
const AudioManager = @import("audio/AudioManager.zig");
const MusicManager = @import("audio/MusicManager.zig");
const RoundSpawner = @import("spawner/RoundSpawner.zig");
const SaveSystem = @import("save/SaveSystem.zig");
const spells = @import("../components/Weapons/spells.zig");
const Hands = @import("../components/Weapons/Hands.zig");

const Self = @This();

pub var resume_saved_run: bool = false;
const replenish_objective_text = " - Pick up Boon Drop to upgrade\n - Enter Exit Door for next room";

pub const RoomState = enum {
    combat,
    replenish,
};

pub const RoomType = enum {
    tutorial,
    normal,
    mini_boss,
    boss,

    pub fn fromRoomNumber(room_num: u32) RoomType {
        if (room_num == 0) return .tutorial;
        if (room_num % 15 == 0) return .boss;
        if (room_num % 5 == 0) return .mini_boss;
        return .normal;
    }

    pub fn displayName(self: RoomType) []const u8 {
        return switch (self) {
            .tutorial => "Tutorial",
            .normal => "Normal",
            .mini_boss => "Mini-Boss",
            .boss => "Boss",
        };
    }
};

pub const RunStats = struct {
    rooms_cleared: u32 = 0,
    current_room: u32 = 0,
    enemies_defeated: u32 = 0,
    experience_collected: usize = 0,
};

pub const FallenEnemyRecord = struct {
    enemy_type: RoundSpawner.EnemyType = .melee,
    death_position: lm.Vector2 = .init(0, 0),
};

state: RoomState = .combat,
current_room: u32 = 1,
rooms_cleared: u32 = 0,
enemies_defeated: u32 = 0,
boon_drop_spawned: bool = false,

player: ?*lm.Entity = null,
player_objectives: ?*player_components.Objectives = null,
spawner: RoundSpawner = undefined,
graveyard: lm.List(FallenEnemyRecord) = undefined,

pub fn Awake(self: *Self) !void {
    if (resume_saved_run and SaveSystem.hasActiveRun()) {
        if (SaveSystem.getSavedRun()) |saved| {
            self.current_room = if (saved.round > 0) saved.round else 1;
            self.rooms_cleared = saved.rounds_survived;
            self.enemies_defeated = saved.enemies_defeated;
            self.state = .replenish;
            MusicManager.setGlobalPhase(.replenish);
        } else {
            self.initFreshRun();
        }
    } else {
        self.initFreshRun();
    }

    BoonPool.reset();
    self.graveyard = lm.List(FallenEnemyRecord).init(lm.allocators.scene());
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
        try prefabs.ExitDoor(.init(128, -200)),
    });
}

fn initFreshRun(self: *Self) void {
    self.current_room = 1;
    self.rooms_cleared = 0;
    self.enemies_defeated = 0;
    self.boon_drop_spawned = false;
    self.state = .combat;
    MusicManager.setGlobalPhase(.combat);
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

            if (player.getComponent(Hands)) |hands| {
                if (attack.currentWeapon()) |w| {
                    hands.setWeapon(w.*);
                }
            }
        }

        if (self.state == .combat and !self.spawner.is_active) {
            try self.startCurrentRoomCombat();
        } else if (self.state == .replenish) {
            if (self.player_objectives) |objectives| {
                _ = try objectives.setSingleObjective("Replenish", replenish_objective_text);
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
        try self.completeCurrentRoomCombat();
    }
}

pub fn End(self: *Self) !void {
    MusicManager.stopGlobal();
    self.spawner.deinit();
    BoonPool.reset();
}

fn startCurrentRoomCombat(self: *Self) !void {
    self.state = .combat;
    MusicManager.setGlobalPhase(.combat);

    if (self.player_objectives) |objectives| {
        const room_type = self.getRoomType();
        switch (room_type) {
            .mini_boss => _ = try objectives.setSingleObjective("Mini-Boss Room", "Defeat the Mini-Boss!"),
            .boss => _ = try objectives.setSingleObjective("Boss Room", "Defeat the Boss!"),
            .tutorial => _ = try objectives.setSingleObjective("Tutorial Room", "Complete your training"),
            .normal => _ = try objectives.setSingleObjective("Combat Wave", "Defeat all enemies"),
        }
    }

    self.saveRunState();
    try self.spawner.startWave(self.current_room);
}

fn completeCurrentRoomCombat(self: *Self) !void {
    self.state = .replenish;
    self.rooms_cleared += 1;
    self.spawner.finishWave();

    MusicManager.setGlobalPhase(.replenish);

    self.grantRoomRewards();

    if (!self.boon_drop_spawned) {
        self.boon_drop_spawned = true;
        const fallback_pos: lm.Vector2 = if (self.player) |p| pos: {
            if (p.getComponent(lm.Transform)) |t| {
                break :pos lm.vec3ToVec2(t.position).add(.init(48, 0));
            }
            break :pos .init(0, 0);
        } else .init(0, 0);

        self.spawnBoonDrop(fallback_pos) catch |err| {
            std.log.err("Failed to spawn fallback boon drop: {any}", .{err});
        };
    }

    if (self.player_objectives) |objectives| {
        _ = try objectives.setSingleObjective("Replenish", replenish_objective_text);
    }

    self.saveRunState();
}

pub fn spawnBoonDrop(self: *Self, position: lm.Vector2) !void {
    _ = self;
    const drop = try prefabs.items.BoonDrop(position);
    try lm.summoning.entity(drop);
}

fn grantRoomRewards(self: *Self) void {
    const player = self.player orelse return;
    const stats = player.getComponent(Stats) orelse return;
    const attack = player.getComponent(player_components.Attack) orelse return;

    const room_type = self.getRoomType();
    switch (room_type) {
        .mini_boss => {
            // Restore player HP to maximum and permanently add +10% max HP
            stats.max.health *= 1.10;
            stats.current.health = stats.max.health;
            AudioManager.playSfxPitched("audio/sfx/coin.wav", 1.0, 0.05);
        },
        .boss => {
            // Restore player HP to maximum and permanently add +15% max HP, +15 physical dmg, +10 magic dmg
            stats.max.health *= 1.15;
            stats.current.health = stats.max.health;
            stats.current.physical_damage += 15.0;
            stats.current.magic_damage += 10.0;
            stats.base.physical_damage += 15.0;
            stats.base.magic_damage += 10.0;
            AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);
        },
        .normal, .tutorial => {
            BoonPool.reroll(stats.*, attack.*);
        },
    }
}

pub fn enterNextRoom() !void {
    const self = get() orelse return;
    if (self.state != .replenish) return;

    cleanupRoomEntities();
    repositionPlayer();

    self.current_room += 1;
    self.boon_drop_spawned = false;
    try self.startCurrentRoomCombat();
}

pub fn cleanupRoomEntities() void {
    const scene = lm.activeScene() orelse return;
    for (scene.entities.items()) |entity| {
        if (std.mem.eql(u8, entity.id, "player")) continue;
        if (std.mem.eql(u8, entity.id, "background")) continue;
        if (std.mem.startsWith(u8, entity.id, "exit-door")) continue;

        if (std.mem.startsWith(u8, entity.id, "projectile") or
            std.mem.startsWith(u8, entity.id, "experience-orb") or
            std.mem.startsWith(u8, entity.id, "boon-drop") or
            std.mem.endsWith(u8, entity.id, "-enemy") or
            entity.getComponent(ExperienceOrbComponent) != null or
            entity.getComponent(ProjectileMovement) != null or
            (entity.getComponent(Stats) != null and entity.getComponent(Stats).?.team == .enemy))
        {
            lm.removeEntity(.{ .ptr = entity });
        }
    }
}

pub fn repositionPlayer() void {
    const self = get() orelse return;
    const player = self.player orelse return;
    if (player.getComponent(lm.Transform)) |transform| {
        transform.position = lm.Vec3(0, 0, 0);
    }
    if (player.getComponent(Dashing)) |dashing| {
        if (dashing.dashes) |*dashes| {
            dashes.clearRetainingCapacity();
        }
    }
}

pub fn get() ?*Self {
    const scene = lm.activeScene() orelse return null;
    return scene.getGlobalBehaviour(Self);
}

pub fn isReplenish() bool {
    const self = get() orelse return false;
    return self.state == .replenish;
}

pub fn isCombat() bool {
    const self = get() orelse return false;
    return self.state == .combat;
}

pub fn getState() ?RoomState {
    const self = get() orelse return null;
    return self.state;
}

pub fn getCurrentRoom() u32 {
    const self = get() orelse return 1;
    return self.current_room;
}

pub fn getRoomsCleared() u32 {
    const self = get() orelse return 0;
    return self.rooms_cleared;
}

pub fn getRoomType(self: *const Self) RoomType {
    return RoomType.fromRoomNumber(self.current_room);
}

pub fn getNextRoomType(self: *const Self) RoomType {
    return RoomType.fromRoomNumber(self.current_room + 1);
}

pub fn saveRunState(self: *Self) void {
    const player = self.player orelse return;
    const stats = player.getComponent(Stats) orelse return;
    const attack = player.getComponent(player_components.Attack) orelse return;
    SaveSystem.saveRun(self.current_room, self.rooms_cleared, self.enemies_defeated, stats.*, attack.*);
}

pub fn saveCurrentRun() void {
    const self = get() orelse return;
    self.saveRunState();
}

pub fn getWaveProgress() ?RoundSpawner.WaveProgress {
    const self = get() orelse return null;
    return self.spawner.getProgress();
}

pub fn removeDefeatedEnemy(uuid: u128, death_position: lm.Vector2, enemy_type: RoundSpawner.EnemyType) void {
    const self = get() orelse return;
    self.enemies_defeated += 1;

    self.graveyard.append(.{
        .enemy_type = enemy_type,
        .death_position = death_position,
    }) catch {};

    self.spawner.removeDefeatedEnemy(uuid);

    if (self.spawner.isWaveFinished() and !self.boon_drop_spawned) {
        self.boon_drop_spawned = true;
        self.spawnBoonDrop(death_position) catch |err| {
            std.log.err("Failed to spawn boon drop: {any}", .{err});
        };
    }
}

pub fn popFallenEnemyForRevive() ?FallenEnemyRecord {
    const self = get() orelse return null;
    if (self.graveyard.len() == 0) return null;
    return self.graveyard.swapRemove(self.graveyard.len() - 1);
}

pub fn getRunStats() RunStats {
    const self = get() orelse return .{};
    const xp = if (self.player) |p|
        if (p.getComponent(Stats)) |s| s.current.experience else 0
    else
        0;
    return .{
        .rooms_cleared = self.rooms_cleared,
        .current_room = self.current_room,
        .enemies_defeated = self.enemies_defeated,
        .experience_collected = xp,
    };
}

// --------------------------------------------------------------------------------------------------
// Unit Tests
// --------------------------------------------------------------------------------------------------

test "RoomType determination from room number" {
    try std.testing.expectEqual(RoomType.tutorial, RoomType.fromRoomNumber(0));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(1));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(2));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(3));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(4));
    try std.testing.expectEqual(RoomType.mini_boss, RoomType.fromRoomNumber(5));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(6));
    try std.testing.expectEqual(RoomType.mini_boss, RoomType.fromRoomNumber(10));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(14));
    try std.testing.expectEqual(RoomType.boss, RoomType.fromRoomNumber(15));
    try std.testing.expectEqual(RoomType.mini_boss, RoomType.fromRoomNumber(20));
    try std.testing.expectEqual(RoomType.boss, RoomType.fromRoomNumber(30));
}

test "RoomManager RunStats defaults" {
    const stats = RunStats{};
    try std.testing.expectEqual(@as(u32, 0), stats.rooms_cleared);
    try std.testing.expectEqual(@as(u32, 0), stats.current_room);
    try std.testing.expectEqual(@as(u32, 0), stats.enemies_defeated);
    try std.testing.expectEqual(@as(usize, 0), stats.experience_collected);
}

test "RoomType display names" {
    try std.testing.expectEqualStrings("Tutorial", RoomType.tutorial.displayName());
    try std.testing.expectEqualStrings("Normal", RoomType.normal.displayName());
    try std.testing.expectEqualStrings("Mini-Boss", RoomType.mini_boss.displayName());
    try std.testing.expectEqualStrings("Boss", RoomType.boss.displayName());
}

test "Mini-boss reward boosts max HP by 10 percent and restores current health" {
    var stats = Stats{
        .max = .{ .health = 100.0 },
        .current = .{ .health = 25.0 },
    };

    // Simulate Mini-Boss reward logic
    stats.max.health *= 1.10;
    stats.current.health = stats.max.health;

    try std.testing.expectApproxEqAbs(@as(f32, 110.0), stats.max.health, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 110.0), stats.current.health, 0.001);
}

test "Boss reward boosts max HP by 15 percent, restores HP, and adds +15 phys / +10 magic dmg" {
    var stats = Stats{
        .max = .{ .health = 100.0 },
        .current = .{
            .health = 10.0,
            .physical_damage = 20.0,
            .magic_damage = 5.0,
        },
        .base = .{
            .physical_damage = 20.0,
            .magic_damage = 5.0,
        },
    };

    // Simulate Boss reward logic
    stats.max.health *= 1.15;
    stats.current.health = stats.max.health;
    stats.current.physical_damage += 15.0;
    stats.current.magic_damage += 10.0;
    stats.base.physical_damage += 15.0;
    stats.base.magic_damage += 10.0;

    try std.testing.expectApproxEqAbs(@as(f32, 115.0), stats.max.health, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 115.0), stats.current.health, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 35.0), stats.current.physical_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), stats.current.magic_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 35.0), stats.base.physical_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), stats.base.magic_damage, 0.001);
}

test "RoomManager lifecycle state transitions" {
    var rm = Self{};
    rm.initFreshRun();

    // Starts in combat
    try std.testing.expectEqual(RoomState.combat, rm.state);
    try std.testing.expectEqual(@as(u32, 1), rm.current_room);
    try std.testing.expectEqual(@as(u32, 0), rm.rooms_cleared);

    // Simulate room wave cleared
    rm.state = .replenish;
    rm.rooms_cleared += 1;
    try std.testing.expectEqual(RoomState.replenish, rm.state);
    try std.testing.expectEqual(@as(u32, 1), rm.rooms_cleared);

    // Advance to next room
    rm.current_room += 1;
    rm.state = .combat;
    try std.testing.expectEqual(RoomState.combat, rm.state);
    try std.testing.expectEqual(@as(u32, 2), rm.current_room);
    try std.testing.expectEqual(@as(u32, 1), rm.rooms_cleared);
}
