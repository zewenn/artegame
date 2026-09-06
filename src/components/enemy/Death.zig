const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;
const TIMER = 0.1;

const Stats = @import("../Stats.zig");
const Attack = @import("../player/Attack.zig");
const prefabs = @import("../../prefabs/prefabs.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");
const DemoMap = @import("../../global/DemoMap.zig");

const Self = @This();

stats: ?*Stats = null,
player_stats: ?*Stats = null,
player_attack: ?*Attack = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    if (lm.activeScene()) |scene| {
        if (scene.getEntityById("player")) |player| {
            self.player_stats = player.getComponent(Stats);
            self.player_attack = player.getComponent(Attack);
        }
    }
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);

    if (stats.current.health > 0) return;

    const enemy_pos: lm.Vector2 = if (entity.getComponent(lm.Transform)) |t|
        lm.vec3ToVec2(t.position)
    else
        .init(0, 0);

    var listener_pos = enemy_pos;
    player_listner: {
        const player = lm.getEntity(.{ .id = "player" }) orelse break :player_listner;
        const player_transform = player.getComponent(lm.Transform) orelse break :player_listner;
        listener_pos = lm.vec3ToVec2(player_transform.position);
    }

    SpatialAudio.playSpatialPitched("audio/boom.wav", enemy_pos, listener_pos, 800.0, 0.75, 0.15);

    const orb_count = lm.random.intRangeAtMostBiased(u8, 1, 3);
    for (0..orb_count) |_| {
        const angle = lm.randFloat(f32, 0, std.math.pi * 2);
        const scatter_speed = lm.randFloat(f32, 100, 220);
        const initial_vel = lm.Vec2(
            std.math.cos(angle) * scatter_speed,
            std.math.sin(angle) * scatter_speed,
        );
        const orb = try prefabs.items.ExperienceOrb(enemy_pos, 1, initial_vel);
        try lm.summoning.entity(orb);
    }

    if (self.player_attack) |player_attack| {
        player_attack.reduceSpellCooldowns(1.0);
    } else if (lm.activeScene()) |scene| {
        if (scene.getEntityById("player")) |player| {
            if (player.getComponent(Attack)) |attack| {
                attack.reduceSpellCooldowns(1.0);
                self.player_attack = attack;
            }
        }
    }

    DemoMap.removeDefeatedEnemy(entity.uuid);

    lm.removeEntity(.{ .uuid = entity.uuid });
}
