const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;

const Projectile = @import("../../prefabs/Projectile.zig").Projectile;
const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");

const Spell = @import("../Weapons/Spell.zig");
const spells = @import("../Weapons/spells.zig");

const Weapon = @import("../Weapons/Weapon.zig");
const weapons = @import("../Weapons/weapons.zig");

const Hands = @import("../Weapons/Hands.zig");

const Self = @This();

cooldown: f32 = 0,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,

camera: ?*lm.Camera = null,

current_weapon_number: u1 = 0,
hands: ?*Hands = null,

equipped_spells: [2]?Spell = [_]?Spell{
    spells.heal,
    spells.root,
},

equipped_weapons: [2]?Weapon = [_]?Weapon{
    weapons.fists,
    weapons.goliath,
},

pub fn currentWeapon(self: *Self) ?*Weapon {
    return &(self.equipped_weapons[self.current_weapon_number] orelse return null);
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.dashing = try entity.pullComponent(Dashing);
    self.stats = try entity.pullComponent(Stats);
    self.hands = try entity.pullComponent(Hands);

    if (self.hands) |hands| {
        hands.play((self.currentWeapon() orelse return).*) catch {};
    }
}

pub fn Start(self: *Self) void {
    self.camera = lm.activeScene().?.getCameraById("main");
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused()) return;

    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const hands: *Hands = try lm.ensureComponent(self.hands);
    var weapon = self.currentWeapon() orelse return;

    self.cooldown -= lm.time.deltaTime();

    if (self.cooldown < 0) self.cooldown = 0;
    if (lm.keyboard.getKeyDown(.tab) or lm.gamepad.getButtonDown(0, .right_trigger_1)) {
        defer hands.play(weapon.*) catch {};

        self.current_weapon_number +%= 1;
        weapon = self.currentWeapon() orelse return;
    }

    if (self.equipped_spells[0]) |*spell| spell.update(lm.time.deltaTime());
    if (self.equipped_spells[1]) |*spell| spell.update(lm.time.deltaTime());

    if (lm.keyboard.getKeyDown(.q) or lm.gamepad.getButtonDown(0, .right_face_left)) {
        if (self.equipped_spells[0]) |*spell| _ = spell.cast(entity);
    }
    if (lm.keyboard.getKeyDown(.e) or lm.gamepad.getButtonDown(0, .right_face_up)) {
        if (self.equipped_spells[1]) |*spell| _ = spell.cast(entity);
    }

    const mouse_pos = get_angle_vetor: {
        const mouse = camera.screenToWorldPos(lm.mouse.getPosition());

        if (!lm.gamepad.isAvailable(0)) break :get_angle_vetor mouse;

        const gamepad = lm.gamepad.getStickVector(0, .right, 0.1);
        if (gamepad.length() == 0) break :get_angle_vetor mouse;

        break :get_angle_vetor gamepad.normalize().add(lm.vec3ToVec2(transform.position));
    };

    const direction_vector = mouse_pos
        .subtract(lm.vec3ToVec2(transform.position))
        .normalize()
        .multiply(.init(32, 32))
        .add(lm.vec3ToVec2(transform.position));

    if ((lm.mouse.getButtonDown(.left) or lm.gamepad.getButtonDown(0, .right_trigger_2)) and
        self.cooldown == 0 and
        !stats.current.stunned)
    attack_block: {
        self.cooldown = 1 / stats.current.attack_speed;

        stats.applyRoot(0.075);

        try hands.play(weapon.*);

        if (dashing.isDashing()) {
            try weapon.dashAttack(
                direction_vector,
                mouse_pos,
                stats.*,
            );

            break :attack_block;
        }

        try weapon.lightAttack(
            direction_vector,
            mouse_pos,
            stats.*,
        );
    } else if ((lm.mouse.getButtonDown(.right) or lm.gamepad.getButtonDown(0, .left_trigger_2)) and
        self.cooldown == 0 and
        !stats.current.stunned)
    {
        try hands.play(weapon.*);

        try weapon.heavyAttack(
            direction_vector,
            mouse_pos,
            stats.*,
        );

        stats.applyStun(0.2);
    }
}

pub fn equipSpell(self: *Self, spell: Spell) void {
    switch (spell.slot) {
        .left => self.equipped_spells[0] = spell,
        .right => self.equipped_spells[1] = spell,
    }
}

pub fn reduceSpellCooldowns(self: *Self, amount: f32) void {
    if (self.equipped_spells[0]) |*spell| spell.reduceCooldown(amount);
    if (self.equipped_spells[1]) |*spell| spell.reduceCooldown(amount);
}
