const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Ability = @import("Ability.zig");
const ProjectileProfile = Ability.ProjectileProfile;
const Animation = @import("Animation.zig");
const projectiles = @import("../../prefabs/Projectile.zig");
const ProjectileOptions = projectiles.Options;

const Self = @This();

pub const ActionState = enum {
    idle,
    winding_up,
    channeling,
    firing_waves,
    winding_down,
};

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
player_transform: ?*lm.Transform = null,
player_stats: ?*Stats = null,
animator: ?*lm.Animator = null,

abilities_template: []const Ability = &.{},
abilities: ?lm.List(Ability) = null,
fallback_ability: ?Ability = null,

action_state: ActionState = .idle,
active_ability_index: ?usize = null,
is_fallback_active: bool = false,
action_timer: f32 = 0,

channel_timer: f32 = 0,
channel_fire_timer: f32 = 0,
channel_current_angle: f32 = 0,
channel_rotation_speed: f32 = 0,
channel_fire_interval: f32 = 0,

waves_remaining: u32 = 0,
current_wave_index: u32 = 0,
wave_interval_timer: f32 = 0,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    if (self.abilities == null) {
        var list = lm.List(Ability).init(lm.allocators.scene());
        for (self.abilities_template) |template| {
            var ability = template;
            ability.cooldown_remaining = 0;
            try list.append(ability);
        }
        self.abilities = list;
    }

    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.animator = entity.getComponent(lm.Animator);
}

pub fn Start(self: *Self) !void {
    if (lm.activeScene()) |scene| {
        if (scene.getEntityById("player")) |player| {
            self.player_transform = player.getComponent(lm.Transform);
            self.player_stats = player.getComponent(Stats);
        }
    }
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    if (stats.isStunned() or stats.isSleeping()) {
        self.cancelCurrentAction();
        return;
    }

    const dt = lm.time.deltaTime();

    if (self.action_state == .winding_up) {
        self.action_timer -= dt;

        var finished = self.action_timer <= 0;
        calculate_finished: {
            if (finished or self.animator == null) break :calculate_finished;
            const active_ability = self.getActiveAbilityPtr() orelse break :calculate_finished;
            const anim_name = active_ability.windup_animation orelse break :calculate_finished;
            finished = !self.animator.?.isPlaying(anim_name);
        }

        if (!finished) return;

        self.dispatchAbilityExecution(entity, transform, stats, player_transform);
        return;
    }

    if (self.action_state == .channeling) {
        self.channel_timer -= dt;
        self.channel_fire_timer -= dt;
        self.channel_current_angle += self.channel_rotation_speed * dt;

        if (self.channel_fire_timer <= 0) {
            if (self.getActiveAbilityPtr()) |ability| {
                ability.fireProjectileWave(
                    entity,
                    transform,
                    stats,
                    player_transform,
                    self.player_stats,
                    0,
                    self.channel_current_angle,
                ) catch |err| {
                    std.log.err("Failed channeled barrage burst: {any}", .{err});
                };
            }
            self.channel_fire_timer = self.channel_fire_interval;
        }

        if (self.channel_timer <= 0) {
            if (self.getActiveAbilityPtr()) |ability| {
                ability.cooldown_remaining = ability.cooldown;
                self.finishActionAfterCast(ability);
            } else {
                self.cancelCurrentAction();
            }
        }
        return;
    }

    if (self.action_state == .firing_waves) {
        self.wave_interval_timer -= dt;

        if (self.wave_interval_timer <= 0 and self.waves_remaining > 0) {
            if (self.getActiveAbilityPtr()) |ability| {
                ability.fireProjectileWave(
                    entity,
                    transform,
                    stats,
                    player_transform,
                    self.player_stats,
                    self.current_wave_index,
                    null,
                ) catch |err| {
                    std.log.err("Failed wave {d} burst: {any}", .{ self.current_wave_index, err });
                };
                self.waves_remaining -= 1;
                self.current_wave_index += 1;
                const wave_int = if (ability.projectile_profile) |p| p.wave_interval else 0.15;
                self.wave_interval_timer = wave_int;
            } else {
                self.cancelCurrentAction();
                return;
            }
        }

        if (self.waves_remaining == 0) {
            if (self.getActiveAbilityPtr()) |ability| {
                ability.cooldown_remaining = ability.cooldown;
                self.finishActionAfterCast(ability);
            } else {
                self.cancelCurrentAction();
            }
        }
        return;
    }

    if (self.action_state == .winding_down) {
        self.action_timer -= dt;

        var finished = self.action_timer <= 0;
        calculate_finished: {
            if (finished or self.animator == null) break :calculate_finished;
            const active_ability = self.getActiveAbilityPtr() orelse break :calculate_finished;
            const anim_name = active_ability.winddown_animation orelse break :calculate_finished;
            finished = !self.animator.?.isPlaying(anim_name);
        }

        if (!finished) return;

        self.action_state = .idle;
        self.active_ability_index = null;
        self.is_fallback_active = false;
        self.action_timer = 0;

        return;
    }

    if (self.abilities) |*abilities| {
        for (abilities.items()) |*ability| {
            ability.updateCooldown(dt);
        }
    }
    if (self.fallback_ability) |*fallback| {
        fallback.updateCooldown(dt);
    }

    const distance = std.math.hypot(
        transform.position.x - player_transform.position.x,
        transform.position.y - player_transform.position.y,
    );

    if (distance > stats.current.aggro_range) return;

    const player_stats_val = if (self.player_stats) |ps| ps.* else null;

    if (self.abilities) |*abilities| {
        for (abilities.items(), 0..) |*ability, index| {
            if (!ability.canExecute(stats.*, player_stats_val, distance)) continue;

            self.startAbility(ability, index, false, entity, transform, stats, player_transform);
            return;
        }
    }

    if (self.fallback_ability) |*fallback| {
        if (fallback.canExecute(stats.*, player_stats_val, distance)) {
            self.startAbility(fallback, null, true, entity, transform, stats, player_transform);
        }
    }
}

