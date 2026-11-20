const std = @import("std");
const builtin = @import("builtin");
const lm = @import("loom");

const AudioManager = @import("../audio/AudioManager.zig");
const RoomManager = @import("../RoomManager.zig");
const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const ControlScheme = @import("../input/ControlScheme.zig");
const SaveData = @import("SaveData.zig");

const SaveFile = SaveData.SaveFile;
const AllTimeScores = SaveData.AllTimeScores;
const CurrentRunData = SaveData.CurrentRunData;
const SavedPlayerStats = SaveData.SavedPlayerStats;

pub var disable_disk_io_for_tests: bool = builtin.is_test;

var current_save: SaveFile = .{};
var is_initialized: bool = false;
var save_arena: ?std.heap.ArenaAllocator = null;
var test_memory_json: ?[]u8 = null;

pub fn deinit() void {
    if (save_arena) |*arena| {
        arena.deinit();
        save_arena = null;
    }
    if (test_memory_json) |buffer| {
        lm.allocators.generic().free(buffer);
        test_memory_json = null;
    }
    current_save = .{};
    is_initialized = false;
}

pub fn getSavePathAlloc(allocator: std.mem.Allocator) ![]const u8 {
    const io = lm.io.singleThreaded();
    const executable_directory = std.process.executableDirPathAlloc(io, allocator) catch {
        return try allocator.dupe(u8, "save.json");
    };
    defer allocator.free(executable_directory);
    return try std.fs.path.join(allocator, &.{ executable_directory, "save.json" });
}

pub fn init() void {
    if (is_initialized) return;

    load();
    applySettings();
    is_initialized = true;
}

fn resetSaveArena() void {
    if (save_arena) |*arena| {
        arena.deinit();
        save_arena = null;
    }
}

fn parseSaveJson(allocator: std.mem.Allocator, json_bytes: []const u8) bool {
    resetSaveArena();
    var arena = std.heap.ArenaAllocator.init(allocator);

    const parsed = std.json.parseFromSlice(
        SaveFile,
        arena.allocator(),
        json_bytes,
        .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        },
    ) catch |parse_error| {
        arena.deinit();
        std.log.warn("Failed to parse save file ({any}), using defaults", .{parse_error});
        current_save = .{};
        return false;
    };

    if (parsed.value.version != SaveData.CURRENT_SAVE_VERSION) {
        std.log.info("Save file version mismatch (found version {d}, expected version {d}). Resetting save data to defaults.", .{
            parsed.value.version,
            SaveData.CURRENT_SAVE_VERSION,
        });
        arena.deinit();
        current_save = .{};
        return false;
    }

    save_arena = arena;
    current_save = parsed.value;
    return true;
}

pub fn load() void {
    const allocator = lm.allocators.generic();

    if (disable_disk_io_for_tests) {
        const json_bytes = test_memory_json orelse {
            current_save = .{};
            return;
        };
        if (!parseSaveJson(allocator, json_bytes)) {
            save();
        }
        return;
    }

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

    var read_buffer: [1024]u8 = @splat(0);
    var file_reader = file.reader(io, &read_buffer);
    const json_bytes = file_reader.interface.allocRemaining(allocator, .limited(4 * 1024 * 1024)) catch |read_error| {
        std.log.warn("Failed to read save file at {s} ({any}), falling back to defaults", .{ save_path, read_error });
        current_save = .{};
        return;
    };
    defer allocator.free(json_bytes);

    if (!parseSaveJson(allocator, json_bytes)) {
        save();
    }
}

pub fn save() void {
    const allocator = lm.allocators.generic();
    const json_string = std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(current_save, .{ .whitespace = .indent_2 })}) catch return;

    if (disable_disk_io_for_tests) {
        if (test_memory_json) |previous_buffer| {
            allocator.free(previous_buffer);
        }
        test_memory_json = json_string;
        return;
    }
    defer allocator.free(json_string);

    const io = lm.io.singleThreaded();
    const save_path = getSavePathAlloc(allocator) catch return;
    defer allocator.free(save_path);

    var file = std.Io.Dir.createFileAbsolute(io, save_path, .{}) catch |create_error| {
        std.log.warn("Failed to create save file at {s}: {any}", .{ save_path, create_error });
        return;
    };
    defer file.close(io);

    var write_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(io, &write_buffer);
    var writer = &file_writer.interface;
    writer.writeAll(json_string) catch return;
    writer.flush() catch return;
}

