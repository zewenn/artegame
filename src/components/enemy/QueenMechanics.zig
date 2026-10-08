const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");
const Attack = @import("Attack.zig");
const BondOfLife = @import("BondOfLife.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

const Self = @This();

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,
attack: ?*Attack = null,
player_transform: ?*lm.Transform = null,

dash_charge_active: bool = false,
dash_charge_timer_seconds: f32 = 0.0,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.dashing = entity.getComponent(Dashing);
    self.attack = entity.getComponent(Attack);
}

pub fn Start(self: *Self) !void {
    const scene = lm.activeScene() orelse return;
    const player = scene.getEntityById("player") orelse return;
    self.player_transform = player.getComponent(lm.Transform);
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    if (stats.current.health <= 0.0) {
        BondOfLife.instance.reset();
        return;
    }

    const delta_seconds = lm.time.deltaTime();
    BondOfLife.instance.update(delta_seconds);

    self.updateDashCharge(delta_seconds);
}

pub fn End(self: *Self) void {
    _ = self;
    BondOfLife.instance.reset();
}

fn updateDashCharge(self: *Self, delta_seconds: f32) void {
    if (!self.dash_charge_active) return;

    self.dash_charge_timer_seconds -= delta_seconds;
    if (self.dash_charge_timer_seconds <= 0.0) {
        self.dash_charge_active = false;
    }
}

pub fn triggerDashTowardsPlayer(self: *Self, dash_speed_pixels_per_second: f32, duration_seconds: f32) void {
    const transform = self.transform orelse return;
    const player_transform = self.player_transform orelse return;
    const dashing = self.dashing orelse return;

    const queen_position = lm.vec3ToVec2(transform.position);
    const player_position = lm.vec3ToVec2(player_transform.position);
    const to_player = player_position.subtract(queen_position);

    if (to_player.length() < 0.01) return;

    const dash_direction = to_player.normalize();
    const velocity = dash_direction.multiply(.init(dash_speed_pixels_per_second, dash_speed_pixels_per_second));

    dashing.applyEx(velocity, duration_seconds, false);
    self.dash_charge_active = true;
    self.dash_charge_timer_seconds = duration_seconds;

    SpatialAudio.playSpatialPitched("audio/sfx/dash.wav", queen_position, player_position, 800.0, 0.9, 0.1);
}
