const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("Attack.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const projectiles = @import("../../prefabs/Projectile.zig");
pub const HitInfo = projectiles.HitInfo;

/// Shaman "Grieving Wounds" reaction:
/// If the projectile hits the player, all currently active room enemies are healed
/// for the full amount of damage dealt.
pub fn shamanGrievingWoundsOnHit(hit: HitInfo) void {
    if (hit.damage_dealt <= 0) return;
    const scene = lm.activeScene() orelse return;

    const room_manager = RoomManager.get() orelse return;
    for (room_manager.spawner.active_enemies.items()) |enemy_uuid| {
        const enemy_entity = scene.getEntityByUuid(enemy_uuid) orelse continue;
        const stats = enemy_entity.getComponent(Stats) orelse continue;
        stats.current.health = @min(stats.max.health, stats.current.health + hit.damage_dealt);
    }
}

/// Queen "Bond of Life" early cancel reaction:
/// If any projectile hits the target, it pops Bond of Life and immediately cancels
/// the remainder of the caster's attack stream.
pub fn queenBondOfLifeEarlyCancel(hit: HitInfo) void {
    const caster_uuid = hit.caster_uuid orelse return;
    const scene = lm.activeScene() orelse return;

    const caster_entity = scene.getEntityByUuid(caster_uuid) orelse return;
    const attack = caster_entity.getComponent(Attack) orelse return;
    attack.cancelCurrentAction();
}
