const std = @import("std");
const lm = @import("loom");

const prefabs = @import("../prefabs/prefabs.zig");
const player_components = @import("../components/player/export.zig");
const Stats = @import("../components/Stats.zig");
const Dashing = @import("../components/Dashing.zig");
const ExperienceOrbComponent = @import("../components/items/ExperienceOrb.zig");
const ProjectileManager = @import("ProjectileManager.zig");
const BoonPool = @import("boons/BoonPool.zig");
const AudioManager = @import("audio/AudioManager.zig");
const MusicManager = @import("audio/MusicManager.zig");
const RoundSpawner = @import("spawner/RoundSpawner.zig");
const SaveSystem = @import("save/SaveSystem.zig");
const spells = @import("../components/weapons/spells.zig");
const Spell = @import("../components/weapons/Spell.zig");
const Hands = @import("../components/weapons/Hands.zig");
const MapLoader = @import("map/MapLoader.zig");
const DoorSpawner = @import("spawner/DoorSpawner.zig");
const MapRegistry = @import("map/MapRegistry.zig");
const TutorialManager = @import("tutorial/TutorialManager.zig");
const MapTypes = @import("map/MapTypes.zig");

const Self = @This();

pub const RoomState = enum {
    combat,
    replenish,
};

pub const RoomType = @import("RoomType.zig").RoomType;

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

const replenish_objective_text = " - Pick up Boon Drop to upgrade\n - Enter Exit Door for next room";
const playtest_replenish_objective_text = " - Enter Exit Door to return to Map Editor";

pub var resume_saved_run: bool = false;
pub var is_playtest_mode: bool = false;
pub var playtest_map_path_buffer: [256]u8 = undefined;
pub var playtest_map_path: []const u8 = "";
pub var playtest_room_type: RoomType = .normal;
pub var is_practice_tutorial_mode: bool = false;

state: RoomState = .combat,
current_room: u32 = 1,
rooms_cleared: u32 = 0,
room_category: []const u8 = "normal",
current_map_path: []const u8 = "maps/normal/arena_normal.json",
enemies_defeated: u32 = 0,
boon_drop_spawned: bool = false,

player: ?*lm.Entity = null,
player_objectives: ?*player_components.Objectives = null,
spawner: RoundSpawner = undefined,
graveyard: lm.List(FallenEnemyRecord) = undefined,

pub fn Awake(self: *Self) !void {
    self.configureInitialRunMode();

    BoonPool.reset();
    self.graveyard = lm.List(FallenEnemyRecord).init(lm.allocators.scene());
    self.spawner = RoundSpawner.init(lm.allocators.scene());

    MapLoader.loadAndInstantiate(self.current_map_path) catch |load_error| {
        std.log.warn("Failed to load map {s}, using defaults: {any}", .{ self.current_map_path, load_error });
    };
    const map_bounds = MapLoader.getMapBounds();
    self.spawner.setMapBounds(map_bounds.min, map_bounds.max);
    const spawn_zones = MapLoader.getSpawnZones();
    self.spawner.setSpawnZones(spawn_zones);
    if (is_playtest_mode and playtest_room_type == .normal) {
        self.current_room = determinePlaytestNormalRoom(spawn_zones);
    }

    const player_spawn = MapLoader.getPlayerSpawnPosition();
    try lm.summoning.entities(&.{
        try prefabs.Player(player_spawn),
    });

    if (self.state == .replenish) {
        self.spawnDoorsForCurrentRoom(true);
    }
}

pub fn Update(self: *Self, scene: *lm.Scene) !void {
    if (self.player == null or self.player_objectives == null) {
        try self.initializeActivePlayer(scene);
    }

    if (lm.time.paused()) return;

    const player_position = self.getPlayerPosition();
    const delta_seconds = lm.time.deltaTime();
    try self.spawner.update(delta_seconds, player_position);

    if (self.state == .combat and self.spawner.isWaveFinished()) {
        try self.completeCurrentRoomCombat();
    }
}

