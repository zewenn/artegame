const std = @import("std");
const lm = @import("loom");

const AudioManager = @import("../audio/AudioManager.zig");
const RoomManager = @import("../RoomManager.zig");
const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Weapon = @import("../../components/Weapons/Weapon.zig");
const SaveData = @import("SaveData.zig");

pub const SaveFile = SaveData.SaveFile;
pub const AllTimeScores = SaveData.AllTimeScores;
pub const CurrentRunData = SaveData.CurrentRunData;
pub const SettingsData = SaveData.SettingsData;
pub const ProfileData = SaveData.ProfileData;
pub const SavedPlayerStats = SaveData.SavedPlayerStats;
pub const SavedSpell = SaveData.SavedSpell;

var current_save: SaveFile = .{};
var is_initialized: bool = false;
var save_arena: ?std.heap.ArenaAllocator = null;

pub fn deinit() void {
    if (save_arena) |*arena| {
        arena.deinit();
        save_arena = null;
    }
    is_initialized = false;
}

pub fn getSavePathAlloc(allocator: std.mem.Allocator) ![]const u8 {
    const io = lm.io.singleThreaded();
    const exe_dir = std.process.executableDirPathAlloc(io, allocator) catch {
        return try allocator.dupe(u8, "save.json");
    };
    defer allocator.free(exe_dir);
    return try std.fs.path.join(allocator, &.{ exe_dir, "save.json" });
}

pub fn init() void {
    if (is_initialized) return;

    load();
    applySettings();
    is_initialized = true;
}

pub fn load() void {
    const allocator = lm.allocators.generic();
    const io = lm.io.singleThreaded();

    const save_path = getSavePathAlloc(allocator) catch {
        current_save = .{};
        return;
    };
    defer allocator.free(save_path);

    var file = std.Io.Dir.openFileAbsolute(io, save_path, .{ .mode = .read_only }) catch {
        current_save = .{};
        save();
        return;
    };
    defer file.close(io);

    var buffer: [1024 * 256]u8 = undefined;
    const bytes_read = file.readPositionalAll(io, &buffer, 0) catch {
        std.log.warn("Failed to read save file at {s}, falling back to defaults", .{save_path});
        current_save = .{};
        return;
    };

    if (save_arena) |*arena| {
        arena.deinit();
        save_arena = null;
    }
    var arena = std.heap.ArenaAllocator.init(allocator);

    const parsed = std.json.parseFromSlice(
        SaveFile,
        arena.allocator(),
        buffer[0..bytes_read],
        .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        },
    ) catch |err| {
        arena.deinit();
        std.log.warn("Failed to parse save file ({any}), using defaults", .{err});
        current_save = .{};
        save();
        return;
    };

    if (parsed.value.version != SaveData.CURRENT_SAVE_VERSION) {
        std.log.info("Save file version mismatch (found version {d}, expected version {d}). Resetting save data to defaults.", .{
            parsed.value.version,
            SaveData.CURRENT_SAVE_VERSION,
        });
        arena.deinit();
        save_arena = null;
        current_save = .{};
        save();
        return;
    }

    save_arena = arena;
    current_save = parsed.value;
}

pub fn save() void {
    const allocator = lm.allocators.generic();
    const io = lm.io.singleThreaded();

    const save_path = getSavePathAlloc(allocator) catch return;
    defer allocator.free(save_path);

    const json_string = std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(current_save, .{ .whitespace = .indent_2 })}) catch return;
    defer allocator.free(json_string);

    var file = std.Io.Dir.createFileAbsolute(io, save_path, .{}) catch |err| {
        std.log.warn("Failed to create save file at {s}: {any}", .{ save_path, err });
        return;
    };
    defer file.close(io);

    var buf: [4096]u8 = undefined;
    var wr = file.writer(io, &buf);
    var writer = &wr.interface;
    writer.writeAll(json_string) catch return;
    writer.flush() catch return;
}

pub fn getScores() AllTimeScores {
    return current_save.scores;
}

pub fn getSettings() SettingsData {
    return current_save.settings;
}

pub fn getProfile() ProfileData {
    return current_save.profile;
}

pub fn isTutorialCompleted() bool {
    return current_save.profile.tutorial_completed;
}

pub fn setTutorialCompleted(completed: bool) void {
    current_save.profile.tutorial_completed = completed;
    save();
}

pub fn applySettings() void {
    AudioManager.setMasterVolume(current_save.settings.master_volume);
    AudioManager.setMusicVolume(current_save.settings.music_volume);
    AudioManager.setSfxVolume(current_save.settings.sfx_volume);
    AudioManager.setMute(current_save.settings.mute);
}

