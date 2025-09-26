const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;

const Projectile = @import("../../prefabs/Projectile.zig").Projectile;
const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");

const Weapon = @import("../Weapons/Weapon.zig");

const Self = @This();

remaining_timer: f32 = 0,
cooldown: f32 = 0,
chain_count: usize = 0,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,

arena: ?std.heap.ArenaAllocator = null,
allocator: ?std.mem.Allocator = null,

camera: ?*lm.Camera = null,

weapons: struct {
    goliath: Weapon = .{
        .light_attack = .{
            .shooting_degrees = &.{ -10, 0, 10 },
            .projectile_options = .{
                .damage_multiplier = 0.3,
            },
        },
    },
} = .{},

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.arena = .init(lm.allocators.generic());
    self.allocator = self.arena.?.allocator();

    self.dashing = try entity.pullComponent(Dashing);
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Start(self: *Self) void {
    self.camera = lm.activeScene().?.getCamera("main");
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);

    self.remaining_timer -= lm.time.deltaTime();
    self.cooldown -= lm.time.deltaTime();

    if (self.cooldown < 0) self.cooldown = 0;

    if (self.remaining_timer < 0) self.remaining_timer = 0;
    if (self.remaining_timer == 0) self.chain_count = 0;

    if (lm.mouse.getButtonDown(.left) and self.cooldown < 0.7 / stats.current.attack_speed) attack_block: {
        const mouse_pos = camera.screenToWorldPos(lm.rl.getMousePosition());
        self.remaining_timer = 1.25 / stats.current.attack_speed;

        if (self.cooldown < 0.25 / stats.current.attack_speed)
            self.chain_count = @min(self.chain_count + 1, 3)
        else
            self.chain_count = 0;

        self.cooldown = 1 / stats.current.attack_speed;

        stats.applyRoot(0.075);

        if (dashing.is_dashing()) {
            try self.weapons.goliath.dashAttack(
                lm.vec3ToVec2(transform.position),
                mouse_pos,
                stats.*,
            );

            break :attack_block;
        }

        // try lm.summon(&.{.{
        //     .entity = try switch (self.chain_count) {
        //         2 => Projectile(.{
        //             .start_position = lm.vec3ToVec2(transform.position),
        //             .target_position = mouse_pos,
        //             .size = lm.Vec2(96, 64),
        //             .lifetime = 1.5,
        //             .target_team = .enemy,
        //         }),
        //         3 => Projectile(.{
        //             .start_position = lm.vec3ToVec2(transform.position),
        //             .target_position = mouse_pos,
        //             .size = lm.Vec2(128, 64),
        //             .lifetime = 2,
        //             .passtrough = true,
        //             .damage_multiplier = 2,
        //             .target_team = .enemy,
        //         }),
        //         else => Projectile(.{
        //             .start_position = lm.vec3ToVec2(transform.position),
        //             .target_position = mouse_pos,
        //             .target_team = .enemy,
        //         }),
        //     },
        // }});

        try self.weapons.goliath.lightAttack(
            lm.vec3ToVec2(transform.position),
            mouse_pos,
            stats.*,
        );
    }

    const allocator = self.allocator orelse return;
    const arena = &(self.arena orelse return);
    _ = arena.reset(.free_all);

    const text = try std.fmt.allocPrint(allocator, "Chain Count: {d}", .{self.chain_count});
    const cooldown_text = try std.fmt.allocPrint(allocator, "Cooldown: {d}", .{self.cooldown});
    const health = try std.fmt.allocPrint(allocator, "Health: {d}", .{stats.current.health});
    const stamine = try std.fmt.allocPrint(allocator, "Stamina: {d}", .{stats.current.stamina});

    ui.new(.{
        .id = .ID("chain-attack-count"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = 20, .y = 20 },
        },
        .layout = .{ .direction = .top_to_bottom },
    })({
        ui.text(text, .{ .letter_spacing = 2 });
        ui.text(cooldown_text, .{ .letter_spacing = 2 });
        ui.text(health, .{ .letter_spacing = 2 });
        ui.text(stamine, .{ .letter_spacing = 2 });
    });
}
