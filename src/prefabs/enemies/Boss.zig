const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const MobilityProfile = Enemy.Ability.MobilityProfile;
const RoomManager = @import("../../global/RoomManager.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");
const MeleePrefab = @import("Melee.zig").MeleeEnemy;
const RangedPrefab = @import("Ranged.zig").RangedEnemy;
const ElitePrefab = @import("Elite.zig").EliteEnemy;

var boss_enemy_count: u32 = 0;

pub const BossPhaseController = struct {
    const ControllerSelf = @This();

    stats: ?*Stats = null,
    transform: ?*lm.Transform = null,
    phase_reached: u8 = 1,

    pub fn Awake(self: *ControllerSelf, entity: *lm.Entity) !void {
        self.stats = try entity.pullComponent(Stats);
        self.transform = try entity.pullComponent(lm.Transform);
    }

    pub fn Update(self: *ControllerSelf) !void {
        if (lm.time.paused()) return;

        const stats: *Stats = try lm.ensureComponent(self.stats);
        const transform: *lm.Transform = try lm.ensureComponent(self.transform);
        if (stats.current.health <= 0) return;

        const health_fraction = stats.current.health / stats.max.health;
        const center_position = lm.vec3ToVec2(transform.position);

        if (self.phase_reached == 1 and health_fraction <= 0.75) {
            self.phase_reached = 2;
            try self.triggerPhaseTwo(center_position);
        } else if (self.phase_reached == 2 and health_fraction <= 0.50) {
            self.phase_reached = 3;
            try self.triggerPhaseThree(center_position, stats);
        } else if (self.phase_reached == 3 and health_fraction <= 0.25) {
            self.phase_reached = 4;
            try self.triggerPhaseFour(center_position, stats);
        }
    }

    fn spawnMinionAtOffset(center_position: lm.Vector2, offset_x: f32, offset_y: f32, minion_entity: *lm.Entity) !void {
        _ = center_position;
        _ = offset_x;
        _ = offset_y;
        try lm.summoning.entity(minion_entity);
        RoomManager.registerSummonedEnemy(minion_entity.uuid);
    }

    fn triggerPhaseTwo(self: *ControllerSelf, center_position: lm.Vector2) !void {
        _ = self;
        SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", center_position, center_position, 1200.0, 1.0, 0.1);

        const spawn_offsets = [_]lm.Vector2{
            lm.Vec2(-140, 0),
            lm.Vec2(140, 0),
            lm.Vec2(0, -140),
            lm.Vec2(0, 140),
        };

        for (spawn_offsets) |offset| {
            const minion_position = center_position.add(offset);
            const minion = try MeleePrefab(minion_position);
            try spawnMinionAtOffset(center_position, offset.x, offset.y, minion);
        }
    }

    fn triggerPhaseThree(self: *ControllerSelf, center_position: lm.Vector2, stats: *Stats) !void {
        _ = self;
        stats.current.attack_speed *= 1.25;
        stats.current.movement_speed *= 1.15;
        SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", center_position, center_position, 1200.0, 1.0, 0.1);

        const ranged_one = try RangedPrefab(center_position.add(lm.Vec2(-160, -100)));
        try spawnMinionAtOffset(center_position, -160, -100, ranged_one);

        const ranged_two = try RangedPrefab(center_position.add(lm.Vec2(160, -100)));
        try spawnMinionAtOffset(center_position, 160, -100, ranged_two);

        const elite_guard = try ElitePrefab(center_position.add(lm.Vec2(0, 150)));
        try spawnMinionAtOffset(center_position, 0, 150, elite_guard);
    }

    fn triggerPhaseFour(self: *ControllerSelf, center_position: lm.Vector2, stats: *Stats) !void {
        _ = self;
        stats.current.attack_speed *= 1.35;
        stats.current.movement_speed *= 1.25;
        SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", center_position, center_position, 1200.0, 1.2, 0.15);

        const offsets = [_]lm.Vector2{
            lm.Vec2(-180, -120),
            lm.Vec2(180, -120),
            lm.Vec2(-120, 160),
            lm.Vec2(120, 160),
        };

        for (offsets) |offset| {
            const minion = try MeleePrefab(center_position.add(offset));
            try spawnMinionAtOffset(center_position, offset.x, offset.y, minion);
        }

        const elite_one = try ElitePrefab(center_position.add(lm.Vec2(-140, 0)));
        try spawnMinionAtOffset(center_position, -140, 0, elite_one);

        const elite_two = try ElitePrefab(center_position.add(lm.Vec2(140, 0)));
        try spawnMinionAtOffset(center_position, 140, 0, elite_two);
    }
};

pub const boss_abilities = [_]Ability{
    Ability{
        .id = "boss_lunge",
        .execution_type = .mobility,
        .min_range = 140,
        .max_range = 600,
        .cooldown = 4.0,
        .mobility_profile = MobilityProfile{
            .direction = .towards_target,
            .sfx_path = "audio/sfx/dash.wav",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },
    Ability{
        .id = "boss_nova_barrage",
        .execution_type = .projectile,
        .min_range = 120,
        .max_range = 800,
        .cooldown = 4.5,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .damage = 0.5,
            .damage_type = .magic,
            .speed = 400,
            .lifetime = 2.0,
            .size = .init(56, 56),
            .spread_angles = &.{ -45, -30, -15, 0, 15, 30, 45 },
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },
};

const boss_fallback = Ability{
    .id = "boss_smash",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 120,
    .cooldown = 0.8,
    .projectile_profile = ProjectileProfile{
        .damage = 1.5,
        .damage_type = .physical,
        .speed = 600,
        .lifetime = 0.18,
        .size = .init(72, 72),
        .knockback_strength = 0.6,
        .knockback_duration = 0.3,
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .windup_animation = "windup-melee",
    .release_animation = "attack-melee",
    .winddown_animation = "winddown-melee",
};

pub fn BossEnemy(position: lm.Vector2) !*lm.Entity {
    defer boss_enemy_count +%= 1;

    return try lm.makeEntityI("boss-enemy", boss_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(100, 100),
        },
        lm.Renderer.init(.{
            .img_path = "characters/enemies/melee/left_1.png",
            .tint = lm.Color{ .r = 175, .g = 60, .b = 255, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(104, 104) },
            .weight = 6.0,
        }),
        lm.Animator.init(&Enemy.Animation.melee_animations),

        Stats.init(.enemy, .{
            .health = 2500,
            .attack_speed = 1.1,
            .armour = 75,
            .magic_resist = 40,
            .movement_speed = 120,
            .aggro_range = 1200,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.pursue),
        Enemy.Attack.init(&boss_abilities, boss_fallback),
        Enemy.Animation{},
        BossPhaseController{},
        Enemy.Death{ .enemy_type = .boss },
        Enemy.OverheadUI{ .show_health_bar = false },
    });
}
