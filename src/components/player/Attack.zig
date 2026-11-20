const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");

const Spell = @import("../weapons/Spell.zig");
const spells = @import("../weapons/spells.zig");

const Weapon = @import("../weapons/Weapon.zig");
const weapons = @import("../weapons/weapons.zig");

const Hands = @import("../weapons/Hands.zig");
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

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.dashing = try entity.pullComponent(Dashing);
    self.stats = try entity.pullComponent(Stats);
    self.hands = try entity.pullComponent(Hands);
}

pub fn Start(self: *Self) void {
    self.camera = lm.activeScene().?.getCameraById("main");
    const hands = self.hands orelse return;
    const weapon = self.currentWeapon() orelse return;
    hands.setWeapon(weapon.*);
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused()) return;

    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const hands: *Hands = try lm.ensureComponent(self.hands);

    self.cooldown = @max(0, self.cooldown - lm.time.deltaTime());
    const weapon = self.handleWeaponSwitch(hands) orelse return;

    self.updateAndCastSpells(entity);

    const player_position = lm.vec3ToVec2(transform.position);
    const aim_direction = self.resolveCurrentAimDirection(camera, player_position);
    const spawn_position = player_position.add(aim_direction.multiply(.init(32, 32)));
    const target_position = spawn_position.add(aim_direction);

    try self.handleAttackInput(weapon, hands, stats, dashing, spawn_position, target_position);
}

fn handleWeaponSwitch(self: *Self, hands: *Hands) ?*Weapon {
    const initial_weapon = self.currentWeapon() orelse return null;
    const switch_requested = lm.keyboard.getKeyDown(.tab) or lm.gamepad.getButtonDown(0, .right_trigger_1);
    if (!switch_requested) return initial_weapon;

    self.current_weapon_number +%= 1;
    const next_weapon = self.currentWeapon() orelse return null;
    hands.play(next_weapon.*) catch {};
    return next_weapon;
}

fn updateAndCastSpells(self: *Self, entity: *lm.Entity) void {
    const delta_seconds = lm.time.deltaTime();
    for (std.enums.values(Spell.Slot)) |slot| {
        const spell = self.getSpellPtr(slot) orelse continue;
        spell.update(delta_seconds);
    }

    const left_cast_pressed = lm.keyboard.getKeyDown(.q) or lm.gamepad.getButtonDown(0, .right_face_left);
    if (left_cast_pressed) self.tryCastSpellSlot(entity, .left);

    const right_cast_pressed = lm.keyboard.getKeyDown(.e) or lm.gamepad.getButtonDown(0, .right_face_up);
    if (right_cast_pressed) self.tryCastSpellSlot(entity, .right);
}

fn tryCastSpellSlot(self: *Self, entity: *lm.Entity, slot: Spell.Slot) void {
    const spell = self.getSpellPtr(slot) orelse return;
    if (spell.cast(entity)) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.7, 0.15);
    }
}

fn resolveCurrentAimDirection(self: *Self, camera: *lm.Camera, player_position: lm.Vector2) lm.Vector2 {
    if (lm.gamepad.isAvailable(0)) {
        const gamepad_stick = lm.gamepad.getStickVector(0, .right, 0.1);
        if (gamepad_stick.length() > 0) {
            const normalized = gamepad_stick.normalize();
            self.last_aim_direction = normalized;
            return normalized;
        }
    }

    const control_scheme = ControlScheme.getControlScheme();
    const arrow_vector = ControlScheme.getArrowVector();
    const mouse_world_position = camera.screenToWorldPos(lm.mouse.getPosition());
    const mouse_difference = mouse_world_position.subtract(player_position);
    const resolved = resolveAimDirection(control_scheme, arrow_vector, mouse_difference, self.last_aim_direction);
    self.last_aim_direction = resolved;
    return resolved;
}