pub fn End(self: *Self) void {
    if (self.abilities) |*list| {
        list.deinit();
        self.abilities = null;
    }
}

pub fn init(abilities_template: []const Ability, fallback: ?Ability) Self {
    return Self{
        .abilities_template = abilities_template,
        .fallback_ability = fallback,
    };
}

pub fn fromProjectileOptions(options: ProjectileOptions) Self {
    return Self{
        .fallback_ability = Ability{
            .id = "fallback_shot",
            .execution_type = .projectile,
            .cooldown = 1.0,
            .projectile_profile = ProjectileProfile{
                .speed = options.speed,
                .lifetime = options.lifetime,
                .damage = options.damage,
                .damage_type = options.damage_type,
                .size = options.size,
                .passtrough = options.passtrough,
                .onhit_effect = options.onhit_effect,
                .onhit_duration = options.onhit_duration,
                .onhit_strength = options.onhit_strength,
                .knockback_strength = options.knockback_strength,
                .knockback_duration = options.knockback_duration,
                .sfx_path = "audio/sfx/punch.mp3",
            },
        },
    };
}

pub fn isActing(self: *const Self) bool {
    return self.action_state != .idle;
}

pub fn cancelCurrentAction(self: *Self) void {
    if (self.getActiveAbilityPtr()) |ability| {
        if (self.action_state == .channeling or self.action_state == .firing_waves or self.action_state == .winding_up) {
            ability.cooldown_remaining = ability.cooldown;
        }
    }
    self.action_state = .idle;
    self.active_ability_index = null;
    self.is_fallback_active = false;
    self.action_timer = 0;
    self.channel_timer = 0;
    self.channel_fire_timer = 0;
    self.channel_current_angle = 0;
    self.channel_rotation_speed = 0;
    self.channel_fire_interval = 0;
    self.waves_remaining = 0;
    self.current_wave_index = 0;
    self.wave_interval_timer = 0;
}

fn startAbility(
    self: *Self,
    ability: *Ability,
    index: ?usize,
    is_fallback: bool,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
) void {
    self.active_ability_index = index;
    self.is_fallback_active = is_fallback;

    if (ability.windup_animation) |windup_anim| {
        self.action_state = .winding_up;
        var duration: f32 = 0.2;
        if (self.animator) |animator| {
            const anim_dur = Animation.getAnimationDuration(animator, windup_anim);
            if (anim_dur > 0) duration = anim_dur;
            animator.play(windup_anim) catch {};
        }
        self.action_timer = duration;
        return;
    }

    self.dispatchAbilityExecution(entity, transform, stats, player_transform);
}

