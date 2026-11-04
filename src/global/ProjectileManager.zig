const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const MapTypes = @import("map/MapTypes.zig");
const Wall = MapTypes.Wall;
const Projectile = @import("../prefabs/Projectile.zig");
const Options = Projectile.Options;

const Self = @This();

pub const COLLIDER_SCALE_FACTOR: f32 = 0.8;

/// Contiguous Structure-of-Arrays record for active projectile simulation.
pub const ProjectileRecord = struct {
    position: lm.Vector2,
    velocity_pixels_per_second: lm.Vector2,
    rotation_degrees: f32,
    size_pixels: lm.Vector2,
    collider_half_extents_pixels: lm.Vector2,
    bounding_radius_pixels: f32,
    sin_rotation: f32,
    cos_rotation: f32,
    remaining_lifetime_seconds: f32,
    texture: ?*lm.Texture = null,
    options: Options,
};

/// Type definition for MultiArrayList storage of projectile records.
pub const ProjectileList = std.MultiArrayList(ProjectileRecord);

/// 2D oriented bounding box supporting fast bounding-sphere broadphase and SAT narrowphase.
pub const OrientedBox = struct {
    center_position: lm.Vector2,
    half_extents_pixels: lm.Vector2,
    bounding_radius_pixels: f32,
    sin_rotation: f32,
    cos_rotation: f32,

    /// Constructs an OrientedBox from center position, scale pixels, and rotation degrees.
    pub fn fromTransform(center_position: lm.Vector2, scale_pixels: lm.Vector2, rotation_degrees: f32) OrientedBox {
        const half_extents_pixels = lm.Vector2.init(
            @abs(scale_pixels.x) * 0.5,
            @abs(scale_pixels.y) * 0.5,
        );
        const rotation_radians = std.math.degreesToRadians(rotation_degrees);
        const sin_rotation = @sin(rotation_radians);
        const cos_rotation = @cos(rotation_radians);
        const bounding_radius_pixels = std.math.hypot(half_extents_pixels.x, half_extents_pixels.y);

        return OrientedBox{
            .center_position = center_position,
            .half_extents_pixels = half_extents_pixels,
            .bounding_radius_pixels = bounding_radius_pixels,
            .sin_rotation = sin_rotation,
            .cos_rotation = cos_rotation,
        };
    }

    /// Evaluates intersection between two oriented bounding boxes using Separating Axis Theorem.
    pub fn overlaps(first: OrientedBox, second: OrientedBox) bool {
        const delta_center = second.center_position.subtract(first.center_position);
        const distance_squared = delta_center.x * delta_center.x + delta_center.y * delta_center.y;
        const radius_sum = first.bounding_radius_pixels + second.bounding_radius_pixels;
        if (distance_squared > radius_sum * radius_sum) {
            return false;
        }

        const first_axis_x = lm.Vector2.init(first.cos_rotation, first.sin_rotation);
        const first_axis_y = lm.Vector2.init(-first.sin_rotation, first.cos_rotation);
        const second_axis_x = lm.Vector2.init(second.cos_rotation, second.sin_rotation);
        const second_axis_y = lm.Vector2.init(-second.sin_rotation, second.cos_rotation);

        const dot_xx = first_axis_x.x * second_axis_x.x + first_axis_x.y * second_axis_x.y;
        const dot_xy = first_axis_x.x * second_axis_y.x + first_axis_x.y * second_axis_y.y;
        const dot_yx = first_axis_y.x * second_axis_x.x + first_axis_y.y * second_axis_x.y;
        const dot_yy = first_axis_y.x * second_axis_y.x + first_axis_y.y * second_axis_y.y;

        const abs_dot_xx = @abs(dot_xx);
        const abs_dot_xy = @abs(dot_xy);
        const abs_dot_yx = @abs(dot_yx);
        const abs_dot_yy = @abs(dot_yy);

        const distance_first_x = @abs(delta_center.x * first_axis_x.x + delta_center.y * first_axis_x.y);
        const projected_radius_first_x = first.half_extents_pixels.x +
            (second.half_extents_pixels.x * abs_dot_xx + second.half_extents_pixels.y * abs_dot_xy);
        if (distance_first_x > projected_radius_first_x) return false;

        const distance_first_y = @abs(delta_center.x * first_axis_y.x + delta_center.y * first_axis_y.y);
        const projected_radius_first_y = first.half_extents_pixels.y +
            (second.half_extents_pixels.x * abs_dot_yx + second.half_extents_pixels.y * abs_dot_yy);
        if (distance_first_y > projected_radius_first_y) return false;

        const distance_second_x = @abs(delta_center.x * second_axis_x.x + delta_center.y * second_axis_x.y);
        const projected_radius_second_x = second.half_extents_pixels.x +
            (first.half_extents_pixels.x * abs_dot_xx + first.half_extents_pixels.y * abs_dot_yx);
        if (distance_second_x > projected_radius_second_x) return false;

        const distance_second_y = @abs(delta_center.x * second_axis_y.x + delta_center.y * second_axis_y.y);
        const projected_radius_second_y = second.half_extents_pixels.y +
            (first.half_extents_pixels.x * abs_dot_xy + first.half_extents_pixels.y * abs_dot_yy);
        if (distance_second_y > projected_radius_second_y) return false;

        return true;
    }
};

