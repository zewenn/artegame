const std = @import("std");
const lm = @import("loom");
const Weapon = @import("../../components/Weapons/Weapon.zig");
const Stats = @import("../../components/Stats.zig");

pub const SettingsData = struct {
    master_volume: f32 = 1.0,
    music_volume: f32 = 0.7,
    sfx_volume: f32 = 0.8,
    mute: bool = false,
};

pub const AllTimeScores = struct {
    high_score: usize = 0,
    highest_round: u32 = 0,
    total_enemies_killed: u32 = 0,
    total_runs_played: u32 = 0,
    best_enemies_killed_in_run: u32 = 0,
    total_experience_earned: usize = 0,
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
        return .{
            .health = stats.current.health,
            .max_health = stats.max.health,
            .stamina = stats.current.stamina,
            .max_stamina = stats.max.stamina,
            .movement_speed = stats.current.movement_speed,
            .dash_time = stats.current.dash_time,
            .dash_speed_multiplier = stats.current.dash_speed_multiplier,
            .armour = stats.current.armour,
            .magic_resist = stats.current.magic_resist,
            .physical_damage = stats.current.physical_damage,
            .magic_damage = stats.current.magic_damage,
            .crit_damage_multiplier = stats.current.crit_damage_multiplier,
            .crit_chance = stats.current.crit_chance,
            .attack_speed = stats.current.attack_speed,
            .aggro_range = stats.current.aggro_range,
            .experience = stats.current.experience,
        };
    }

    pub fn applyToStats(self: SavedPlayerStats, stats: *Stats) void {
        stats.current.health = self.health;
        stats.max.health = self.max_health;
        stats.current.stamina = self.stamina;
        stats.max.stamina = self.max_stamina;
        stats.current.movement_speed = self.movement_speed;
        stats.current.dash_time = self.dash_time;
        stats.current.dash_speed_multiplier = self.dash_speed_multiplier;
        stats.current.armour = self.armour;
        stats.current.magic_resist = self.magic_resist;
        stats.current.physical_damage = self.physical_damage;
        stats.current.magic_damage = self.magic_damage;
        stats.current.crit_damage_multiplier = self.crit_damage_multiplier;
        stats.current.crit_chance = self.crit_chance;
        stats.current.attack_speed = self.attack_speed;
        stats.current.aggro_range = self.aggro_range;
        stats.current.experience = self.experience;
    }
};

pub const CurrentRunData = struct {
    has_active_run: bool = false,
    round: u32 = 1,
    rounds_survived: u32 = 0,
    enemies_defeated: u32 = 0,
    player_stats: SavedPlayerStats = .{},
    equipped_weapons: [2]?Weapon = [_]?Weapon{ null, null },
    current_weapon_number: u1 = 0,
    equipped_spells: [2]?SavedSpell = [_]?SavedSpell{ null, null },
};

pub const SaveFile = struct {
    version: u32 = 1,
    settings: SettingsData = .{},
    scores: AllTimeScores = .{},
    current_run: CurrentRunData = .{},
};

test "SaveFile serialization and deserialization roundtrip" {
    const testing = std.testing;
    const alloc = testing.allocator;

    var save_file = SaveFile{};
    save_file.scores.high_score = 9999;
    save_file.scores.highest_round = 12;
    save_file.settings.master_volume = 0.5;
    save_file.current_run.has_active_run = true;
    save_file.current_run.round = 3;
    save_file.current_run.equipped_weapons[0] = Weapon{
        .id = "CustomFists",
        .light_attack = .{
            .projectile_options = .{ .damage = 15.5 },
        },
    };
    save_file.current_run.equipped_spells[0] = .{ .id = "Heal", .level = 3 };

    const json_str = try std.fmt.allocPrint(alloc, "{f}", .{std.json.fmt(save_file, .{})});
    defer alloc.free(json_str);

    var parsed = try std.json.parseFromSlice(SaveFile, alloc, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try testing.expectEqual(@as(u32, 1), parsed.value.version);
    try testing.expectEqual(@as(usize, 9999), parsed.value.scores.high_score);
    try testing.expectEqual(@as(u32, 12), parsed.value.scores.highest_round);
    try testing.expectEqual(@as(f32, 0.5), parsed.value.settings.master_volume);
    try testing.expect(parsed.value.current_run.has_active_run);
    try testing.expectEqual(@as(u32, 3), parsed.value.current_run.round);
    try testing.expectEqualStrings("CustomFists", parsed.value.current_run.equipped_weapons[0].?.id);
    try testing.expectEqual(@as(f32, 15.5), parsed.value.current_run.equipped_weapons[0].?.light_attack.projectile_options.damage);
    try testing.expectEqualStrings("Heal", parsed.value.current_run.equipped_spells[0].?.id);
    try testing.expectEqual(@as(u32, 3), parsed.value.current_run.equipped_spells[0].?.level);
}
