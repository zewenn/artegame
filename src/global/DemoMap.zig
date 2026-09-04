const lm = @import("loom");
const std = @import("std");

const prefabs = @import("../prefabs/prefabs.zig");
const Self = @This();
const player_components = @import("../components/player/export.zig");

pub const RoundState = enum {
    replenish,
    combat,
};

pub var state: RoundState = .replenish;
var instance: ?*Self = null;

pub fn isReplenish() bool {
    return state == .replenish;
}

pub fn startRound() !void {
    const self = instance orelse return;
    if (state != .replenish) return;

    state = .combat;
    self.round += 1;

    if (self.player_objectives) |objectives| {
        objectives.tracking = try objectives.addObjective(.init("FIGHT TILL DEATH", "Kill all enemies"));
    }

    for (0..self.round) |_| {
        const enemy = try prefabs.enemies.Basic(.init(lm.randFloat(f32, -256, 256), lm.randFloat(f32, -256, 256)));
        try self.enemies.append(enemy.uuid);
        try lm.summoning.entity(enemy);
    }
}

fn isEnemyAlive(scene: *lm.Scene, uuid: u128) bool {
    for (scene.entities.items()) |entity| {
        if (entity.uuid == uuid) return true;
    }
    for (scene.new_entities.items()) |entity| {
        if (entity.uuid == uuid) return true;
    }
    return false;
}

player: ?*lm.Entity = null,
player_objectives: ?*player_components.Objectives = null,
enemies: lm.List(u128) = undefined,
round: u32 = 0,


pub fn Awake(self: *Self) !void {
    instance = self;
    state = .replenish;
    self.enemies = .init(lm.allocators.scene());

    try lm.summoning.entities(&.{
        try prefabs.Player(.init(0, 0)),
        try prefabs.Background(20, 10),
        try prefabs.Shrine(.init(-96, -200)),
        try prefabs.RoundActivator(.init(96, -200)),
    });
}

pub fn Update(self: *Self, scene: *lm.Scene) !void {
    if (self.player == null or self.player_objectives == null) {
        const player = scene.getEntityById("player") orelse {
            self.player = null;
            self.player_objectives = null;
            return;
        };

        self.player = player;
        self.player_objectives = player.getComponent(player_components.Objectives);
        if (self.player_objectives) |objectives| {
            objectives.tracking = try objectives.addObjective(.init("Replenish", "Visit Boon Shrine to upgrade | Activate Round Shrine to fight"));
        }
    }

    const len = self.enemies.len();
    for (1..len + 1) |j| {
        const index = len - j;
        const uuid = self.enemies.items()[index];

        if (isEnemyAlive(scene, uuid)) continue;

        _ = self.enemies.swapRemove(index);
    }

    if (state == .combat and self.enemies.len() == 0) {
        state = .replenish;
        if (self.player_objectives) |objectives| {
            objectives.tracking = try objectives.addObjective(.init("Replenish", "Visit Boon Shrine to upgrade | Activate Round Shrine to fight"));
        }
    }
}

pub fn End(self: *Self) !void {
    instance = null;
    self.enemies.clearAndFree();
}