const RetainedTextureEntry = struct {
    sprite_path: []const u8,
    width_pixels: i32,
    height_pixels: i32,
    texture: *lm.Texture,
};

projectiles: ProjectileList = .{},
retained_textures: std.ArrayListUnmanaged(RetainedTextureEntry) = .empty,

var active_instance: ?*Self = null;

/// Returns the currently active ProjectileManager instance.
pub fn instance() ?*Self {
    return active_instance;
}

/// Spawns a projectile into the active manager instance.
pub fn spawn(options: Options) !void {
    const manager = active_instance orelse return;
    try manager.spawnRecord(options, true);
}

/// Clears all active projectiles across the active manager instance.
pub fn clearAll() void {
    const manager = active_instance orelse return;
    manager.clearProjectiles();
}

/// Returns the count of currently active projectiles in the active manager.
pub fn activeCount() usize {
    const manager = active_instance orelse return 0;
    return manager.projectiles.len;
}

/// Lifecycle initialization for ProjectileManager behaviour.
pub fn Awake(self: *Self) !void {
    active_instance = self;
    try self.projectiles.ensureTotalCapacity(lm.allocators.generic(), 512);
}

/// Per-frame motion integration and renderer submission.
pub fn Update(self: *Self) !void {
    self.stepMotionAndLifetime(lm.time.deltaTime());
    try self.submitRenderers();
}

/// Periodic fixed-interval physics and collision evaluation.
pub fn Tick(self: *Self) !void {
    self.stepSceneCollisions();
}

/// Cleanup of retained textures and projectile memory.
pub fn End(self: *Self) !void {
    for (self.retained_textures.items) |entry| {
        lm.assets.texture.releasePtr(entry.texture);
        lm.allocators.generic().free(entry.sprite_path);
    }
    self.retained_textures.deinit(lm.allocators.generic());
    self.projectiles.deinit(lm.allocators.generic());
    if (active_instance == self) {
        active_instance = null;
    }
}

/// Clears all projectiles while retaining allocated capacity.
pub fn clearProjectiles(self: *Self) void {
    self.projectiles.clearRetainingCapacity();
}

/// Spawns a single projectile record into the manager's MultiArrayList.
pub fn spawnRecord(self: *Self, options: Options, load_texture: bool) !void {
    const delta_x = options.target_position.x - options.start_position.x;
    const delta_y = options.target_position.y - options.start_position.y;
    const delta_length_pixels = std.math.hypot(delta_x, delta_y);

    const direction = if (delta_length_pixels > 0.0001)
        lm.Vector2.init(delta_x / delta_length_pixels, delta_y / delta_length_pixels)
    else
        lm.Vector2.init(1.0, 0.0);

    const velocity_pixels_per_second = lm.Vector2.init(
        direction.x * options.speed,
        direction.y * options.speed,
    );

    const rotation_degrees = std.math.radiansToDegrees(std.math.atan2(delta_y, delta_x)) - 90.0;
    const rotation_radians = std.math.degreesToRadians(rotation_degrees);
    const sin_rotation = @sin(rotation_radians);
    const cos_rotation = @cos(rotation_radians);

    const half_collider_scale = COLLIDER_SCALE_FACTOR * 0.5;
    const collider_half_extents_pixels = lm.Vector2.init(
        options.size.x * half_collider_scale,
        options.size.y * half_collider_scale,
    );
    const bounding_radius_pixels = std.math.hypot(
        collider_half_extents_pixels.x,
        collider_half_extents_pixels.y,
    );

    const texture = if (load_texture)
        self.resolveTexture(options.getProjectileSprite(), options.size)
    else
        null;

    const record = ProjectileRecord{
        .position = options.start_position,
        .velocity_pixels_per_second = velocity_pixels_per_second,
        .rotation_degrees = rotation_degrees,
        .size_pixels = options.size,
        .collider_half_extents_pixels = collider_half_extents_pixels,
        .bounding_radius_pixels = bounding_radius_pixels,
        .sin_rotation = sin_rotation,
        .cos_rotation = cos_rotation,
        .remaining_lifetime_seconds = options.lifetime,
        .texture = texture,
        .options = options,
    };

    try self.projectiles.append(lm.allocators.generic(), record);
}

