const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("../player/Attack.zig");
const prefabs = @import("../../prefabs/prefabs.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const ReactiveAura = @import("ReactiveAura.zig");
const EnemyType = @import("EnemyType.zig").EnemyType;

const Self = @This();

stats: ?*Stats = null,
player_attack: ?*Attack = null,
enemy_type: EnemyType = .melee,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    if (lm.getEntity(.{ .id = "player" })) |player| {
        self.player_attack = player.getComponent(Attack);
    }
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    if (stats.current.health > 0) return;

    const enemy_position = getEntityPosition(entity);
    const listener_position = getPlayerListenerPosition(enemy_position);

    SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", enemy_position, listener_position, 800.0, 0.75, 0.15);

    try self.spawnExperienceOrbs(enemy_position);
    self.reducePlayerSpellCooldowns();

    if (entity.getComponent(ReactiveAura)) |reactive_aura| {
        reactive_aura.executeDeathRetaliation();
    }

    RoomManager.removeDefeatedEnemy(entity.uuid, enemy_position, self.enemy_type);
    lm.removeEntity(.{ .uuid = entity.uuid });
}

fn spawnExperienceOrbs(self: *const Self, enemy_position: lm.Vector2) !void {
    const orb_range = self.enemy_type.orbDropRange();
    const orb_count = lm.random.intRangeAtMostBiased(u8, orb_range.min_count, orb_range.max_count);

    for (0..orb_count) |_| {
        const angle_radians = lm.randFloat(f32, 0, std.math.pi * 2);
        const scatter_speed_pixels_per_second = lm.randFloat(f32, 100, 220);
        const initial_velocity = lm.Vec2(
            std.math.cos(angle_radians) * scatter_speed_pixels_per_second,
            std.math.sin(angle_radians) * scatter_speed_pixels_per_second,
        );
        const orb = try prefabs.items.ExperienceOrb(enemy_position, 1, initial_velocity);
        try lm.summoning.entity(orb);
    }
}

fn reducePlayerSpellCooldowns(self: *Self) void {
    if (self.player_attack) |player_attack| {
        player_attack.reduceSpellCooldowns(1.0);
        return;
    }

    const player = lm.getEntity(.{ .id = "player" }) orelse return;
    const attack = player.getComponent(Attack) orelse return;
    attack.reduceSpellCooldowns(1.0);
    self.player_attack = attack;
}

fn getEntityPosition(entity: *lm.Entity) lm.Vector2 {
    const transform = entity.getComponent(lm.Transform) orelse return .init(0, 0);
    return lm.vec3ToVec2(transform.position);
}

fn getPlayerListenerPosition(fallback_position: lm.Vector2) lm.Vector2 {
    const player = lm.getEntity(.{ .id = "player" }) orelse return fallback_position;
    const player_transform = player.getComponent(lm.Transform) orelse return fallback_position;
    return lm.vec3ToVec2(player_transform.position);
}
