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
    winding_down,
};

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
player_transform: ?*lm.Transform = null,
player_stats: ?*Stats = null,
animator: ?*lm.Animator = null,

abilities: []Ability = &.{},
fallback_ability: ?Ability = null,

action_state: ActionState = .idle,
active_ability_index: ?usize = null,
is_fallback_active: bool = false,
action_timer: f32 = 0,

pub fn init(abilities: []Ability, fallback: ?Ability) Self {
    return Self{
        .abilities = abilities,
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
                .sfx_path = "audio/punch.mp3",
            },
        },
    };
}

pub fn isActing(self: *const Self) bool {
    return self.action_state != .idle;
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
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
        self.action_state = .idle;
        self.active_ability_index = null;
        self.is_fallback_active = false;
        self.action_timer = 0;
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

        if (self.getActiveAbilityPtr()) |ability| ability_finish: {
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

            const animator = self.animator orelse break :ability_finish;

            if (ability.release_animation) |rel_anim| {
                animator.play(rel_anim) catch std.log.err("failed to play release anim", .{});
            }

            if (ability.winddown_animation) |wd_anim| {
                self.action_state = .winding_down;

                var duration = Animation.getAnimationDuration(animator, wd_anim);
                if (duration <= 0) duration = 0.15;

                self.action_timer = duration;
                animator.play(wd_anim) catch std.log.err("failed to play winddown anim", .{});

                return;
            }
        }

        self.action_state = .idle;
        self.active_ability_index = null;
        self.is_fallback_active = false;
        self.action_timer = 0;

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

    for (self.abilities) |*ability| {
        ability.updateCooldown(dt);
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

    for (self.abilities, 0..) |*ability, index| {
        if (!ability.canExecute(stats.*, player_stats_val, distance)) continue;

        self.startAbility(ability, index, false, entity, transform, stats, player_transform);
        return;
    }

    if (self.fallback_ability) |*fallback| {
        if (fallback.canExecute(stats.*, player_stats_val, distance)) {
            self.startAbility(fallback, null, true, entity, transform, stats, player_transform);
        }
    }
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
    if (ability.windup_animation) |windup_anim| {
        self.action_state = .winding_up;
        self.active_ability_index = index;
        self.is_fallback_active = is_fallback;

        var duration: f32 = 0.2;
        if (self.animator) |animator| {
            const anim_dur = Animation.getAnimationDuration(animator, windup_anim);
            if (anim_dur > 0) duration = anim_dur;
            animator.play(windup_anim) catch {};
        }
        self.action_timer = duration;
        return;
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
    const animator = self.animator orelse return;

    if (ability.release_animation) |rel_anim| {
        animator.play(rel_anim) catch {};
    }

    if (ability.winddown_animation) |wd_anim| {
        self.action_state = .winding_down;
        self.active_ability_index = index;
        self.is_fallback_active = is_fallback;

        var duration = Animation.getAnimationDuration(animator, wd_anim);
        if (duration <= 0) duration = 0.15;

        self.action_timer = duration;
        animator.play(wd_anim) catch {};
    }
}

fn getActiveAbilityPtr(self: *Self) ?*Ability {
    if (self.is_fallback_active) return &(self.fallback_ability orelse return null);

    ability_index: {
        const index = self.active_ability_index orelse break :ability_index;
        if (index > self.abilities.len) break :ability_index;
        return &self.abilities[index];
    }

    return null;
}