fn resolveTexture(self: *Self, sprite_path: []const u8, size_pixels: lm.Vector2) ?*lm.Texture {
    if (size_pixels.x <= 0 or size_pixels.y <= 0) return null;
    const width_pixels = lm.toi32(size_pixels.x);
    const height_pixels = lm.toi32(size_pixels.y);

    for (self.retained_textures.items) |entry| {
        const matches_dimensions = entry.width_pixels == width_pixels and entry.height_pixels == height_pixels;
        if (matches_dimensions and std.mem.eql(u8, entry.sprite_path, sprite_path)) {
            return entry.texture;
        }
    }

    const loaded_texture = lm.assets.texture.get(
        sprite_path,
        &.{ width_pixels, height_pixels },
    ) orelse return null;

    const duplicated_path = lm.allocators.generic().dupe(u8, sprite_path) catch return loaded_texture;
    self.retained_textures.append(lm.allocators.generic(), .{
        .sprite_path = duplicated_path,
        .width_pixels = width_pixels,
        .height_pixels = height_pixels,
        .texture = loaded_texture,
    }) catch {
        lm.allocators.generic().free(duplicated_path);
        return loaded_texture;
    };
    return loaded_texture;
}

/// Integrates motion and decrements remaining lifetimes across all projectiles.
pub fn stepMotionAndLifetime(self: *Self, delta_seconds: f32) void {
    const slice = self.projectiles.slice();
    const positions = slice.items(.position);
    const velocities_pixels_per_second = slice.items(.velocity_pixels_per_second);
    const remaining_lifetimes_seconds = slice.items(.remaining_lifetime_seconds);
    const projectile_count = self.projectiles.len;

    for (0..projectile_count) |projectile_index| {
        positions[projectile_index].x += velocities_pixels_per_second[projectile_index].x * delta_seconds;
        positions[projectile_index].y += velocities_pixels_per_second[projectile_index].y * delta_seconds;
        remaining_lifetimes_seconds[projectile_index] -= delta_seconds;
    }

    self.removeExpiredOrInactiveProjectiles();
}

fn removeExpiredOrInactiveProjectiles(self: *Self) void {
    if (self.projectiles.len == 0) return;
    const slice = self.projectiles.slice();
    const remaining_lifetimes_seconds = slice.items(.remaining_lifetime_seconds);
    const options_list = slice.items(.options);

    var projectile_index: usize = self.projectiles.len;
    while (projectile_index > 0) {
        projectile_index -= 1;
        const is_expired = remaining_lifetimes_seconds[projectile_index] <= 0.0;
        const is_inactive = options_list[projectile_index].inactive;
        if (is_expired or is_inactive) {
            self.projectiles.swapRemove(projectile_index);
        }
    }
}

/// Processes collision detection against walls and targets across the scene.
pub fn stepSceneCollisions(self: *Self) void {
    const scene = lm.activeScene() orelse return;
    const entities = scene.entities.items();

    for (entities) |entity| {
        self.processEntityCollisions(entity);
    }

    self.removeInactiveProjectiles();
}

fn removeInactiveProjectiles(self: *Self) void {
    if (self.projectiles.len == 0) return;
    const slice = self.projectiles.slice();
    const options_list = slice.items(.options);

    var projectile_index: usize = self.projectiles.len;
    while (projectile_index > 0) {
        projectile_index -= 1;
        if (options_list[projectile_index].inactive) {
            self.projectiles.swapRemove(projectile_index);
        }
    }
}

fn processEntityCollisions(self: *Self, entity: *lm.Entity) void {
    const transform = entity.getComponent(lm.Transform) orelse return;

    if (entity.getComponent(Wall)) |wall| {
        self.processWallCollisions(entity, wall, transform);
        return;
    }

    if (entity.getComponent(Stats)) |stats| {
        self.processTargetCollisions(entity, stats, transform);
        return;
    }
}

fn createOrientedBoxFromEntity(entity: *lm.Entity, transform: *const lm.Transform) OrientedBox {
    if (entity.getComponent(lm.RectangleCollider)) |collider| {
        const center_position = lm.vec3ToVec2(transform.position.add(collider.collider_transform.position));
        const collider_scale = collider.collider_transform.scale;
        const scale_pixels = if (collider_scale.x > 0 and collider_scale.y > 0)
            collider_scale
        else
            transform.scale;
        const rotation_degrees = transform.rotation + collider.collider_transform.rotation;
        return OrientedBox.fromTransform(center_position, scale_pixels, rotation_degrees);
    }

    return OrientedBox.fromTransform(
        lm.vec3ToVec2(transform.position),
        transform.scale,
        transform.rotation,
    );
}

