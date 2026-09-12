const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;
const TIMER = 0.1;

const Stats = @import("../Stats.zig");
const Attack = @import("../player/Attack.zig");
const prefabs = @import("../../prefabs/prefabs.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const ReactiveAura = @import("ReactiveAura.zig");
const RoundSpawner = @import("../../global/spawner/RoundSpawner.zig");

const Self = @This();

stats: ?*Stats = null,
player_stats: ?*Stats = null,
player_attack: ?*Attack = null,
enemy_type: RoundSpawner.EnemyType = .melee,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    if (lm.getEntity(.{ .id = "player" })) |player| {
        self.player_stats = player.getComponent(Stats);
        self.player_attack = player.getComponent(Attack);
    }

    if (self.enemy_type == .melee) {
        if (std.mem.startsWith(u8, entity.id, "ranged")) {
            self.enemy_type = .ranged;
        } else if (std.mem.startsWith(u8, entity.id, "elite")) {
            self.enemy_type = .elite;
        }
    }
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);

    if (stats.current.health > 0) return;

    const enemy_position: lm.Vector2 = if (entity.getComponent(lm.Transform)) |transform|
        lm.vec3ToVec2(transform.position)
    else
        .init(0, 0);

    var listener_position = enemy_position;
    player_listener: {
        const player = lm.getEntity(.{ .id = "player" }) orelse break :player_listener;
        const player_transform = player.getComponent(lm.Transform) orelse break :player_listener;
        listener_position = lm.vec3ToVec2(player_transform.position);
    }

    SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", enemy_position, listener_position, 800.0, 0.75, 0.15);

    const orb_count = lm.random.intRangeAtMostBiased(u8, 1, 3);
    for (0..orb_count) |_| {
        const angle = lm.randFloat(f32, 0, std.math.pi * 2);
        const scatter_speed = lm.randFloat(f32, 100, 220);
        const initial_velocity = lm.Vec2(
            std.math.cos(angle) * scatter_speed,
            std.math.sin(angle) * scatter_speed,
        );
        const orb = try prefabs.items.ExperienceOrb(enemy_position, 1, initial_velocity);
        try lm.summoning.entity(orb);
    }

    if (self.player_attack) |player_attack| {
        player_attack.reduceSpellCooldowns(1.0);
    } else if (lm.getEntity(.{ .id = "player" })) |player| {
        if (player.getComponent(Attack)) |attack| {
            attack.reduceSpellCooldowns(1.0);
            self.player_attack = attack;
        }
    }

    if (entity.getComponent(ReactiveAura)) |reactive_aura| {
        reactive_aura.executeDeathRetaliation();
    }

    RoomManager.removeDefeatedEnemy(entity.uuid, enemy_position, self.enemy_type);

    lm.removeEntity(.{ .uuid = entity.uuid });
}