fn dispatchAbilityExecution(
    self: *Self,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
) void {
    const ability = self.getActiveAbilityPtr() orelse {
        self.cancelCurrentAction();
        return;
    };

    if (ability.execution_type == .projectile and ability.projectile_profile != null) {
        const profile = ability.projectile_profile.?;

        if (profile.is_channeled) {
            self.action_state = .channeling;
            self.channel_timer = profile.channel_duration;
            self.channel_rotation_speed = profile.channel_rotation_speed;
            self.channel_fire_interval = profile.channel_fire_interval;
            self.channel_current_angle = profile.initial_angle;

            ability.fireProjectileWave(
                entity,
                transform,
                stats,
                player_transform,
                self.player_stats,
                0,
                self.channel_current_angle,
            ) catch |err| {
                std.log.err("Failed initial channel burst {s}: {any}", .{ ability.id, err });
            };
            self.channel_fire_timer = self.channel_fire_interval;

            if (self.animator) |animator| {
                if (ability.release_animation) |rel_anim| {
                    animator.play(rel_anim) catch {};
                }
            }
            return;
        }

        if (profile.wave_count > 1) {
            self.action_state = .firing_waves;
            self.waves_remaining = profile.wave_count - 1;
            self.current_wave_index = 1;
            self.wave_interval_timer = profile.wave_interval;

            ability.fireProjectileWave(
                entity,
                transform,
                stats,
                player_transform,
                self.player_stats,
                0,
                null,
            ) catch |err| {
                std.log.err("Failed initial wave 0 for {s}: {any}", .{ ability.id, err });
            };

            if (self.animator) |animator| {
                if (ability.release_animation) |rel_anim| {
                    animator.play(rel_anim) catch {};
                }
            }
            return;
        }
    }

    ability.execute(
        entity,
        transform,
        stats,
        player_transform,
        self.player_stats,
    ) catch |err| {
        std.log.err("Failed to execute ability {s}: {any}", .{ ability.id, err });
    };

    ability.cooldown_remaining = ability.cooldown;
    self.finishActionAfterCast(ability);
}

fn finishActionAfterCast(self: *Self, ability: *Ability) void {
    const animator = self.animator orelse {
        self.action_state = .idle;
        self.active_ability_index = null;
        self.is_fallback_active = false;
        self.action_timer = 0;
        return;
    };

    if (ability.release_animation) |rel_anim| {
        animator.play(rel_anim) catch {};
    }

    if (ability.winddown_animation) |wd_anim| {
        self.action_state = .winding_down;
        var duration = Animation.getAnimationDuration(animator, wd_anim);
        if (duration <= 0) duration = 0.15;
        
        self.action_timer = duration;
        animator.play(wd_anim) catch {};
        return;
    }

    self.action_state = .idle;
    self.active_ability_index = null;
    self.is_fallback_active = false;
    self.action_timer = 0;
}

fn getActiveAbilityPtr(self: *Self) ?*Ability {
    if (self.is_fallback_active) return &(self.fallback_ability orelse return null);

    const abilities = &(self.abilities orelse return null);
    const index = self.active_ability_index orelse return null;
    const items = abilities.items();
    if (index >= items.len) return null;
    return &items[index];
}

test "Enemy Attack with lm.List(Ability)" {
    const template = [_]Ability{
        .{
            .id = "slash",
            .execution_type = .projectile,
            .cooldown = 2.0,
            .projectile_profile = .{},
        },
        .{
            .id = "spin",
            .execution_type = .projectile,
            .cooldown = 5.0,
            .projectile_profile = .{},
        },
    };

    var attack = Self.init(&template, null);
    try std.testing.expectEqual(@as(usize, 2), attack.abilities_template.len);
    try std.testing.expect(attack.abilities == null);

    var list = lm.List(Ability).init(std.testing.allocator);
    for (attack.abilities_template) |t| {
        var ab = t;
        ab.cooldown_remaining = 0;
        try list.append(ab);
    }
    attack.abilities = list;
    defer attack.End();

    try std.testing.expectEqual(@as(usize, 2), attack.abilities.?.items().len);

    attack.active_ability_index = 0;
    const active_0 = attack.getActiveAbilityPtr();
    try std.testing.expect(active_0 != null);
    try std.testing.expectEqualStrings("slash", active_0.?.id);

    active_0.?.cooldown_remaining = 2.0;

    attack.active_ability_index = 1;
    const active_1 = attack.getActiveAbilityPtr();
    try std.testing.expect(active_1 != null);
    try std.testing.expectEqualStrings("spin", active_1.?.id);

    attack.active_ability_index = 2;
    try std.testing.expect(attack.getActiveAbilityPtr() == null);
    attack.active_ability_index = 999;
    try std.testing.expect(attack.getActiveAbilityPtr() == null);

    for (attack.abilities.?.items()) |*ab| {
        ab.updateCooldown(0.5);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), attack.abilities.?.items()[0].cooldown_remaining, 0.001);
}