fn processWallCollisions(
    self: *Self,
    entity: *lm.Entity,
    wall: *const Wall,
    transform: *const lm.Transform,
) void {
    if (!wall.wall_type.blocksProjectiles()) return;

    const wall_box = createOrientedBoxFromEntity(entity, transform);
    const slice = self.projectiles.slice();
    const positions = slice.items(.position);
    const options_list = slice.items(.options);
    const collider_half_extents = slice.items(.collider_half_extents_pixels);
    const bounding_radii = slice.items(.bounding_radius_pixels);
    const sin_rotations = slice.items(.sin_rotation);
    const cos_rotations = slice.items(.cos_rotation);

    for (0..self.projectiles.len) |projectile_index| {
        testProjectileWall(
            projectile_index,
            wall.*,
            wall_box,
            positions,
            options_list,
            collider_half_extents,
            bounding_radii,
            sin_rotations,
            cos_rotations,
        );
    }
}

fn testProjectileWall(
    projectile_index: usize,
    wall: Wall,
    wall_box: OrientedBox,
    positions: []const lm.Vector2,
    options_list: []Options,
    collider_half_extents: []const lm.Vector2,
    bounding_radii: []const f32,
    sin_rotations: []const f32,
    cos_rotations: []const f32,
) void {
    if (options_list[projectile_index].inactive) return;

    const projectile_box = OrientedBox{
        .center_position = positions[projectile_index],
        .half_extents_pixels = collider_half_extents[projectile_index],
        .bounding_radius_pixels = bounding_radii[projectile_index],
        .sin_rotation = sin_rotations[projectile_index],
        .cos_rotation = cos_rotations[projectile_index],
    };

    if (!OrientedBox.overlaps(projectile_box, wall_box)) return;

    _ = Projectile.resolveWallCollision(
        &options_list[projectile_index],
        positions[projectile_index],
        wall,
    );
}

fn processTargetCollisions(
    self: *Self,
    entity: *lm.Entity,
    stats: *const Stats,
    transform: *const lm.Transform,
) void {
    const target_box = createOrientedBoxFromEntity(entity, transform);
    const slice = self.projectiles.slice();
    const positions = slice.items(.position);
    const options_list = slice.items(.options);
    const collider_half_extents = slice.items(.collider_half_extents_pixels);
    const bounding_radii = slice.items(.bounding_radius_pixels);
    const sin_rotations = slice.items(.sin_rotation);
    const cos_rotations = slice.items(.cos_rotation);

    for (0..self.projectiles.len) |projectile_index| {
        testProjectileTarget(
            projectile_index,
            entity,
            stats,
            target_box,
            positions,
            options_list,
            collider_half_extents,
            bounding_radii,
            sin_rotations,
            cos_rotations,
        );
    }
}

fn testProjectileTarget(
    projectile_index: usize,
    target_entity: *lm.Entity,
    target_stats: *const Stats,
    target_box: OrientedBox,
    positions: []const lm.Vector2,
    options_list: []Options,
    collider_half_extents: []const lm.Vector2,
    bounding_radii: []const f32,
    sin_rotations: []const f32,
    cos_rotations: []const f32,
) void {
    if (options_list[projectile_index].inactive) return;
    if (target_stats.team != options_list[projectile_index].target_team) return;

    const projectile_box = OrientedBox{
        .center_position = positions[projectile_index],
        .half_extents_pixels = collider_half_extents[projectile_index],
        .bounding_radius_pixels = bounding_radii[projectile_index],
        .sin_rotation = sin_rotations[projectile_index],
        .cos_rotation = cos_rotations[projectile_index],
    };

    if (!OrientedBox.overlaps(projectile_box, target_box)) return;

    Projectile.resolveEntityHit(
        &options_list[projectile_index],
        positions[projectile_index],
        target_entity,
    );
}