pub fn End(self: *Self) !void {
    MusicManager.stopGlobal();
    DoorSpawner.cleanupDoors();
    self.spawner.deinit();
    self.graveyard.deinit();
    BoonPool.reset();
    MapLoader.unload();
}

pub fn startPlaytest(map_path: []const u8, room_type: RoomType) void {
    is_playtest_mode = true;
    const path_length = @min(map_path.len, playtest_map_path_buffer.len);
    @memcpy(playtest_map_path_buffer[0..path_length], map_path[0..path_length]);
    playtest_map_path = playtest_map_path_buffer[0..path_length];
    playtest_room_type = room_type;
}

pub fn endPlaytest() void {
    is_playtest_mode = false;
    playtest_map_path = "";
    MapLoader.setInMemoryMapOverride(null);
}

pub fn isPlaytestMode() bool {
    return is_playtest_mode;
}

pub fn determinePlaytestNormalRoom(zones: []const MapTypes.SpawnZoneRecord) u32 {
    var highest_unlock_round: u32 = 2;
    for (zones) |zone| {
        const enemy_type = zone.enemy_type orelse continue;
        const rule = enemy_type.normalWaveRule() orelse continue;
        if (rule.unlock_round > highest_unlock_round) {
            highest_unlock_round = rule.unlock_round;
        }
    }
    return highest_unlock_round;
}

pub fn startPracticeTutorial() void {
    is_practice_tutorial_mode = true;
    resume_saved_run = false;
}

pub fn endPracticeTutorial() void {
    is_practice_tutorial_mode = false;
}

pub fn isPracticeTutorialMode() bool {
    return is_practice_tutorial_mode;
}

pub fn initPracticeTutorialRun(self: *Self) void {
    self.initRunState(0, "tutorial", RoomType.tutorial.defaultMapPath());
}

fn configureInitialRunMode(self: *Self) void {
    if (is_playtest_mode) {
        self.initFreshRun();
        self.current_map_path = playtest_map_path;
        self.current_room = playtest_room_type.metadata().playtest_room_number;
        self.room_category = playtest_room_type.directoryCategory();
        return;
    }

    if (is_practice_tutorial_mode) {
        self.initPracticeTutorialRun();
        return;
    }

    if (self.resumeRunIfSaved()) return;

    self.initFreshRun();
    const room_type = self.getRoomType();
    self.current_map_path = MapRegistry.pickRandomMap(
        lm.allocators.arena(),
        room_type,
        "",
    ) catch MapRegistry.getDefaultMapPath(room_type);
}

fn initRunState(self: *Self, room_number: u32, room_category: []const u8, map_path: []const u8) void {
    self.current_room = room_number;
    self.rooms_cleared = 0;
    self.room_category = room_category;
    self.current_map_path = map_path;
    self.enemies_defeated = 0;
    self.boon_drop_spawned = false;
    self.state = .combat;
    MusicManager.setGlobalPhase(.combat);
}

fn initFreshRun(self: *Self) void {
    if (!SaveSystem.isTutorialCompleted()) {
        self.initRunState(0, "tutorial", RoomType.tutorial.defaultMapPath());
        return;
    }
    self.initRunState(1, "normal", RoomType.normal.defaultMapPath());
}

fn resumeRunIfSaved(self: *Self) bool {
    if (!resume_saved_run or !SaveSystem.hasActiveRun()) return false;
    const saved = SaveSystem.getSavedRun() orelse return false;
    self.current_room = if (saved.current_room_index > 0) saved.current_room_index else 1;
    self.rooms_cleared = saved.rooms_cleared;
    self.room_category = saved.room_category;
    if (saved.current_map_path.len > 0) {
        self.current_map_path = saved.current_map_path;
    }
    self.enemies_defeated = saved.enemies_defeated;
    self.state = .replenish;
    MusicManager.setGlobalPhase(.replenish);
    return true;
}

