const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Ability = @import("Ability.zig");
const Animation = @import("Animation.zig");

const Self = @This();

pub const AbilitySelection = struct {
    ability_index: ?usize = null,
    is_fallback: bool = false,
};

pub const TimedPhase = struct {
    selection: AbilitySelection = .{},
    timer_seconds: f32 = 0,
};

pub const ChannelState = struct {
    selection: AbilitySelection = .{},
    timer_seconds: f32 = 0,
    fire_timer_seconds: f32 = 0,
    current_angle_degrees: f32 = 0,
    rotation_speed_degrees_per_second: f32 = 0,
    fire_interval_seconds: f32 = 0,
};

pub const WaveState = struct {
    selection: AbilitySelection = .{},
    waves_remaining: u32 = 0,
    current_wave_index: u32 = 0,
    interval_timer_seconds: f32 = 0,
};

pub const ActionState = union(enum) {
    idle,
    winding_up: TimedPhase,
    releasing: TimedPhase,
    channeling: ChannelState,
    firing_waves: WaveState,
    winding_down: TimedPhase,
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
    const scene = lm.activeScene() orelse return;
    const player = scene.getEntityById("player") orelse return;
    self.player_transform = player.getComponent(lm.Transform);
    self.player_stats = player.getComponent(Stats);
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    if (stats.isStunned() or stats.isStasis()) {
        self.cancelCurrentAction();
        return;
    }

    const delta_seconds = lm.time.deltaTime();

    if (self.stepActiveAction(entity, transform, stats, player_transform, delta_seconds)) {
        return;
    }

    self.tickAbilityCooldowns(delta_seconds);

    if (stats.isWeakened()) return;

    const distance_pixels = std.math.hypot(
        transform.position.x - player_transform.position.x,
        transform.position.y - player_transform.position.y,
    );
    if (distance_pixels > stats.current.aggro_range) return;

    self.tryStartReadyAbility(entity, transform, stats, player_transform, distance_pixels);
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

pub fn isActing(self: *const Self) bool {
    return self.action_state != .idle;
}

pub fn cancelCurrentAction(self: *Self) void {
    if (self.getActiveAbilityPtr()) |ability| {
        const is_cancellable_active_phase = switch (self.action_state) {
            .channeling, .firing_waves, .winding_up, .releasing => true,
            .idle, .winding_down => false,
        };
        if (is_cancellable_active_phase) {
            ability.cooldown_remaining = ability.cooldown;
        }
    }
    self.action_state = .idle;
}

fn stepActiveAction(
    self: *Self,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
    delta_seconds: f32,
) bool {
    switch (self.action_state) {
        .idle => return false,
        .winding_up => |*phase| self.processWindingUp(phase, entity, transform, stats, player_transform, delta_seconds),
        .releasing => |*phase| self.processReleasing(phase, delta_seconds),
        .channeling => |*channel| self.processChanneling(channel, entity, transform, stats, player_transform, delta_seconds),
        .firing_waves => |*wave| self.processFiringWaves(wave, entity, transform, stats, player_transform, delta_seconds),
        .winding_down => |*phase| self.processWindingDown(phase, delta_seconds),
    }
    return true;
}

fn tickAbilityCooldowns(self: *Self, delta_seconds: f32) void {
    if (self.abilities) |*abilities| {
        for (abilities.items()) |*ability| {
            ability.updateCooldown(delta_seconds);
        }
    }
    if (self.fallback_ability) |*fallback| {
        fallback.updateCooldown(delta_seconds);
    }
}

fn tryStartReadyAbility(
    self: *Self,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
    distance_pixels: f32,
) void {
    const player_stats_value = if (self.player_stats) |player_stats| player_stats.* else null;

    if (self.abilities) |*abilities| {
        for (abilities.items(), 0..) |*ability, ability_index| {
            if (!ability.canExecute(stats.*, player_stats_value, distance_pixels)) continue;

            self.startAbility(ability, .{ .ability_index = ability_index, .is_fallback = false }, entity, transform, stats, player_transform);
            return;
        }
    }

    if (self.fallback_ability) |*fallback| {
        if (fallback.canExecute(stats.*, player_stats_value, distance_pixels)) {
            self.startAbility(fallback, .{ .ability_index = null, .is_fallback = true }, entity, transform, stats, player_transform);
        }
    }
}

fn isAnimationPhaseFinished(self: *Self, timer_seconds: f32, animation_name: ?[]const u8) bool {
    if (timer_seconds <= 0) return true;
    const animator = self.animator orelse return false;
    const target_animation = animation_name orelse return false;
    return !animator.isPlaying(target_animation);
}

fn processWindingUp(
    self: *Self,
    phase: *TimedPhase,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
    delta_seconds: f32,
) void {
    phase.timer_seconds -= delta_seconds;
    const active_ability = self.getAbilityForSelection(phase.selection);
    const windup_animation = if (active_ability) |ability| ability.windup_animation else null;

    if (!self.isAnimationPhaseFinished(phase.timer_seconds, windup_animation)) return;

    self.dispatchAbilityExecution(phase.selection, entity, transform, stats, player_transform);
}

fn processChanneling(
    self: *Self,
    channel: *ChannelState,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
    delta_seconds: f32,
) void {
    channel.timer_seconds -= delta_seconds;
    channel.fire_timer_seconds -= delta_seconds;
    channel.current_angle_degrees += channel.rotation_speed_degrees_per_second * delta_seconds;

    if (channel.fire_timer_seconds <= 0) {
        self.fireChannelBurst(channel, entity, transform, stats, player_transform);
        channel.fire_timer_seconds = channel.fire_interval_seconds;
    }

    if (channel.timer_seconds <= 0) {
        self.completeAbilityToWinddown(channel.selection);
    }
}

fn fireChannelBurst(
    self: *Self,
    channel: *const ChannelState,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
) void {
    const ability = self.getAbilityForSelection(channel.selection) orelse return;
    ability.fireProjectileWave(
        entity,
        transform,
        stats,
        player_transform,
        channel.current_angle_degrees,
    ) catch |fire_error| {
        std.log.err("Failed channeled barrage burst: {any}", .{fire_error});
    };
}

fn processFiringWaves(
    self: *Self,
    wave: *WaveState,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
    delta_seconds: f32,
) void {
    wave.interval_timer_seconds -= delta_seconds;

    if (wave.interval_timer_seconds <= 0 and wave.waves_remaining > 0) {
        const ability = self.getAbilityForSelection(wave.selection) orelse {
            self.cancelCurrentAction();
            return;
        };

        ability.fireProjectileWave(
            entity,
            transform,
            stats,
            player_transform,
            null,
        ) catch |fire_error| {
            std.log.err("Failed wave {d} burst: {any}", .{ wave.current_wave_index, fire_error });
        };
        wave.waves_remaining -= 1;
        wave.current_wave_index += 1;
        wave.interval_timer_seconds = if (ability.projectile_profile) |profile| profile.wave_interval else 0.15;
    }

    if (wave.waves_remaining == 0) {
        self.completeAbilityToWinddown(wave.selection);
    }
}

fn processReleasing(self: *Self, phase: *TimedPhase, delta_seconds: f32) void {
    phase.timer_seconds -= delta_seconds;
    const ability = self.getAbilityForSelection(phase.selection) orelse {
        self.cancelCurrentAction();
        return;
    };

    if (!self.isAnimationPhaseFinished(phase.timer_seconds, ability.release_animation)) return;

    self.transitionToWinddown(phase.selection, ability);
}

fn processWindingDown(self: *Self, phase: *TimedPhase, delta_seconds: f32) void {
    phase.timer_seconds -= delta_seconds;
    const active_ability = self.getAbilityForSelection(phase.selection);
    const winddown_animation = if (active_ability) |ability| ability.winddown_animation else null;

    if (!self.isAnimationPhaseFinished(phase.timer_seconds, winddown_animation)) return;

    self.action_state = .idle;
}

fn startAbility(
    self: *Self,
    ability: *Ability,
    selection: AbilitySelection,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
) void {
    if (ability.windup_animation) |windup_animation| {
        const duration_seconds = self.playTimedAnimation(windup_animation, 0.2);
        self.action_state = .{ .winding_up = .{
            .selection = selection,
            .timer_seconds = duration_seconds,
        } };
        return;
    }

    self.dispatchAbilityExecution(selection, entity, transform, stats, player_transform);
}

fn dispatchAbilityExecution(
    self: *Self,
    selection: AbilitySelection,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
) void {
    const ability = self.getAbilityForSelection(selection) orelse {
        self.cancelCurrentAction();
        return;
    };

    if (ability.execution_type == .projectile) {
        if (self.tryStartSpecialProjectile(selection, ability, entity, transform, stats, player_transform)) {
            return;
        }
    }

    ability.execute(
        entity,
        transform,
        stats,
        player_transform,
        self.player_stats,
    ) catch |execution_error| {
        std.log.err("Failed to execute ability {s}: {any}", .{ ability.id, execution_error });
    };

    ability.cooldown_remaining = ability.cooldown;
    self.transitionToReleasing(selection, ability);
}

fn tryStartSpecialProjectile(
    self: *Self,
    selection: AbilitySelection,
    ability: *const Ability,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
) bool {
    const profile = ability.projectile_profile orelse return false;
    if (profile.is_channeled) {
        self.beginChanneledExecution(selection, ability, profile, entity, transform, stats, player_transform);
        return true;
    }
    if (profile.wave_count > 1) {
        self.beginWaveExecution(selection, ability, profile, entity, transform, stats, player_transform);
        return true;
    }
    return false;
}

fn beginChanneledExecution(
    self: *Self,
    selection: AbilitySelection,
    ability: *const Ability,
    profile: Ability.ProjectileProfile,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
) void {
    ability.fireProjectileWave(
        entity,
        transform,
        stats,
        player_transform,
        profile.initial_angle,
    ) catch |fire_error| {
        std.log.err("Failed initial channel burst {s}: {any}", .{ ability.id, fire_error });
    };

    self.playReleaseAnimation(ability);
    self.action_state = .{ .channeling = .{
        .selection = selection,
        .timer_seconds = profile.channel_duration,
        .fire_timer_seconds = profile.channel_fire_interval,
        .current_angle_degrees = profile.initial_angle,
        .rotation_speed_degrees_per_second = profile.channel_rotation_speed,
        .fire_interval_seconds = profile.channel_fire_interval,
    } };
}

fn beginWaveExecution(
    self: *Self,
    selection: AbilitySelection,
    ability: *const Ability,
    profile: Ability.ProjectileProfile,
    entity: *lm.Entity,
    transform: *lm.Transform,
    stats: *Stats,
    player_transform: *lm.Transform,
) void {
    ability.fireProjectileWave(
        entity,
        transform,
        stats,
        player_transform,
        null,
    ) catch |fire_error| {
        std.log.err("Failed initial wave 0 for {s}: {any}", .{ ability.id, fire_error });
    };

    self.playReleaseAnimation(ability);
    self.action_state = .{ .firing_waves = .{
        .selection = selection,
        .waves_remaining = profile.wave_count - 1,
        .current_wave_index = 1,
        .interval_timer_seconds = profile.wave_interval,
    } };
}

fn playReleaseAnimation(self: *Self, ability: *const Ability) void {
    const animator = self.animator orelse return;
    const release_animation = ability.release_animation orelse return;
    animator.play(release_animation) catch {};
}

fn playTimedAnimation(self: *Self, animation_name: []const u8, fallback_duration_seconds: f32) f32 {
    const animator = self.animator orelse return fallback_duration_seconds;
    const animation_duration_seconds = Animation.getAnimationDuration(animator, animation_name);
    animator.play(animation_name) catch {};
    return if (animation_duration_seconds > 0) animation_duration_seconds else fallback_duration_seconds;
}

fn completeAbilityToWinddown(self: *Self, selection: AbilitySelection) void {
    const ability = self.getAbilityForSelection(selection) orelse {
        self.cancelCurrentAction();
        return;
    };
    ability.cooldown_remaining = ability.cooldown;
    self.transitionToWinddown(selection, ability);
}

fn transitionToReleasing(self: *Self, selection: AbilitySelection, ability: *Ability) void {
    if (ability.release_animation) |release_animation| {
        if (self.animator != null) {
            const duration_seconds = self.playTimedAnimation(release_animation, 0.2);
            self.action_state = .{ .releasing = .{
                .selection = selection,
                .timer_seconds = duration_seconds,
            } };
            return;
        }
    }

    self.transitionToWinddown(selection, ability);
}

fn transitionToWinddown(self: *Self, selection: AbilitySelection, ability: *Ability) void {
    if (ability.winddown_animation) |winddown_animation| {
        if (self.animator != null) {
            const duration_seconds = self.playTimedAnimation(winddown_animation, 0.15);
            self.action_state = .{ .winding_down = .{
                .selection = selection,
                .timer_seconds = duration_seconds,
            } };
            return;
        }
    }

    self.action_state = .idle;
}

fn getActiveAbilityPtr(self: *Self) ?*Ability {
    const selection: AbilitySelection = switch (self.action_state) {
        .idle => return null,
        .winding_up, .releasing, .winding_down => |phase| phase.selection,
        .channeling => |channel| channel.selection,
        .firing_waves => |wave| wave.selection,
    };
    return self.getAbilityForSelection(selection);
}

fn getAbilityForSelection(self: *Self, selection: AbilitySelection) ?*Ability {
    if (selection.is_fallback) return &(self.fallback_ability orelse return null);

    const abilities = &(self.abilities orelse return null);
    const index = selection.ability_index orelse return null;
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
    for (attack.abilities_template) |template_item| {
        var ability_instance = template_item;
        ability_instance.cooldown_remaining = 0;
        try list.append(ability_instance);
    }
    attack.abilities = list;
    defer attack.End();

    try std.testing.expectEqual(@as(usize, 2), attack.abilities.?.items().len);

    attack.action_state = .{ .releasing = .{ .selection = .{ .ability_index = 0 } } };
    const active_0 = attack.getActiveAbilityPtr();
    try std.testing.expect(active_0 != null);
    try std.testing.expectEqualStrings("slash", active_0.?.id);

    active_0.?.cooldown_remaining = 2.0;

    attack.action_state = .{ .releasing = .{ .selection = .{ .ability_index = 1 } } };
    const active_1 = attack.getActiveAbilityPtr();
    try std.testing.expect(active_1 != null);
    try std.testing.expectEqualStrings("spin", active_1.?.id);

    attack.action_state = .{ .releasing = .{ .selection = .{ .ability_index = 2 } } };
    try std.testing.expect(attack.getActiveAbilityPtr() == null);
    attack.action_state = .{ .releasing = .{ .selection = .{ .ability_index = 999 } } };
    try std.testing.expect(attack.getActiveAbilityPtr() == null);

    for (attack.abilities.?.items()) |*ability| {
        ability.updateCooldown(0.5);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), attack.abilities.?.items()[0].cooldown_remaining, 0.001);
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

    attack.action_state = .{ .channeling = .{
        .selection = .{ .ability_index = 0 },
        .timer_seconds = 3.5,
        .current_angle_degrees = 120.0,
    } };

    try std.testing.expect(attack.isActing());

    attack.cancelCurrentAction();

    try std.testing.expect(!attack.isActing());
    try std.testing.expectEqual(ActionState.idle, attack.action_state);
    try std.testing.expectEqual(@as(f32, 8.0), attack.abilities.?.items()[0].cooldown_remaining);
}