test "Enemy Attack dynamic channeled barrage rotation angle progression (Bishop dynamic sweep)" {
    const bishop_sweep = [_]Ability{
        .{
            .id = "bishop_sweep",
            .execution_type = .projectile,
            .cooldown = 4.0,
            .projectile_profile = .{
                .is_channeled = true,
                .channel_duration = 5.0,
                .channel_fire_interval = 0.05,
                .channel_rotation_speed = 72.0,
                .initial_angle = 0,
                .spread_angles = &.{ 0, 90, -90, 180 },
            },
        },
    };

    var attack = Self.init(&bishop_sweep, null);
    var list = lm.List(Ability).init(std.testing.allocator);
    try list.append(bishop_sweep[0]);
    attack.abilities = list;
    defer attack.End();

    attack.active_ability_index = 0;
    attack.action_state = .channeling;
    attack.channel_timer = 5.0;
    attack.channel_fire_timer = 0.05;
    attack.channel_current_angle = 0;
    attack.channel_rotation_speed = 72.0;
    attack.channel_fire_interval = 0.05;

    try std.testing.expect(attack.isActing());

    // Simulate 1.0 second elapsed: 72 deg/s * 1.0s = 72 degrees
    const delta_time_1_seconds: f32 = 1.0;
    attack.channel_timer -= delta_time_1_seconds;
    attack.channel_current_angle += attack.channel_rotation_speed * delta_time_1_seconds;

    try std.testing.expectApproxEqAbs(@as(f32, 4.0), attack.channel_timer, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 72.0), attack.channel_current_angle, 0.001);

    // Simulate another 1.5 seconds: 72 + 1.5 * 72 = 180 degrees
    const delta_time_2_seconds: f32 = 1.5;
    attack.channel_timer -= delta_time_2_seconds;
    attack.channel_current_angle += attack.channel_rotation_speed * delta_time_2_seconds;

    try std.testing.expectApproxEqAbs(@as(f32, 2.5), attack.channel_timer, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 180.0), attack.channel_current_angle, 0.001);
}

test "Enemy Attack multi-wave volley staggered firing" {
    const multi_wave = [_]Ability{
        .{
            .id = "tank_burst",
            .execution_type = .projectile,
            .cooldown = 3.0,
            .projectile_profile = .{
                .wave_count = 3,
                .wave_interval = 0.2,
                .wave_angle_offset = 15.0,
            },
        },
    };

    var attack = Self.init(&multi_wave, null);
    var list = lm.List(Ability).init(std.testing.allocator);
    try list.append(multi_wave[0]);
    attack.abilities = list;
    defer attack.End();

    attack.active_ability_index = 0;
    attack.action_state = .firing_waves;
    attack.waves_remaining = 2; // wave 0 already fired
    attack.current_wave_index = 1;
    attack.wave_interval_timer = 0.2;

    try std.testing.expect(attack.isActing());

    // Advance interval to trigger wave 1
    attack.wave_interval_timer -= 0.2;
    try std.testing.expect(attack.wave_interval_timer <= 0);

    attack.waves_remaining -= 1;
    attack.current_wave_index += 1;
    attack.wave_interval_timer = 0.2;

    try std.testing.expectEqual(@as(u32, 1), attack.waves_remaining);
    try std.testing.expectEqual(@as(u32, 2), attack.current_wave_index);

    // Advance interval to trigger wave 2 (last wave)
    attack.wave_interval_timer -= 0.2;
    attack.waves_remaining -= 1;
    attack.current_wave_index += 1;

    try std.testing.expectEqual(@as(u32, 0), attack.waves_remaining);
    try std.testing.expectEqual(@as(u32, 3), attack.current_wave_index);
}

test "Enemy Attack cancelCurrentAction cleanly halts channeling and sets cooldown" {
    const template = [_]Ability{
        .{
            .id = "queen_sweep",
            .execution_type = .projectile,
            .cooldown = 8.0,
            .projectile_profile = .{
                .is_channeled = true,
                .channel_duration = 5.0,
            },
        },
    };

    var attack = Self.init(&template, null);
    var list = lm.List(Ability).init(std.testing.allocator);
    try list.append(template[0]);
    attack.abilities = list;
    defer attack.End();

    attack.active_ability_index = 0;
    attack.action_state = .channeling;
    attack.channel_timer = 3.5;
    attack.channel_current_angle = 120.0;

    try std.testing.expect(attack.isActing());

    // Call cancelCurrentAction (e.g. from queenBondOfLifeEarlyCancel callback)
    attack.cancelCurrentAction();

    try std.testing.expect(!attack.isActing());
    try std.testing.expectEqual(ActionState.idle, attack.action_state);
    try std.testing.expectEqual(@as(f32, 0), attack.channel_timer);
    try std.testing.expectEqual(@as(f32, 0), attack.channel_current_angle);
    try std.testing.expect(attack.active_ability_index == null);

    // Cooldown applied to cancelled ability
    try std.testing.expectEqual(@as(f32, 8.0), attack.abilities.?.items()[0].cooldown_remaining);
}