fn handleAttackInput(
    self: *Self,
    weapon: *Weapon,
    hands: *Hands,
    stats: *Stats,
    dashing: *Dashing,
    spawn_position: lm.Vector2,
    target_position: lm.Vector2,
) !void {
    if (self.cooldown != 0 or stats.isStunned()) return;

    const control_scheme = ControlScheme.getControlScheme();
    const arrow_vector = ControlScheme.getArrowVector();
    const is_arrow_active = arrow_vector.length() > 0 and (ControlScheme.isAnyArrowKeyPressed() or ControlScheme.isAnyArrowKeyHeld());
    const is_shift_modifier = ControlScheme.isShiftModifierActive();

    const is_heavy_requested = (is_arrow_active and is_shift_modifier) or
        (control_scheme == .keyboard_and_mouse and lm.mouse.getButtonDown(.right)) or
        lm.gamepad.getButtonDown(0, .left_trigger_2);

    if (is_heavy_requested) {
        try self.executeHeavyAttack(weapon, hands, stats, spawn_position, target_position);
        return;
    }

    const is_light_requested = (is_arrow_active and !is_shift_modifier) or
        (control_scheme == .keyboard_and_mouse and lm.mouse.getButtonDown(.left)) or
        lm.gamepad.getButtonDown(0, .right_trigger_2);

    if (is_light_requested) {
        try self.executeLightAttack(weapon, hands, stats, dashing, spawn_position, target_position);
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
        .id = "attack_commitment_root",
        .effect_type = .root,
        .duration = 0.075,
        .visual = .{},
    });

    try hands.play(weapon.*);
    AudioManager.playSfxPitched("audio/sfx/punch.mp3", 0.7, 0.1);

    if (dashing.isDashing()) {
        try weapon.dashAttack(spawn_position, target_position, stats.*);
        return;
    }

    try weapon.lightAttack(spawn_position, target_position, stats.*);
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
        .id = "attack_commitment_root",
        .effect_type = .root,
        .duration = 0.12,
        .visual = .{},
    });

    try hands.play(weapon.*);
    AudioManager.playSfxPitched("audio/sfx/punch.mp3", 0.95, 0.15);

    try weapon.heavyAttack(spawn_position, target_position, stats.*);
}

pub fn currentWeapon(self: *Self) ?*Weapon {
    return &(self.equipped_weapons[self.current_weapon_number] orelse return null);
}

pub fn getSpell(self: *const Self, slot: Spell.Slot) ?Spell {
    return self.equipped_spells[@intFromEnum(slot)];
}

pub fn getSpellPtr(self: *Self, slot: Spell.Slot) ?*Spell {
    return &(self.equipped_spells[@intFromEnum(slot)] orelse return null);
}

/// Resolves the 2D aim direction according to the active control scheme and inputs.
pub fn resolveAimDirection(
    scheme: ControlScheme.ControlScheme,
    arrow_vector: lm.Vector2,
    mouse_difference: lm.Vector2,
    fallback_direction: lm.Vector2,
) lm.Vector2 {
    if (arrow_vector.length() > 0) {
        return arrow_vector.normalize();
    }

    if (scheme == .keyboard_only) {
        return fallback_direction;
    }

    if (mouse_difference.length() > 0) {
        return mouse_difference.normalize();
    }

    return fallback_direction;
}

pub fn reduceSpellCooldowns(self: *Self, amount_seconds: f32) void {
    for (std.enums.values(Spell.Slot)) |slot| {
        const spell = self.getSpellPtr(slot) orelse continue;
        spell.reduceCooldown(amount_seconds);
    }
}

pub fn getWeaponById(self: *Self, id: []const u8) ?*Weapon {
    for (&self.equipped_weapons) |*maybe_weapon| {
        const weapon = &(maybe_weapon.* orelse continue);
        if (std.mem.eql(u8, weapon.id, id)) {
            return weapon;
        }
    }
    return null;
}

pub fn hasWeaponId(self: *const Self, id: []const u8) bool {
    for (self.equipped_weapons) |maybe_weapon| {
        const weapon = maybe_weapon orelse continue;
        if (std.mem.eql(u8, weapon.id, id)) return true;
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
    const mouse_difference = lm.Vec2(100, 200);

    const up_direction = resolveAimDirection(.keyboard_only, .init(0, -1), mouse_difference, fallback);
    try std.testing.expectApproxEqAbs(@as(f32, 0), up_direction.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1), up_direction.y, 0.001);

    const up_right_direction = resolveAimDirection(.keyboard_only, .init(1, -1), mouse_difference, fallback);
    const expected_diagonal: f32 = std.math.sqrt(@as(f32, 0.5));
    try std.testing.expectApproxEqAbs(expected_diagonal, up_right_direction.x, 0.001);
    try std.testing.expectApproxEqAbs(-expected_diagonal, up_right_direction.y, 0.001);

    const fallback_direction = resolveAimDirection(.keyboard_only, .init(0, 0), mouse_difference, fallback);
    try std.testing.expectApproxEqAbs(@as(f32, 1), fallback_direction.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), fallback_direction.y, 0.001);
}

test "Attack.resolveAimDirection in keyboard_and_mouse mode prioritizes arrows then mouse" {
    const fallback = lm.Vec2(0, 1);
    const mouse_difference = lm.Vec2(100, 0);

    const mouse_aim = resolveAimDirection(.keyboard_and_mouse, .init(0, 0), mouse_difference, fallback);
    try std.testing.expectApproxEqAbs(@as(f32, 1), mouse_aim.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), mouse_aim.y, 0.001);

    const arrow_aim = resolveAimDirection(.keyboard_and_mouse, .init(-1, 0), mouse_difference, fallback);
    try std.testing.expectApproxEqAbs(@as(f32, -1), arrow_aim.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), arrow_aim.y, 0.001);
}