pub fn updateSettings(master: f32, music: f32, sfx: f32, mute: bool) void {
    current_save.settings.master_volume = master;
    current_save.settings.music_volume = music;
    current_save.settings.sfx_volume = sfx;
    current_save.settings.mute = mute;
    applySettings();
    save();
}

pub fn hasActiveRun() bool {
    return current_save.current_run.has_active_run;
}

pub fn getSavedRun() ?CurrentRunData {
    if (!hasActiveRun()) return null;
    return current_save.current_run;
}

pub fn getCurrentRoomIndex() ?u32 {
    if (!hasActiveRun()) return null;
    return current_save.current_run.current_room_index;
}

pub fn getRoomsCleared() ?u32 {
    if (!hasActiveRun()) return null;
    return current_save.current_run.rooms_cleared;
}

pub fn getRoomCategory() ?[]const u8 {
    if (!hasActiveRun()) return null;
    return current_save.current_run.room_category;
}

pub fn recordRunEnd(stats: RoomManager.RunStats) void {
    current_save.scores.total_runs_played += 1;
    current_save.scores.total_enemies_killed += stats.enemies_defeated;
    current_save.scores.total_experience_earned += stats.experience_collected;

    if (stats.experience_collected > current_save.scores.high_score) {
        current_save.scores.high_score = stats.experience_collected;
    }
    if (stats.rooms_cleared > current_save.scores.highest_round) {
        current_save.scores.highest_round = stats.rooms_cleared;
    }
    if (stats.enemies_defeated > current_save.scores.best_enemies_killed_in_run) {
        current_save.scores.best_enemies_killed_in_run = stats.enemies_defeated;
    }

    current_save.current_run.has_active_run = false;
    save();
}

pub fn saveRun(
    current_room_index: u32,
    rooms_cleared: u32,
    room_category: []const u8,
    enemies_defeated: u32,
    stats: Stats,
    attack: Attack,
) void {
    current_save.current_run.has_active_run = true;
    current_save.current_run.current_room_index = current_room_index;
    current_save.current_run.rooms_cleared = rooms_cleared;
    current_save.current_run.room_category = room_category;
    current_save.current_run.enemies_defeated = enemies_defeated;
    current_save.current_run.player_stats = SavedPlayerStats.fromStats(stats);

    current_save.current_run.equipped_weapons = attack.equipped_weapons;
    current_save.current_run.current_weapon_number = attack.current_weapon_number;

    for (attack.equipped_spells, 0..) |maybe_spell, spell_index| {
        if (maybe_spell) |spell| {
            current_save.current_run.equipped_spells[spell_index] = .{
                .id = spell.id,
                .level = spell.level,
            };
        } else {
            current_save.current_run.equipped_spells[spell_index] = null;
        }
    }

    save();
}

pub fn clearRun() void {
    current_save.current_run.has_active_run = false;
    save();
}

test "SaveSystem score recording and run lifecycle" {
    const testing = std.testing;

    current_save = .{};

    try testing.expect(!hasActiveRun());
    try testing.expectEqual(@as(usize, 0), getScores().high_score);

    recordRunEnd(.{
        .rooms_cleared = 5,
        .current_room = 6,
        .enemies_defeated = 35,
        .experience_collected = 1500,
    });

    try testing.expectEqual(@as(u32, 1), getScores().total_runs_played);
    try testing.expectEqual(@as(u32, 35), getScores().total_enemies_killed);
    try testing.expectEqual(@as(usize, 1500), getScores().high_score);
    try testing.expectEqual(@as(u32, 5), getScores().highest_round);
    try testing.expectEqual(@as(u32, 35), getScores().best_enemies_killed_in_run);
    try testing.expect(!hasActiveRun());

    recordRunEnd(.{
        .rooms_cleared = 2,
        .current_room = 3,
        .enemies_defeated = 10,
        .experience_collected = 400,
    });

    try testing.expectEqual(@as(u32, 2), getScores().total_runs_played);
    try testing.expectEqual(@as(u32, 45), getScores().total_enemies_killed);
    try testing.expectEqual(@as(usize, 1500), getScores().high_score);
    try testing.expectEqual(@as(u32, 5), getScores().highest_round);
    try testing.expectEqual(@as(u32, 35), getScores().best_enemies_killed_in_run);
}

test "SaveSystem updateSettings modifies and retains settings" {
    const testing = std.testing;

    current_save = .{};
    updateSettings(0.65, 0.45, 0.85, true);

    const s = getSettings();
    try testing.expectEqual(@as(f32, 0.65), s.master_volume);
    try testing.expectEqual(@as(f32, 0.45), s.music_volume);
    try testing.expectEqual(@as(f32, 0.85), s.sfx_volume);
    try testing.expect(s.mute);
}