fn applySavedRunToPlayer(player: *lm.Entity) void {
    if (!resume_saved_run or !SaveSystem.hasActiveRun()) return;
    resume_saved_run = false;

    const saved = SaveSystem.getSavedRun() orelse return;
    if (player.getComponent(Stats)) |stats| {
        saved.player_stats.applyToStats(stats);
    }

    const attack = player.getComponent(player_components.Attack) orelse return;
    attack.equipped_weapons = saved.equipped_weapons;
    attack.current_weapon_number = saved.current_weapon_number;

    for (0..2, saved.equipped_spells) |spell_index, maybe_spell| {
        attack.equipped_spells[spell_index] = resolveSavedSpell(maybe_spell);
    }

    const hands = player.getComponent(Hands) orelse return;
    const weapon = attack.currentWeapon() orelse return;
    hands.setWeapon(weapon.*);
}

fn resolveSavedSpell(maybe_spell: anytype) ?Spell {
    const spell = maybe_spell orelse return null;
    const base_spell = spells.getById(spell.id) orelse return null;
    var equipped_spell = base_spell;
    equipped_spell.level = spell.level;
    return equipped_spell;
}

fn getPlayerPosition(self: *const Self) lm.Vector2 {
    const player = self.player orelse return lm.Vec2(0, 0);
    const transform = player.getComponent(lm.Transform) orelse return lm.Vec2(0, 0);
    return lm.vec3ToVec2(transform.position);
}

fn initializeActivePlayer(self: *Self, scene: *lm.Scene) !void {
    const player = scene.getEntityById("player") orelse {
        self.player = null;
        self.player_objectives = null;
        return;
    };

    self.player = player;
    self.player_objectives = player.getComponent(player_components.Objectives);

    if (is_playtest_mode) {
        applyPlaytestScalingToPlayer(player, playtest_room_type);
    } else {
        applySavedRunToPlayer(player);
    }

    if (self.state == .combat and !self.spawner.is_active) {
        try self.startCurrentRoomCombat();
        return;
    }

    if (self.state == .replenish) {
        self.initializeReplenishObjectives();
        if (!DoorSpawner.hasDoorsInScene()) {
            self.spawnDoorsForCurrentRoom(true);
        }
    }
}

fn initializeReplenishObjectives(self: *Self) void {
    const objectives = self.player_objectives orelse return;
    const objective_description = if (is_playtest_mode)
        playtest_replenish_objective_text
    else
        replenish_objective_text;
    _ = objectives.setSingleObjective("Replenish", objective_description) catch {};
}

fn startCurrentRoomCombat(self: *Self) !void {
    self.state = .combat;
    MusicManager.setGlobalPhase(.combat);

    self.spawnDoorsForCurrentRoom(false);

    const room_type = self.getRoomType();
    if (room_type == .tutorial) {
        try lm.summoning.entity(try prefabs.enemies.TrainingDummy(.init(200.0, 0.0)));
        if (TutorialManager.get()) |tutorial_manager| {
            tutorial_manager.reset();
            tutorial_manager.refreshObjectives();
            tutorial_manager.setExitDoorsUnlocked(false);
        }
        return;
    }

    if (self.player_objectives) |objectives| {
        const room_metadata = room_type.metadata();
        _ = try objectives.setSingleObjective(room_metadata.objective_title, room_metadata.objective_description);
    }

    try self.spawner.startWaveForRoom(self.current_room, room_type);
}

fn getPlayerFallbackPosition(self: *const Self) lm.Vector2 {
    const player = self.player orelse return .init(0, 0);
    const transform = player.getComponent(lm.Transform) orelse return .init(0, 0);
    return lm.vec3ToVec2(transform.position).add(.init(48, 0));
}

