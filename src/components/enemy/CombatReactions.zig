const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("Attack.zig");
const BondOfLife = @import("BondOfLife.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const projectiles = @import("../../prefabs/Projectile.zig");
pub const HitInfo = projectiles.HitInfo;

pub fn shamanGrievingWoundsOnHit(hit: HitInfo) void {
    if (hit.damage_dealt <= 0) return;

    const room_manager = RoomManager.get() orelse return;
    for (room_manager.spawner.active_enemies.items()) |enemy_uuid| {
        const enemy_entity = lm.getEntity(.{ .uuid = enemy_uuid }) orelse continue;
        const stats = enemy_entity.getComponent(Stats) orelse continue;
        stats.current.health = @min(stats.max.health, stats.current.health + hit.damage_dealt);
    }
}

pub fn queenBondOfLifeEarlyCancel(hit: HitInfo) void {
    _ = hit;
    _ = BondOfLife.instance.popOnHit(null);
}

pub fn queenBondOfLifeSniperOnHit(hit: HitInfo) void {
    _ = hit;
    _ = BondOfLife.instance.popOnHit(2.0);
}

pub fn queenBondOfLifeOnMiss() void {
    _ = BondOfLife.instance.expireOnMiss();
}