pub fn getScores() AllTimeScores {
    return current_save.scores;
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
    ControlScheme.setControlScheme(current_save.settings.control_scheme);
}

pub fn updateSettings(master: f32, music: f32, sfx: f32, mute: bool) void {
    current_save.settings.master_volume = master;
    current_save.settings.music_volume = music;
    current_save.settings.sfx_volume = sfx;
    current_save.settings.mute = mute;
    applySettings();
    save();
}

pub fn updateControlScheme(scheme: ControlScheme.ControlScheme) void {
    current_save.settings.control_scheme = scheme;
    ControlScheme.setControlScheme(scheme);
    save();
}

pub fn hasActiveRun() bool {
    return current_save.current_run.has_active_run;
}

pub fn getSavedRun() ?CurrentRunData {
    if (!hasActiveRun()) return null;
    return current_save.current_run;
}

pub fn recordRunEnd(stats: RoomManager.RunStats) void {
    current_save.scores.total_runs_played += 1;
    current_save.scores.total_enemies_killed += stats.enemies_defeated;

    if (stats.experience_collected > current_save.scores.high_score) {
        current_save.scores.high_score = stats.experience_collected;
    }
    if (stats.rooms_cleared > current_save.scores.highest_round) {
        current_save.scores.highest_round = stats.rooms_cleared;
    }

    current_save.current_run.has_active_run = false;
    save();
}

pub fn saveRun(
    current_room_index: u32,
    rooms_cleared: u32,
    room_category: []const u8,
    enemies_defeated: u32,
    current_map_path: []const u8,
    stats: Stats,
    attack: Attack,
) void {
    current_save.current_run.has_active_run = true;
    current_save.current_run.current_room_index = current_room_index;
    current_save.current_run.rooms_cleared = rooms_cleared;
    current_save.current_run.room_category = room_category;
    current_save.current_run.enemies_defeated = enemies_defeated;
    current_save.current_run.current_map_path = current_map_path;
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
    const previous_disk_io = disable_disk_io_for_tests;
    disable_disk_io_for_tests = true;
    defer {
        deinit();
        disable_disk_io_for_tests = previous_disk_io;
    }

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
}

test "SaveSystem updateSettings modifies and retains settings" {
    const testing = std.testing;
    const previous_disk_io = disable_disk_io_for_tests;
    const previous_master = AudioManager.master_volume;
    const previous_music = AudioManager.music_volume;
    const previous_sfx = AudioManager.sfx_volume;
    const previous_mute = AudioManager.mute;
    const previous_scheme = ControlScheme.getControlScheme();
    disable_disk_io_for_tests = true;
    defer {
        AudioManager.setMasterVolume(previous_master);
        AudioManager.setMusicVolume(previous_music);
        AudioManager.setSfxVolume(previous_sfx);
        AudioManager.setMute(previous_mute);
        ControlScheme.setControlScheme(previous_scheme);
        deinit();
        disable_disk_io_for_tests = previous_disk_io;
    }

    current_save = .{};
    updateSettings(0.65, 0.45, 0.85, true);

    const saved_settings = current_save.settings;
    try testing.expectEqual(@as(f32, 0.65), saved_settings.master_volume);
    try testing.expectEqual(@as(f32, 0.45), saved_settings.music_volume);
    try testing.expectEqual(@as(f32, 0.85), saved_settings.sfx_volume);
    try testing.expect(saved_settings.mute);

    updateControlScheme(.keyboard_only);
    try testing.expectEqual(ControlScheme.ControlScheme.keyboard_only, current_save.settings.control_scheme);
    try testing.expectEqual(ControlScheme.ControlScheme.keyboard_only, ControlScheme.getControlScheme());

    updateControlScheme(.keyboard_and_mouse);
    try testing.expectEqual(ControlScheme.ControlScheme.keyboard_and_mouse, current_save.settings.control_scheme);
    try testing.expectEqual(ControlScheme.ControlScheme.keyboard_and_mouse, ControlScheme.getControlScheme());
}