fn completeCurrentRoomCombat(self: *Self) !void {
    self.state = .replenish;
    self.rooms_cleared += 1;
    self.spawner.finishWave();

    MusicManager.setGlobalPhase(.replenish);
    self.grantRoomRewards();

    if (!self.boon_drop_spawned and self.getRoomType() == .normal) {
        self.boon_drop_spawned = true;
        const fallback_position = self.getPlayerFallbackPosition();
        self.spawnBoonDrop(fallback_position) catch |spawn_error| {
            std.log.err("Failed to spawn fallback boon drop: {any}", .{spawn_error});
        };
    }

    self.initializeReplenishObjectives();

    if (DoorSpawner.hasDoorsInScene()) {
        DoorSpawner.openAllDoors();
    } else {
        self.spawnDoorsForCurrentRoom(true);
    }
    self.saveRunState();
}

fn spawnDoorsForCurrentRoom(self: *Self, is_open: bool) void {
    const player_entity = self.player;
    const stats_value = if (player_entity) |entity| (if (entity.getComponent(Stats)) |stats| stats.* else null) else null;
    const attack_value = if (player_entity) |entity| (if (entity.getComponent(player_components.Attack)) |attack| attack.* else null) else null;

    DoorSpawner.spawnRoomDoors(self.current_room, stats_value, attack_value, is_open) catch |spawn_error| {
        std.log.err("Failed to spawn room doors: {any}", .{spawn_error});
    };
}

pub fn spawnBoonDrop(self: *Self, position: lm.Vector2) !void {
    _ = self;
    const drop = try prefabs.items.BoonDrop(position);
    try lm.summoning.entity(drop);
}

fn grantRoomRewards(self: *Self) void {
    if (is_playtest_mode or is_practice_tutorial_mode) return;
    const player = self.player orelse return;
    const stats = player.getComponent(Stats) orelse return;
    const attack = player.getComponent(player_components.Attack) orelse return;

    const room_type = self.getRoomType();
    switch (room_type) {
        .mini_boss => {
            stats.max.health *= 1.10;
            stats.base.health *= 1.10;
            stats.current.health = stats.max.health;
            AudioManager.playSfxPitched("audio/sfx/coin.wav", 1.0, 0.05);
        },
        .boss => {
            stats.max.health *= 1.15;
            stats.base.health *= 1.15;
            stats.current.health = stats.max.health;
            stats.current.physical_damage += 15.0;
            stats.current.magic_damage += 10.0;
            stats.base.physical_damage += 15.0;
            stats.base.magic_damage += 10.0;
            AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);
        },
        .normal, .tutorial => {
            BoonPool.rerollCategory(stats.*, attack.*, self.room_category);
        },
    }
}

fn exitSpecialModeIfActive() bool {
    if (is_playtest_mode) {
        endPlaytest();
        lm.loadScene("map_editor") catch |load_error| {
            std.log.err("Failed to return to map_editor scene after playtest: {any}", .{load_error});
        };
        return true;
    }
    if (is_practice_tutorial_mode) {
        endPracticeTutorial();
        lm.loadScene("main_menu") catch |load_error| {
            std.log.err("Failed to return to main_menu scene after tutorial practice: {any}", .{load_error});
        };
        return true;
    }
    return false;
}

pub fn enterNextRoomWithCategory(category: []const u8) !void {
    const self = get() orelse return;
    if (exitSpecialModeIfActive()) return;
    self.room_category = category;
    try enterNextRoom();
}

pub fn enterNextRoom() !void {
    const self = get() orelse return;
    if (self.state != .replenish and self.getRoomType() != .tutorial) return;
    if (exitSpecialModeIfActive()) return;

    if (self.getRoomType() == .tutorial) {
        SaveSystem.setTutorialCompleted(true);
    }

    DoorSpawner.cleanupDoors();
    cleanupRoomEntities();
    self.graveyard.clearRetainingCapacity();

    self.current_room += 1;
    const next_room_type = self.getRoomType();
    if (next_room_type != .normal) {
        self.room_category = next_room_type.displayName();
    }
    self.boon_drop_spawned = false;

    self.current_map_path = MapRegistry.pickRandomMap(
        lm.allocators.arena(),
        next_room_type,
        self.current_map_path,
    ) catch MapRegistry.getDefaultMapPath(next_room_type);

    MapLoader.loadAndInstantiate(self.current_map_path) catch |load_error| {
        std.log.warn("Failed to load map {s}: {any}", .{ self.current_map_path, load_error });
    };
    const map_bounds = MapLoader.getMapBounds();
    self.spawner.setMapBounds(map_bounds.min, map_bounds.max);
    self.spawner.setSpawnZones(MapLoader.getSpawnZones());
    repositionPlayer();

    try self.startCurrentRoomCombat();
}

