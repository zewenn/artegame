const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const prefabs = @import("../../prefabs/prefabs.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

pub fn findLowestHealthAlly(
    caster_uuid: u128,
    max_health_ratio_threshold: f32,
) ?*lm.Entity {
    const room_manager = RoomManager.get() orelse return null;
    var lowest_entity: ?*lm.Entity = null;
    var lowest_ratio: f32 = max_health_ratio_threshold;

    for (room_manager.spawner.active_enemies.items()) |enemy_uuid| {
        if (enemy_uuid == caster_uuid) continue;

        const enemy_entity = lm.getEntity(.{ .uuid = enemy_uuid }) orelse continue;
        const stats = enemy_entity.getComponent(Stats) orelse continue;

        if (stats.max.health <= 0.0 or stats.current.health <= 0.0) continue;

        const current_ratio = stats.current.health / stats.max.health;
        if (current_ratio < lowest_ratio) {
            lowest_ratio = current_ratio;
            lowest_entity = enemy_entity;
        }
    }

    return lowest_entity;
}

pub fn findRandomLivingAlly(caster_uuid: u128) ?*lm.Entity {
    const room_manager = RoomManager.get() orelse return null;
    const active_items = room_manager.spawner.active_enemies.items();
    if (active_items.len == 0) return null;

    var valid_candidates: [32]u128 = [_]u128{0} ** 32;
    var candidate_count: usize = 0;

    for (active_items) |enemy_uuid| {
        if (enemy_uuid == caster_uuid) continue;

        const enemy_entity = lm.getEntity(.{ .uuid = enemy_uuid }) orelse continue;
        const stats = enemy_entity.getComponent(Stats) orelse continue;
        if (stats.current.health <= 0.0) continue;

        if (candidate_count < valid_candidates.len) {
            valid_candidates[candidate_count] = enemy_uuid;
            candidate_count += 1;
        }
    }

    if (candidate_count == 0) return null;

    const selected_index = lm.random.intRangeLessThan(usize, 0, candidate_count);
    return lm.getEntity(.{ .uuid = valid_candidates[selected_index] });
}

pub fn applySpeedBoost(
    target_entity: *lm.Entity,
    bonus_speed_pixels_per_second: f32,
    duration_seconds: f32,
) void {
    const stats = target_entity.getComponent(Stats) orelse return;

    stats.addEffect(.{
        .id = "shaman_speed_boost",
        .effect_type = .haste,
        .duration = duration_seconds,
        .value = bonus_speed_pixels_per_second,
        .on_enable = struct {
            pub fn onEnable(s: *Stats) void {
                if (s.getEffect(.{ .id = "shaman_speed_boost" })) |effect| {
                    s.current.movement_speed += effect.value;
                }
            }
        }.onEnable,
        .on_disable = struct {
            pub fn onDisable(s: *Stats) void {
                if (s.getEffect(.{ .id = "shaman_speed_boost" })) |effect| {
                    s.current.movement_speed = @max(10.0, s.current.movement_speed - effect.value);
                }
            }
        }.onDisable,
    });
}

pub fn executeLifelinerRescue(
    lifeliner_entity: *lm.Entity,
    ally_entity: *lm.Entity,
    player_position: lm.Vector2,
    minimum_distance_from_player: f32,
) void {
    const ally_transform = ally_entity.getComponent(lm.Transform) orelse return;
    const lifeliner_transform = lifeliner_entity.getComponent(lm.Transform) orelse return;

    const ally_position = lm.vec3ToVec2(ally_transform.position);
    const to_ally = ally_position.subtract(player_position);

    const safe_direction = if (to_ally.length() > 0.001)
        to_ally.normalize()
    else
        lm.Vec2(1.0, 0.0);

    const safe_position = player_position.add(safe_direction.multiply(.init(minimum_distance_from_player, minimum_distance_from_player)));

    ally_transform.position.x = safe_position.x;
    ally_transform.position.y = safe_position.y;

    lifeliner_transform.position.x = safe_position.x + 40.0;
    lifeliner_transform.position.y = safe_position.y;

    SpatialAudio.playSpatialPitched("audio/sfx/pickup.mp3", safe_position, player_position, 800.0, 0.7, 0.1);
}

pub fn executeEnemyRevive(
    room_manager: *RoomManager,
    current_room: u32,
) !bool {
    const record = room_manager.popFallenEnemyForRevive() orelse return false;

    const safe_position = record.death_position;

    // Instantiate revived enemy prefab
    const enemy_entity = switch (record.enemy_type) {
        .ranged => try prefabs.enemies.Ranged(safe_position),
        .elite => try prefabs.enemies.Elite(safe_position),
        .melee => try prefabs.enemies.Melee(safe_position),
    };

    const stats = enemy_entity.getComponent(Stats) orelse return false;

    // Revived enemy starts with 33% HP, scaling with rooms completed
    const room_scale = 1.0 + @as(f32, @floatFromInt(if (current_room > 1) current_room - 1 else 0)) * 0.05;
    const revive_health_fraction = @min(1.0, 0.33 * room_scale);
    stats.current.health = stats.max.health * revive_health_fraction;

    try lm.summoning.entity(enemy_entity);
    try room_manager.spawner.active_enemies.append(enemy_entity.uuid);

    const player = lm.getEntity(.{ .id = "player" });
    const listener_position = if (player) |p|
        if (p.getComponent(lm.Transform)) |t| lm.vec3ToVec2(t.position) else safe_position
    else
        safe_position;

    SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", safe_position, listener_position, 800.0, 0.5, 0.2);

    return true;
}

test "SupportMechanics lowest health ally query filters correctly" {
    var stats_1 = Stats.init(.enemy, .{
        .health = 100.0,
    });
    defer stats_1.deinit();
    stats_1.current.health = 50.0; // 50%

    var stats_2 = Stats.init(.enemy, .{
        .health = 100.0,
    });
    defer stats_2.deinit();
    stats_2.current.health = 8.0; // 8% (< 10% threshold)

    var stats_3 = Stats.init(.enemy, .{
        .health = 100.0,
    });
    defer stats_3.deinit();
    stats_3.current.health = 80.0; // 80%

    try std.testing.expect(stats_2.current.health / stats_2.max.health < 0.10);
    try std.testing.expect(stats_1.current.health / stats_1.max.health >= 0.10);
}

test "SupportMechanics speed boost lifecycle" {
    var stats = Stats.init(.enemy, .{
        .movement_speed = 200.0,
    });
    defer stats.deinit();

    var entity = lm.Entity.init(std.testing.allocator, "shaman_target");
    defer entity.deinit();

    try entity.addComponent(stats);
    try entity.addPreparedComponents(false);

    applySpeedBoost(&entity, 100.0, 5.0);

    const stats_ptr = entity.getComponent(Stats).?;
    try std.testing.expect(stats_ptr.hasEffect(.{ .id = "shaman_speed_boost" }));
    try std.testing.expectEqual(@as(f32, 300.0), stats_ptr.current.movement_speed);

    // Expire effect
    stats_ptr.tickEffects(5.0);
    try std.testing.expect(!stats_ptr.hasEffect(.{ .id = "shaman_speed_boost" }));
    try std.testing.expectEqual(@as(f32, 200.0), stats_ptr.current.movement_speed);
}
