const lm = @import("loom");
const std = @import("std");

const prefabs = @import("../prefabs/prefabs.zig");
const Self = @This();
const player_components = @import("../components/player/export.zig");

const RoundState = enum {
    replenish,
    combat,
};

player: ?*lm.Entity = null,
player_objectives: ?*player_components.Objectives = null,
enemies: lm.List(u128) = undefined,
state: RoundState = .replenish,
round: u32 = 0,

fn newRound(self: *Self) !void {
    std.debug.assert(self.state == .replenish);

    self.state = .combat;
    self.round += 1;

    for (0..self.round) |_| {
        const enemy = try prefabs.enemies.Basic(.init(lm.randFloat(f32, -256, 256), lm.randFloat(f32, -256, 256)));
        try self.enemies.append(enemy.uuid);

        try lm.summon(&.{.{ .entity = enemy }});
    }
}

pub fn Awake(self: *Self) !void {
    self.enemies = .init(lm.allocators.scene());

    try lm.summon(&.{
        .{ .entity = try prefabs.Player(.init(0, 0)) },
        .{ .entity = try prefabs.Background(20, 10) },
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
    }

    const objectives = self.player_objectives orelse return;

    if (lm.keyboard.getKeyDown(.f) and self.state == .replenish) {
        try self.newRound();
        objectives.tracking = objectives.addObjective(.init("FIGHT TILL DEATH", "Kill all enemies")) catch |err| {
            std.log.err("{any}", .{err});
            return;
        };

        return;
    }

    if (self.state == .combat and self.enemies.len() == 0) {
        self.state = .replenish;
        objectives.tracking = try objectives.addObjective(.init("Replenish", "Press [F] to continue"));
    }

    const len = self.enemies.len();
    for (1..len + 1) |j| {
        const index = len - j;
        const uuid = self.enemies.items()[index];

        if (lm.activeScene().?.isEntityAliveUuid(uuid)) continue;

        _ = self.enemies.swapRemove(index);
    }
}

pub fn End(self: *Self) !void {
    self.enemies.clearAndFree();
}
