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
const ControlScheme = @import("../../global/input/ControlScheme.zig");

const Self = @This();

cooldown: f32 = 0,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,

camera: ?*lm.Camera = null,

current_weapon_number: u1 = 0,
hands: ?*Hands = null,
last_aim_direction: lm.Vector2 = .init(1, 0),

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
}

pub fn Start(self: *Self) void {
    self.camera = lm.activeScene().?.getCameraById("main");
    if (self.hands) |hands| {
        if (self.currentWeapon()) |w| {
            hands.setWeapon(w.*);
        }
    }
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
        if (spell.cast(entity)) AudioManager.playSfxPitched("audio/sfx/click.wav", 0.7, 0.15);
    }
    if (lm.keyboard.getKeyDown(.e) or lm.gamepad.getButtonDown(0, .right_face_up)) spell_1: {
        const spell = &(self.equipped_spells[1] orelse break :spell_1);
        if (spell.cast(entity)) AudioManager.playSfxPitched("audio/sfx/click.wav", 0.7, 0.15);
    }

    const player_position = lm.vec3ToVec2(transform.position);
    const control_scheme = ControlScheme.getControlScheme();
    const arrow_vector = ControlScheme.getArrowVector();
    const is_arrow_pressed = ControlScheme.isAnyArrowKeyPressed();
    const is_arrow_held = ControlScheme.isAnyArrowKeyHeld();
    const is_shift_modifier = ControlScheme.isShiftModifierActive();

    const aim_direction = resolve_aim: {
        if (lm.gamepad.isAvailable(0)) {
            const gamepad_stick = lm.gamepad.getStickVector(0, .right, 0.1);
            if (gamepad_stick.length() > 0) {
                const normalized = gamepad_stick.normalize();
                self.last_aim_direction = normalized;
                break :resolve_aim normalized;
            }
        }

        const mouse_world_position = camera.screenToWorldPos(lm.mouse.getPosition());
        const mouse_difference = mouse_world_position.subtract(player_position);
        const resolved = resolveAimDirection(control_scheme, arrow_vector, mouse_difference, self.last_aim_direction);
        self.last_aim_direction = resolved;
        break :resolve_aim resolved;
    };

    const spawn_position = player_position.add(aim_direction.multiply(.init(32, 32)));
    const target_position = spawn_position.add(aim_direction);

    const should_attack_via_arrows = arrow_vector.length() > 0 and (is_arrow_pressed or is_arrow_held);
    const should_attack_via_mouse_light = (control_scheme == .keyboard_and_mouse) and lm.mouse.getButtonDown(.left);
    const should_attack_via_mouse_heavy = (control_scheme == .keyboard_and_mouse) and lm.mouse.getButtonDown(.right);
    const should_attack_via_gamepad_light = lm.gamepad.getButtonDown(0, .right_trigger_2);
    const should_attack_via_gamepad_heavy = lm.gamepad.getButtonDown(0, .left_trigger_2);

    const is_heavy_requested = (should_attack_via_arrows and is_shift_modifier) or
        should_attack_via_mouse_heavy or
        should_attack_via_gamepad_heavy;

    const is_light_requested = (should_attack_via_arrows and !is_shift_modifier) or
        should_attack_via_mouse_light or
        should_attack_via_gamepad_light;

    if (self.cooldown == 0 and !stats.isStunned()) {
        if (is_heavy_requested) {
            try self.executeHeavyAttack(weapon, hands, stats, spawn_position, target_position);
        } else if (is_light_requested) {
            try self.executeLightAttack(weapon, hands, stats, dashing, spawn_position, target_position);
        }
    }
}

