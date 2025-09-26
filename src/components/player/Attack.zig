const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;

const Projectile = @import("../../prefabs/Projectile.zig").Projectile;
const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");

const Weapon = @import("../Weapons/Weapon.zig");
const weapons = @import("../Weapons/weapons.zig");

const Self = @This();

cooldown: f32 = 0,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,

arena: ?std.heap.ArenaAllocator = null,
allocator: ?std.mem.Allocator = null,

camera: ?*lm.Camera = null,

current_weapon: Weapon = weapons.fists,

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

    self.cooldown -= lm.time.deltaTime();

    if (self.cooldown < 0) self.cooldown = 0;

    const mouse_pos = camera.screenToWorldPos(lm.rl.getMousePosition());
    if (lm.mouse.getButtonDown(.left) and self.cooldown < 1 / stats.current.attack_speed and !stats.current.stunned) attack_block: {
        self.cooldown = 1 / stats.current.attack_speed;

        stats.applyRoot(0.075);

        if (dashing.is_dashing()) {
            try self.current_weapon.dashAttack(
                lm.vec3ToVec2(transform.position),
                mouse_pos,
                stats.*,
            );

            break :attack_block;
        }

        try self.current_weapon.lightAttack(
            lm.vec3ToVec2(transform.position),
            mouse_pos,
            stats.*,
        );
    } else if (lm.mouse.getButtonDown(.right) and self.cooldown < 1 / stats.current.attack_speed and !stats.current.stunned) {
        try self.current_weapon.heavyAttack(
            lm.vec3ToVec2(transform.position),
            mouse_pos,
            stats.*,
        );

        stats.applyStun(0.2);
    }

    const allocator = self.allocator orelse return;
    const arena = &(self.arena orelse return);
    _ = arena.reset(.free_all);

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
        ui.text(health, .{ .letter_spacing = 2 });
        ui.text(stamine, .{ .letter_spacing = 2 });
    });
}