test "SaveSystem saveRun and clearRun lifecycle" {
    const testing = std.testing;
    const previous_disk_io = disable_disk_io_for_tests;
    disable_disk_io_for_tests = true;
    defer {
        deinit();
        disable_disk_io_for_tests = previous_disk_io;
    }

    current_save = .{};
    try testing.expect(!hasActiveRun());

    var stats = Stats.init(.player, .{ .health = 75, .experience = 500 });
    defer stats.deinit();

    var attack = Attack{};
    attack.equipped_weapons[0] = .{
        .id = "SavedWeaponTest",
        .type = .wide,
        .light_attack = .{
            .projectile_options = .{ .damage = 99.0 },
        },
    };

    saveRun(4, 3, "normal", 27, "maps/normal/arena_normal.json", stats, attack);

    try testing.expect(hasActiveRun());
    const saved = getSavedRun().?;
    try testing.expectEqual(@as(u32, 4), saved.current_room_index);
    try testing.expectEqual(@as(u32, 3), saved.rooms_cleared);
    try testing.expectEqualStrings("normal", saved.room_category);
    try testing.expectEqualStrings("maps/normal/arena_normal.json", saved.current_map_path);
    try testing.expectEqual(@as(u32, 27), saved.enemies_defeated);
    try testing.expectEqual(@as(f32, 75), saved.player_stats.health);
    try testing.expectEqual(@as(usize, 500), saved.player_stats.experience);
    try testing.expectEqualStrings("SavedWeaponTest", saved.equipped_weapons[0].?.id);
    try testing.expectEqual(@as(f32, 99.0), saved.equipped_weapons[0].?.light_attack.projectile_options.damage);

    clearRun();
    try testing.expect(!hasActiveRun());
    try testing.expect(getSavedRun() == null);
}

test "SaveSystem load and re-save after resume (boon purchase simulation)" {
    const testing = std.testing;
    const previous_disk_io = disable_disk_io_for_tests;
    disable_disk_io_for_tests = true;
    defer {
        deinit();
        disable_disk_io_for_tests = previous_disk_io;
    }

    current_save = .{};
    var stats = Stats.init(.player, .{ .health = 100, .experience = 250 });
    defer stats.deinit();

    var attack = Attack{};
    attack.equipped_weapons[0] = .{
        .id = "DashFists",
        .dash_attack = .{
            .shooting_degrees = &.{ -2, 0, 2 },
            .projectile_options = .{ .damage = 15.0 },
        },
    };

    saveRun(2, 1, "plate_upgrades", 12, "maps/normal/arena_normal.json", stats, attack);
    try testing.expect(hasActiveRun());

    load();
    try testing.expect(hasActiveRun());

    const saved = getSavedRun().?;
    var resumed_attack = Attack{};
    resumed_attack.equipped_weapons = saved.equipped_weapons;

    resumed_attack.equipped_weapons[0].?.dash_attack.projectile_options.damage *= 1.25;
    saveRun(saved.current_room_index, saved.rooms_cleared, saved.room_category, saved.enemies_defeated, saved.current_map_path, stats, resumed_attack);

    const reloaded = getSavedRun().?;
    try testing.expectEqualStrings("DashFists", reloaded.equipped_weapons[0].?.id);
    try testing.expectEqualStrings("plate_upgrades", reloaded.room_category);
    try testing.expectEqual(@as(usize, 3), reloaded.equipped_weapons[0].?.dash_attack.shooting_degrees.len);
    try testing.expectEqual(@as(f32, -2), reloaded.equipped_weapons[0].?.dash_attack.shooting_degrees[0]);

    clearRun();
}