fn executeLightAttack(
    self: *Self,
    weapon: *Weapon,
    hands: *Hands,
    stats: *Stats,
    dashing: *Dashing,
    spawn_position: lm.Vector2,
    target_position: lm.Vector2,
) !void {
    self.cooldown = 1.0 / stats.current.attack_speed;

    stats.addEffect(.{
        .id = "root",
        .effect_type = .root,
        .duration = 0.075,
        .visual = .{},
    });

    try hands.play(weapon.*);
    AudioManager.playSfxPitched("audio/sfx/punch.mp3", 0.7, 0.1);

    if (dashing.isDashing()) {
        try weapon.dashAttack(
            spawn_position,
            target_position,
            stats.*,
        );
        return;
    }

    try weapon.lightAttack(
        spawn_position,
        target_position,
        stats.*,
    );
}

fn executeHeavyAttack(
    self: *Self,
    weapon: *Weapon,
    hands: *Hands,
    stats: *Stats,
    spawn_position: lm.Vector2,
    target_position: lm.Vector2,
) !void {
    self.cooldown = 1.8 / stats.current.attack_speed;

    stats.addEffect(.{
        .id = "root",
        .effect_type = .root,
        .duration = 0.12,
        .visual = .{},
    });

    try hands.play(weapon.*);
    AudioManager.playSfxPitched("audio/sfx/punch.mp3", 0.95, 0.15);

    try weapon.heavyAttack(
        spawn_position,
        target_position,
        stats.*,
    );
}

/// Resolves the 2D aim direction according to the active control scheme and input inputs.
pub fn resolveAimDirection(
    scheme: ControlScheme.ControlScheme,
    arrow_vector: lm.Vector2,
    mouse_difference: lm.Vector2,
    fallback_direction: lm.Vector2,
) lm.Vector2 {
    if (scheme == .keyboard_only) {
        if (arrow_vector.length() > 0) {
            return arrow_vector.normalize();
        }
        return fallback_direction;
    }

    if (arrow_vector.length() > 0) {
        return arrow_vector.normalize();
    }

    if (mouse_difference.length() > 0) {
        return mouse_difference.normalize();
    }

    return fallback_direction;
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

test "Attack.resolveAimDirection in keyboard_only mode uses arrow keys and ignores mouse" {
    const fallback = lm.Vec2(1, 0);
    const mouse_diff = lm.Vec2(100, 200);

    // Aiming straight up via arrow keys
    const up_direction = resolveAimDirection(.keyboard_only, .init(0, -1), mouse_diff, fallback);
    try std.testing.expectApproxEqAbs(@as(f32, 0), up_direction.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1), up_direction.y, 0.001);

    // Aiming diagonal up-right via arrow keys
    const up_right_direction = resolveAimDirection(.keyboard_only, .init(1, -1), mouse_diff, fallback);
    const expected_diagonal: f32 = std.math.sqrt(@as(f32, 0.5));
    try std.testing.expectApproxEqAbs(expected_diagonal, up_right_direction.x, 0.001);
    try std.testing.expectApproxEqAbs(-expected_diagonal, up_right_direction.y, 0.001);

    // When no arrow keys pressed, retains fallback direction and ignores mouse
    const fallback_direction = resolveAimDirection(.keyboard_only, .init(0, 0), mouse_diff, fallback);
    try std.testing.expectApproxEqAbs(@as(f32, 1), fallback_direction.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), fallback_direction.y, 0.001);
}

test "Attack.resolveAimDirection in keyboard_and_mouse mode prioritizes arrows then mouse" {
    const fallback = lm.Vec2(0, 1);
    const mouse_diff = lm.Vec2(100, 0);

    // If mouse diff is present and no arrows, uses mouse
    const mouse_aim = resolveAimDirection(.keyboard_and_mouse, .init(0, 0), mouse_diff, fallback);
    try std.testing.expectApproxEqAbs(@as(f32, 1), mouse_aim.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), mouse_aim.y, 0.001);

    // If arrow keys pressed, uses arrow keys
    const arrow_aim = resolveAimDirection(.keyboard_and_mouse, .init(-1, 0), mouse_diff, fallback);
    try std.testing.expectApproxEqAbs(@as(f32, -1), arrow_aim.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), arrow_aim.y, 0.001);
}