test "SaveSystem tutorial completed query and persistence" {
    const testing = std.testing;

    current_save = .{};
    try testing.expect(!isTutorialCompleted());

    current_save.profile.tutorial_completed = true;
    try testing.expect(isTutorialCompleted());

    current_save.profile.tutorial_completed = false;
    try testing.expect(!isTutorialCompleted());
}

test "SaveSystem saveRun and clearRun lifecycle" {
    const testing = std.testing;

    current_save = .{};
    try testing.expect(!hasActiveRun());

    var stats = Stats.init(.player, .{ .health = 75, .experience = 500 });
    defer stats.deinit();

    var attack = Attack{};
    attack.equipped_weapons[0] = Weapon{
        .id = "SavedWeaponTest",
        .type = .wide,
        .light_attack = .{
            .projectile_options = .{ .damage = 99.0 },
        },
    };

    saveRun(4, 3, "normal", 27, stats, attack);

    try testing.expect(hasActiveRun());
    const saved = getSavedRun().?;
    try testing.expectEqual(@as(u32, 4), saved.current_room_index);
    try testing.expectEqual(@as(u32, 3), saved.rooms_cleared);
    try testing.expectEqualStrings("normal", saved.room_category);
    try testing.expectEqual(@as(u32, 27), saved.enemies_defeated);
    try testing.expectEqual(@as(f32, 75), saved.player_stats.health);
    try testing.expectEqual(@as(usize, 500), saved.player_stats.experience);
    try testing.expectEqualStrings("SavedWeaponTest", saved.equipped_weapons[0].?.id);
    try testing.expectEqual(@as(f32, 99.0), saved.equipped_weapons[0].?.light_attack.projectile_options.damage);

    try testing.expectEqual(@as(?u32, 4), getCurrentRoomIndex());
    try testing.expectEqual(@as(?u32, 3), getRoomsCleared());
    try testing.expectEqualStrings("normal", getRoomCategory().?);

    clearRun();
    try testing.expect(!hasActiveRun());
    try testing.expect(getSavedRun() == null);
}

test "SaveSystem getSavePathAlloc resolves path ending with save.json" {
    const testing = std.testing;
    const path = try getSavePathAlloc(testing.allocator);
    defer testing.allocator.free(path);

    try testing.expect(std.mem.endsWith(u8, path, "save.json"));
}

test "SaveSystem load and re-save after resume (boon purchase simulation)" {
    const testing = std.testing;

    var stats = Stats.init(.player, .{ .health = 100, .experience = 250 });
    defer stats.deinit();

    var attack = Attack{};
    attack.equipped_weapons[0] = Weapon{
        .id = "DashFists",
        .dash_attack = .{
            .shooting_degrees = &.{ -2, 0, 2 },
            .projectile_options = .{ .damage = 15.0 },
        },
    };

    saveRun(2, 1, "plate_upgrades", 12, stats, attack);
    try testing.expect(hasActiveRun());

    load();
    try testing.expect(hasActiveRun());

    const saved = getSavedRun().?;
    var resumed_attack = Attack{};
    resumed_attack.equipped_weapons = saved.equipped_weapons;

    resumed_attack.equipped_weapons[0].?.dash_attack.projectile_options.damage *= 1.25;
    saveRun(saved.current_room_index, saved.rooms_cleared, saved.room_category, saved.enemies_defeated, stats, resumed_attack);

    const reloaded = getSavedRun().?;
    try testing.expectEqualStrings("DashFists", reloaded.equipped_weapons[0].?.id);
    try testing.expectEqualStrings("plate_upgrades", reloaded.room_category);
    try testing.expectEqual(@as(usize, 3), reloaded.equipped_weapons[0].?.dash_attack.shooting_degrees.len);
    try testing.expectEqual(@as(f32, -2), reloaded.equipped_weapons[0].?.dash_attack.shooting_degrees[0]);

    clearRun();
}

test "SaveSystem detects legacy version mismatch and resets" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const legacy_json =
        \\{
        \\  "version": 1,
        \\  "scores": {
        \\    "high_score": 5000
        \\  }
        \\}
    ;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = try std.json.parseFromSlice(
        SaveFile,
        arena.allocator(),
        legacy_json,
        .{ .ignore_unknown_fields = true },
    );

    try testing.expectEqual(@as(u32, 1), parsed.value.version);

    try testing.expect(parsed.value.version != SaveData.CURRENT_SAVE_VERSION);
}
