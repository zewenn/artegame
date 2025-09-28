const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;

const Projectile = @import("../../prefabs/Projectile.zig").Projectile;
const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");

const Weapon = @import("../Weapons/Weapon.zig");
const weapons = @import("../Weapons/weapons.zig");
const Hands = @import("../Weapons/Hands.zig");

const Self = @This();

cooldown: f32 = 0,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,

arena: ?std.heap.ArenaAllocator = null,
allocator: ?std.mem.Allocator = null,

camera: ?*lm.Camera = null,

current_weapon: Weapon = weapons.fists,
hands: ?*Hands = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.arena = .init(lm.allocators.generic());
    self.allocator = self.arena.?.allocator();

    self.dashing = try entity.pullComponent(Dashing);
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.hands = try entity.pullComponent(Hands);

    if (self.hands) |hands| {
        hands.play(self.current_weapon) catch {};
    }
}

pub fn Start(self: *Self) void {
    self.camera = lm.activeScene().?.getCamera("main");
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const hands: *Hands = try lm.ensureComponent(self.hands);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);

    self.cooldown -= lm.time.deltaTime();

    if (self.cooldown < 0) self.cooldown = 0;

    if (lm.keyboard.getKeyDown(.tab) or
        lm.gamepad.getButtonDown(0, .right_trigger_1))
    weapon_switching: {
        defer hands.play(self.current_weapon) catch {};
        if (std.mem.eql(u8, self.current_weapon.id, weapons.fists.id)) {
            self.current_weapon = weapons.goliath;
            break :weapon_switching;
        }

        self.current_weapon = weapons.fists;
    }

    const mouse_pos = get_angle_vetor: {
        const mouse = camera.screenToWorldPos(lm.mouse.getPosition());

        if (!lm.gamepad.isAvailable(0)) break :get_angle_vetor mouse;

        const gamepad = lm.gamepad.getStickVector(0, .right, 0.1);
        if (gamepad.length() == 0) break :get_angle_vetor mouse;

        break :get_angle_vetor gamepad.normalize().add(lm.vec3ToVec2(transform.position));
    };

    if ((lm.mouse.getButtonDown(.left) or lm.gamepad.getButtonDown(0, .right_trigger_2)) and
        self.cooldown == 0 and
        !stats.current.stunned)
    attack_block: {
        self.cooldown = 1 / stats.current.attack_speed;

        stats.applyRoot(0.075);

        try hands.play(self.current_weapon);

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
    } else if ((lm.mouse.getButtonDown(.right) or lm.gamepad.getButtonDown(0, .left_trigger_2)) and
        self.cooldown == 0 and
        !stats.current.stunned)
    {
        try hands.play(self.current_weapon);

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
