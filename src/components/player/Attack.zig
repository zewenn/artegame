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
const AudioManager = @import("../../global/audio/AudioManager.zig");

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

    if (lm.keyboard.getKeyDown(.q) or lm.gamepad.getButtonDown(0, .right_face_left)) spell_0: {
        const spell = &(self.equipped_spells[0] orelse break :spell_0);
        if (spell.cast(entity)) AudioManager.playSfxPitched("audio/click.wav", 0.7, 0.15);
    }
    if (lm.keyboard.getKeyDown(.e) or lm.gamepad.getButtonDown(0, .right_face_up)) spell_1: {
        const spell = &(self.equipped_spells[1] orelse break :spell_1);
        if (spell.cast(entity)) AudioManager.playSfxPitched("audio/click.wav", 0.7, 0.15);
    }

    const player_pos = lm.vec3ToVec2(transform.position);

    const aim_dir = get_aim_dir: {
        if (lm.gamepad.isAvailable(0)) {
            const gamepad = lm.gamepad.getStickVector(0, .right, 0.1);
            if (gamepad.length() > 0) break :get_aim_dir gamepad.normalize();
        }

        const mouse = camera.screenToWorldPos(lm.mouse.getPosition());
        const diff = mouse.subtract(player_pos);
        if (diff.length() > 0) break :get_aim_dir diff.normalize();

        break :get_aim_dir lm.Vec2(1, 0);
    };

    const spawn_pos = player_pos.add(aim_dir.multiply(.init(32, 32)));
    const target_pos = spawn_pos.add(aim_dir);

    if ((lm.mouse.getButtonDown(.left) or lm.gamepad.getButtonDown(0, .right_trigger_2)) and
        self.cooldown == 0 and
        !stats.isStunned())
    attack_block: {
        self.cooldown = 1 / stats.current.attack_speed;

        stats.applyRoot(0.075);

        try hands.play(weapon.*);
        AudioManager.playSfxPitched("audio/punch.mp3", 0.7, 0.1);

        if (dashing.isDashing()) {
            try weapon.dashAttack(
                spawn_pos,
                target_pos,
                stats.*,
            );

            break :attack_block;
        }

        try weapon.lightAttack(
            spawn_pos,
            target_pos,
            stats.*,
        );
    } else if ((lm.mouse.getButtonDown(.right) or lm.gamepad.getButtonDown(0, .left_trigger_2)) and
        self.cooldown == 0 and
        !stats.isStunned())
    {
        self.cooldown = 1.8 / stats.current.attack_speed;

        stats.applyRoot(0.12);

        try hands.play(weapon.*);
        AudioManager.playSfxPitched("audio/punch.mp3", 0.95, 0.15);

        try weapon.heavyAttack(
            spawn_pos,
            target_pos,
            stats.*,
        );
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

pub fn getWeaponById(self: *Self, id: []const u8) ?*Weapon {
    for (&self.equipped_weapons) |*maybe_weapon| {
        if (maybe_weapon.*) |*weapon| {
            if (std.mem.eql(u8, weapon.id, id)) {
                return weapon;
            }
        }
    }
    return null;
}

pub fn hasWeaponId(self: *const Self, id: []const u8) bool {
    for (self.equipped_weapons) |maybe_weapon| {
        if (maybe_weapon) |weapon| {
            if (std.mem.eql(u8, weapon.id, id)) return true;
        }
    }
    return false;
}

test "Attack.getWeaponById and hasWeaponId" {
    var attack: Self = .{};
    try std.testing.expect(attack.hasWeaponId("Fists"));
    try std.testing.expect(attack.hasWeaponId("Goliath"));
    try std.testing.expect(!attack.hasWeaponId("NonExistent"));

    const fists_weapon = attack.getWeaponById("Fists");
    try std.testing.expect(fists_weapon != null);
    try std.testing.expectEqualStrings("Fists", fists_weapon.?.id);

    const goliath_weapon = attack.getWeaponById("Goliath");
    try std.testing.expect(goliath_weapon != null);
    try std.testing.expectEqualStrings("Goliath", goliath_weapon.?.id);

    try std.testing.expect(attack.getWeaponById("NonExistent") == null);
}
