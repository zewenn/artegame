const std = @import("std");
const Weapon = @import("../../components/weapons/Weapon.zig");
const Stats = @import("../../components/Stats.zig");
const ControlScheme = @import("../input/ControlScheme.zig").ControlScheme;

pub const SettingsData = struct {
    master_volume: f32 = 1.0,
    music_volume: f32 = 0.7,
    sfx_volume: f32 = 0.8,
    mute: bool = false,
    control_scheme: ControlScheme = .keyboard_and_mouse,
};

pub const AllTimeScores = struct {
    high_score: usize = 0,
    highest_round: u32 = 0,
    total_enemies_killed: u32 = 0,
    total_runs_played: u32 = 0,
};

pub const SavedSpell = struct {
    id: []const u8 = "",
    level: u32 = 1,
};

pub const SavedPlayerStats = struct {
    health: f32 = 100,
    max_health: f32 = 100,
    stamina: f32 = 100,
    max_stamina: f32 = 100,
    movement_speed: f32 = 330,
    dash_time: f32 = 0.2,
    dash_speed_multiplier: f32 = 3,
    armour: f32 = 30,
    magic_resist: f32 = 0,
    physical_damage: f32 = 20,
    magic_damage: f32 = 0,
    crit_damage_multiplier: f32 = 2,
    crit_chance: f32 = 0,
    attack_speed: f32 = 5,
    aggro_range: f32 = 300,
    experience: usize = 0,

    pub fn fromStats(stats: Stats) SavedPlayerStats {
        var saved = SavedPlayerStats{
            .max_health = stats.max.health,
            .max_stamina = stats.max.stamina,
        };
        inline for (@typeInfo(Stats.StatValues).@"struct".field_names) |field_name| {
            @field(saved, field_name) = @field(stats.current, field_name);
        }
        return saved;
    }

    pub fn applyToStats(self: SavedPlayerStats, stats: *Stats) void {
        inline for (@typeInfo(Stats.StatValues).@"struct".field_names) |field_name| {
            const value = @field(self, field_name);
            @field(stats.current, field_name) = value;
            @field(stats.base, field_name) = value;
            @field(stats.max, field_name) = value;
        }
        stats.max.health = self.max_health;
        stats.max.stamina = self.max_stamina;
    }
};

pub const CURRENT_SAVE_VERSION: u32 = 4;

pub const ProfileData = struct {
    tutorial_completed: bool = false,
};

pub const CurrentRunData = struct {
    has_active_run: bool = false,
    current_room_index: u32 = 1,
    rooms_cleared: u32 = 0,
    room_category: []const u8 = "normal",
    current_map_path: []const u8 = "",
    enemies_defeated: u32 = 0,
    player_stats: SavedPlayerStats = .{},
    equipped_weapons: [2]?Weapon = [_]?Weapon{ null, null },
    current_weapon_number: u1 = 0,
    equipped_spells: [2]?SavedSpell = [_]?SavedSpell{ null, null },
};

pub const SaveFile = struct {
    version: u32 = CURRENT_SAVE_VERSION,
    settings: SettingsData = .{},
    profile: ProfileData = .{},
    scores: AllTimeScores = .{},
    current_run: CurrentRunData = .{},
};

test "SaveFile serialization and deserialization roundtrip" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var save_file = SaveFile{};
    save_file.scores.high_score = 9999;
    save_file.scores.highest_round = 12;
    save_file.settings.master_volume = 0.5;
    save_file.current_run.has_active_run = true;
    save_file.current_run.current_room_index = 3;
    save_file.current_run.equipped_weapons[0] = Weapon{
        .id = "CustomFists",
        .light_attack = .{
            .projectile_options = .{ .damage = 15.5 },
        },
    };
    save_file.current_run.equipped_spells[0] = .{ .id = "Heal", .level = 3 };

    const json_string = try std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(save_file, .{})});
    defer allocator.free(json_string);

    var parsed = try std.json.parseFromSlice(SaveFile, allocator, json_string, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try testing.expectEqual(@as(u32, CURRENT_SAVE_VERSION), parsed.value.version);
    try testing.expectEqual(@as(usize, 9999), parsed.value.scores.high_score);
    try testing.expectEqual(@as(u32, 12), parsed.value.scores.highest_round);
    try testing.expectEqual(@as(f32, 0.5), parsed.value.settings.master_volume);
    try testing.expect(parsed.value.current_run.has_active_run);
    try testing.expectEqual(@as(u32, 3), parsed.value.current_run.current_room_index);
    try testing.expectEqualStrings("CustomFists", parsed.value.current_run.equipped_weapons[0].?.id);
    try testing.expectEqual(@as(f32, 15.5), parsed.value.current_run.equipped_weapons[0].?.light_attack.projectile_options.damage);
    try testing.expectEqualStrings("Heal", parsed.value.current_run.equipped_spells[0].?.id);
    try testing.expectEqual(@as(u32, 3), parsed.value.current_run.equipped_spells[0].?.level);
}

test "SavedPlayerStats restores current, base, and max stat values" {
    var source = Stats.init(.player, .{
        .health = 100,
        .movement_speed = 420,
        .physical_damage = 55,
    });
    defer source.deinit();

    source.max.health = 160;
    source.current.health = 85;
    source.max.stamina = 140;
    source.current.stamina = 60;

    const saved = SavedPlayerStats.fromStats(source);

    var restored = Stats.init(.player, .{});
    defer restored.deinit();
    saved.applyToStats(&restored);

    try std.testing.expectEqual(@as(f32, 85), restored.current.health);
    try std.testing.expectEqual(@as(f32, 160), restored.max.health);
    try std.testing.expectEqual(@as(f32, 60), restored.current.stamina);
    try std.testing.expectEqual(@as(f32, 140), restored.max.stamina);
    try std.testing.expectEqual(@as(f32, 420), restored.current.movement_speed);
    try std.testing.expectEqual(@as(f32, 420), restored.base.movement_speed);
    try std.testing.expectEqual(@as(f32, 420), restored.max.movement_speed);
    try std.testing.expectEqual(@as(f32, 55), restored.base.physical_damage);
}