/// Submits render calls for all active projectiles with loaded textures.
pub fn submitRenderers(self: *Self) !void {
    const slice = self.projectiles.slice();
    const positions = slice.items(.position);
    const rotations_degrees = slice.items(.rotation_degrees);
    const sizes_pixels = slice.items(.size_pixels);
    const textures = slice.items(.texture);

    for (0..self.projectiles.len) |projectile_index| {
        const projectile_texture = textures[projectile_index] orelse continue;
        try lm.display.addRenderer(.{
            .renderer = .{
                .texture = .{
                    .texture = projectile_texture.*,
                    .transform = lm.Transform{
                        .position = lm.vec2ToVec3(positions[projectile_index]),
                        .rotation = rotations_degrees[projectile_index],
                        .scale = sizes_pixels[projectile_index],
                    },
                    .tint = lm.deps.rl.Color.white,
                    .fill_color = null,
                    .entity = null,
                },
            },
            .index = 0,
        });
    }
}

test "ProjectileManager SoA spawn, motion, and lifetime expiration" {
    var manager = Self{};
    defer manager.projectiles.deinit(lm.allocators.generic());

    const options = Options{
        .start_position = .init(0, 0),
        .target_position = .init(100, 0),
        .speed = 200,
        .lifetime = 0.5,
    };

    try manager.spawnRecord(options, false);
    try std.testing.expectEqual(@as(usize, 1), manager.projectiles.len);

    manager.stepMotionAndLifetime(0.1);
    const slice = manager.projectiles.slice();
    const positions = slice.items(.position);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), positions[0].x, 0.01);
    try std.testing.expectEqual(@as(usize, 1), manager.projectiles.len);

    manager.stepMotionAndLifetime(0.45);
    try std.testing.expectEqual(@as(usize, 0), manager.projectiles.len);
}

test "OrientedBox overlaps broadphase and narrowphase detection" {
    const first_box = OrientedBox.fromTransform(.init(0, 0), .init(20, 20), 0);
    const overlapping_box = OrientedBox.fromTransform(.init(10, 0), .init(20, 20), 0);
    const separated_box = OrientedBox.fromTransform(.init(50, 0), .init(20, 20), 0);

    try std.testing.expect(OrientedBox.overlaps(first_box, overlapping_box));
    try std.testing.expect(!OrientedBox.overlaps(first_box, separated_box));

    const rotated_box = OrientedBox.fromTransform(.init(15, 0), .init(20, 20), 45);
    try std.testing.expect(OrientedBox.overlaps(first_box, rotated_box));
}

test "ProjectileManager 5000 concurrent projectiles update within 16ms" {
    var manager = Self{};
    defer manager.projectiles.deinit(lm.allocators.generic());

    try manager.projectiles.ensureTotalCapacity(lm.allocators.generic(), 5000);

    for (0..5000) |index| {
        const float_index = @as(f32, @floatFromInt(index));
        const angle_radians = float_index * 0.001;
        const target_x = @cos(angle_radians) * 1000.0;
        const target_y = @sin(angle_radians) * 1000.0;

        try manager.spawnRecord(.{
            .start_position = .init(0, 0),
            .target_position = .init(target_x, target_y),
            .speed = 300.0,
            .lifetime = 10.0,
            .size = .init(32, 32),
        }, false);
    }

    try std.testing.expectEqual(@as(usize, 5000), manager.projectiles.len);

    const wall_box = OrientedBox.fromTransform(.init(500, 500), .init(64, 64), 0);
    var collision_count: usize = 0;

    const start_nanoseconds = std.Io.Timestamp.now(std.testing.io, .real).toNanoseconds();
    manager.stepMotionAndLifetime(0.016);

    const slice = manager.projectiles.slice();
    const positions = slice.items(.position);
    const collider_half_extents = slice.items(.collider_half_extents_pixels);
    const bounding_radii = slice.items(.bounding_radius_pixels);
    const sin_rotations = slice.items(.sin_rotation);
    const cos_rotations = slice.items(.cos_rotation);

    for (0..manager.projectiles.len) |projectile_index| {
        const projectile_box = OrientedBox{
            .center_position = positions[projectile_index],
            .half_extents_pixels = collider_half_extents[projectile_index],
            .bounding_radius_pixels = bounding_radii[projectile_index],
            .sin_rotation = sin_rotations[projectile_index],
            .cos_rotation = cos_rotations[projectile_index],
        };
        if (OrientedBox.overlaps(projectile_box, wall_box)) {
            collision_count += 1;
        }
    }

    const end_nanoseconds = std.Io.Timestamp.now(std.testing.io, .real).toNanoseconds();
    const elapsed_nanoseconds = end_nanoseconds - start_nanoseconds;
    const elapsed_milliseconds = @as(f64, @floatFromInt(elapsed_nanoseconds)) / 1_000_000.0;

    try std.testing.expect(elapsed_milliseconds < 16.0);
    try std.testing.expectEqual(@as(usize, 5000), manager.projectiles.len);
}
