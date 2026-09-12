const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("Attack.zig");
const BondOfLife = @import("BondOfLife.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const projectiles = @import("../../prefabs/Projectile.zig");
pub const HitInfo = projectiles.HitInfo;

/// Shaman "Grieving Wounds" reaction:
/// If the projectile hits the player, all currently active room enemies are healed
/// for the full amount of damage dealt.
pub fn shamanGrievingWoundsOnHit(hit: HitInfo) void {
    if (hit.damage_dealt <= 0) return;

    const room_manager = RoomManager.get() orelse return;
    for (room_manager.spawner.active_enemies.items()) |enemy_uuid| {
        const enemy_entity = lm.getEntity(.{ .uuid = enemy_uuid }) orelse continue;
        const stats = enemy_entity.getComponent(Stats) orelse continue;
        stats.current.health = @min(stats.max.health, stats.current.health + hit.damage_dealt);
    }
}

/// Queen "Bond of Life" early cancel reaction:
/// If any projectile hits the target, it pops Bond of Life, deals true damage, heals
/// the caster, and immediately cancels the remainder of the caster's attack stream.
pub fn queenBondOfLifeEarlyCancel(hit: HitInfo) void {
    _ = hit;
    _ = BondOfLife.instance.popOnHit(null);
}

/// Queen "Bond of Life" pop with stun (sniper variant)
pub fn queenBondOfLifeSniperOnHit(hit: HitInfo) void {
    _ = hit;
    _ = BondOfLife.instance.popOnHit(2.0);
}

/// Queen "Bond of Life" miss/expiration:
/// Rebounds true damage to the Queen when projectiles are completely avoided.
pub fn queenBondOfLifeOnMiss() void {
    _ = BondOfLife.instance.expireOnMiss();
}