fn isCleanupTarget(entity: *lm.Entity) bool {
    if (std.mem.eql(u8, entity.id, "player")) return false;
    if (std.mem.eql(u8, entity.id, "map_background")) return false;
    if (std.mem.startsWith(u8, entity.id, "wall_")) return false;
    if (std.mem.startsWith(u8, entity.id, "exit-door")) return true;
    if (std.mem.startsWith(u8, entity.id, "training-dummy")) return true;

    const is_enemy_stats = if (entity.getComponent(Stats)) |stats| stats.team == .enemy else false;

    return std.mem.startsWith(u8, entity.id, "experience-orb") or
        std.mem.startsWith(u8, entity.id, "boon-drop") or
        std.mem.endsWith(u8, entity.id, "-enemy") or
        entity.getComponent(ExperienceOrbComponent) != null or
        is_enemy_stats;
}

pub fn cleanupRoomEntities() void {
    ProjectileManager.clearAll();
    const scene = lm.activeScene() orelse return;
    for (scene.entities.items()) |entity| {
        if (isCleanupTarget(entity)) {
            lm.removeEntity(.{ .ptr = entity });
        }
    }
}

pub fn repositionPlayer() void {
    const self = get() orelse return;
    const player = self.player orelse return;
    const spawn_position = MapLoader.getPlayerSpawnPosition();
    if (player.getComponent(lm.Transform)) |transform| {
        transform.position = lm.Vec3(spawn_position.x, spawn_position.y, 0);
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

pub fn getState() ?RoomState {
    const self = get() orelse return null;
    return self.state;
}

pub fn getRoomsCleared() u32 {
    const self = get() orelse return 0;
    return self.rooms_cleared;
}

pub fn getRoomCategory() []const u8 {
    const self = get() orelse return "normal";
    return self.room_category;
}

pub fn getRoomType(self: *const Self) RoomType {
    return RoomType.fromRoomNumber(self.current_room);
}

pub fn saveRunState(self: *Self) void {
    if (is_playtest_mode or is_practice_tutorial_mode) return;
    if (self.state != .replenish) return;

    const player = self.player orelse return;
    const stats = player.getComponent(Stats) orelse return;
    const attack = player.getComponent(player_components.Attack) orelse return;
    SaveSystem.saveRun(
        self.current_room,
        self.rooms_cleared,
        self.room_category,
        self.enemies_defeated,
        self.current_map_path,
        stats.*,
        attack.*,
    );
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

    if (self.spawner.isWaveFinished() and !self.boon_drop_spawned and self.getRoomType() == .normal) {
        self.boon_drop_spawned = true;
        self.spawnBoonDrop(death_position) catch |spawn_error| {
            std.log.err("Failed to spawn boon drop: {any}", .{spawn_error});
        };
    }
}

pub fn registerSummonedEnemy(uuid: u128) void {
    const self = get() orelse return;
    self.spawner.registerSummonedEnemy(uuid) catch {};
}

pub fn popFallenEnemyForRevive() ?FallenEnemyRecord {
    const self = get() orelse return null;
    if (self.graveyard.len() == 0) return null;
    return self.graveyard.swapRemove(self.graveyard.len() - 1);
}

pub fn getRunStats() RunStats {
    const self = get() orelse return .{};
    const experience_amount = if (self.player) |player_entity|
        if (player_entity.getComponent(Stats)) |stats| stats.current.experience else 0
    else
        0;
    return .{
        .rooms_cleared = self.rooms_cleared,
        .current_room = self.current_room,
        .enemies_defeated = self.enemies_defeated,
        .experience_collected = experience_amount,
    };
}

pub fn applyPlaytestScalingToPlayer(player_entity: *lm.Entity, room_type: RoomType) void {
    const stats = player_entity.getComponent(Stats) orelse return;
    const profile = room_type.metadata().playtest_stats;

    stats.max.health = profile.health;
    stats.base.health = profile.health;
    stats.current.health = profile.health;

    if (profile.physical_damage) |physical_damage| {
        stats.current.physical_damage = physical_damage;
        stats.base.physical_damage = physical_damage;
    }
    if (profile.magic_damage) |magic_damage| {
        stats.current.magic_damage = magic_damage;
        stats.base.magic_damage = magic_damage;
    }
    if (profile.armour) |armour| {
        stats.current.armour = armour;
        stats.base.armour = armour;
    }
    if (profile.magic_resist) |magic_resist| {
        stats.current.magic_resist = magic_resist;
        stats.base.magic_resist = magic_resist;
    }
    if (profile.attack_speed) |attack_speed| {
        stats.current.attack_speed = attack_speed;
        stats.base.attack_speed = attack_speed;
    }
}

test "RoomManager initFreshRun starts in the first normal room when tutorial completed" {
    const previous_disk_io = SaveSystem.disable_disk_io_for_tests;
    SaveSystem.disable_disk_io_for_tests = true;
    defer {
        SaveSystem.deinit();
        SaveSystem.disable_disk_io_for_tests = previous_disk_io;
    }

    SaveSystem.setTutorialCompleted(true);

    var room_manager = Self{};
    room_manager.initFreshRun();

    try std.testing.expectEqual(RoomState.combat, room_manager.state);
    try std.testing.expectEqual(@as(u32, 1), room_manager.current_room);
    try std.testing.expectEqual(@as(u32, 0), room_manager.rooms_cleared);
    try std.testing.expectEqualStrings("normal", room_manager.room_category);
}

test "RoomManager initFreshRun starts in tutorial when tutorial not completed" {
    const previous_disk_io = SaveSystem.disable_disk_io_for_tests;
    SaveSystem.disable_disk_io_for_tests = true;
    defer {
        SaveSystem.deinit();
        SaveSystem.disable_disk_io_for_tests = previous_disk_io;
    }

    SaveSystem.setTutorialCompleted(false);

    var room_manager = Self{};
    room_manager.initFreshRun();

    try std.testing.expectEqual(RoomState.combat, room_manager.state);
    try std.testing.expectEqual(@as(u32, 0), room_manager.current_room);
    try std.testing.expectEqual(@as(u32, 0), room_manager.rooms_cleared);
    try std.testing.expectEqualStrings("tutorial", room_manager.room_category);
    try std.testing.expectEqualStrings("maps/tutorial.json", room_manager.current_map_path);
}

test "RoomManager determinePlaytestNormalRoom sets room according to highest unlock round" {
    const empty_zones = [_]MapTypes.SpawnZoneRecord{};
    try std.testing.expectEqual(@as(u32, 2), determinePlaytestNormalRoom(&empty_zones));

    const shaman_zones = [_]MapTypes.SpawnZoneRecord{
        .{
            .center_x_pixels = 0,
            .center_y_pixels = 0,
            .enemy_type = .shaman,
        },
    };
    try std.testing.expectEqual(@as(u32, 3), determinePlaytestNormalRoom(&shaman_zones));

    const magician_zones = [_]MapTypes.SpawnZoneRecord{
        .{
            .center_x_pixels = 0,
            .center_y_pixels = 0,
            .enemy_type = .magician,
        },
    };
    try std.testing.expectEqual(@as(u32, 4), determinePlaytestNormalRoom(&magician_zones));
}
