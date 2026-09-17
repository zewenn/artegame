const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

pub const UiColor = [4]f32;

pub const InputDevice = enum {
    keyboard_mouse,
    gamepad,
};

pub const PromptAction = enum {
    interact,
    spell_0,
    spell_1,
    dash,
    attack_primary,
    attack_secondary,
    switch_weapon,
    pause,
    menu_select,
    menu_back,
    menu_navigate,
    tab_prev,
    tab_next,
};

pub const ActionPrompt = struct {
    label: []const u8,
    badge_background_color: UiColor,
    badge_border_color: UiColor,
    text_color: UiColor,
    is_controller_button: bool,
};

pub var current_device: InputDevice = .keyboard_mouse;
pub var test_override_device: ?InputDevice = null;

pub fn getDevice() InputDevice {
    return test_override_device orelse current_device;
}

pub fn isGamepad() bool {
    return getDevice() == .gamepad;
}

pub fn setDeviceForTest(device: ?InputDevice) void {
    test_override_device = device;
}

pub fn reset() void {
    current_device = .keyboard_mouse;
    test_override_device = null;
}

pub fn update() void {
    if (lm.gamepad.isAvailable(0)) {
        if (lm.gamepad.anyButton()) {
            current_device = .gamepad;
            return;
        }

        const stick_left = lm.gamepad.getStickVector(0, .left, 0.25);
        const stick_right = lm.gamepad.getStickVector(0, .right, 0.25);
        if (stick_left.x != 0 or stick_left.y != 0 or stick_right.x != 0 or stick_right.y != 0) {
            current_device = .gamepad;
            return;
        }

        const left_trigger = lm.gamepad.getAxisMovement(0, .left_trigger);
        const right_trigger = lm.gamepad.getAxisMovement(0, .right_trigger);
        if (left_trigger > -0.5 or right_trigger > -0.5) {
            current_device = .gamepad;
            return;
        }
    } else {
        current_device = .keyboard_mouse;
    }

    if (lm.keyboard.anyKey()) {
        current_device = .keyboard_mouse;
        return;
    }

    if (lm.keyboard.getKey(.w) or lm.keyboard.getKey(.a) or lm.keyboard.getKey(.s) or lm.keyboard.getKey(.d) or
        lm.keyboard.getKey(.space) or lm.keyboard.getKey(.escape) or lm.keyboard.getKey(.enter) or
        lm.keyboard.getKey(.q) or lm.keyboard.getKey(.e) or lm.keyboard.getKey(.f) or lm.keyboard.getKey(.tab))
    {
        current_device = .keyboard_mouse;
        return;
    }

    if (lm.mouse.getButtonDown(.left) or lm.mouse.getButtonDown(.right) or lm.mouse.getButtonDown(.middle)) {
        current_device = .keyboard_mouse;
        return;
    }

    if (lm.mouse.getWheelMove() != 0.0) {
        current_device = .keyboard_mouse;
        return;
    }

    const delta = lm.mouse.getDelta();
    if (delta.x * delta.x + delta.y * delta.y > 4.0) {
        current_device = .keyboard_mouse;
        return;
    }
}

pub fn getActionPrompt(action: PromptAction) ActionPrompt {
    return getDeviceActionPrompt(getDevice(), action);
}

pub fn getDeviceActionPrompt(device: InputDevice, action: PromptAction) ActionPrompt {
    const pad_green_background = ui.color(35, 145, 75, 250);
    const pad_green_border = ui.color(65, 200, 110, 255);

    const pad_red_background = ui.color(180, 40, 50, 250);
    const pad_red_border = ui.color(230, 70, 80, 255);

    const pad_blue_background = ui.color(35, 100, 210, 250);
    const pad_blue_border = ui.color(75, 140, 255, 255);

    const pad_yellow_background = ui.color(195, 145, 25, 250);
    const pad_yellow_border = ui.color(245, 195, 55, 255);

    const pad_bumper_background = ui.color(55, 60, 75, 250);
    const pad_bumper_border = ui.color(130, 140, 160, 220);

    const pad_trigger_background = ui.color(45, 50, 65, 250);
    const pad_trigger_border = ui.color(120, 130, 150, 220);

    const pad_navigation_background = ui.color(40, 45, 58, 240);
    const pad_navigation_border = ui.color(90, 100, 125, 200);

    return switch (device) {
        .keyboard_mouse => switch (action) {
            .interact => keyboardPrompt("F"),
            .spell_0 => keyboardPrompt("Q"),
            .spell_1 => keyboardPrompt("E"),
            .dash => keyboardPrompt("SPACE"),
            .attack_primary => keyboardPrompt("LMB"),
            .attack_secondary => keyboardPrompt("RMB"),
            .switch_weapon => keyboardPrompt("TAB"),
            .pause => keyboardPrompt("ESC"),
            .menu_select => keyboardPrompt("ENTER"),
            .menu_back => keyboardPrompt("ESC"),
            .menu_navigate => keyboardPrompt("WASD / ARROWS"),
            .tab_prev => keyboardPrompt("Q"),
            .tab_next => keyboardPrompt("E"),
        },
        .gamepad => switch (action) {
            .interact => gamepadPrompt("A", pad_green_background, pad_green_border),
            .spell_0 => gamepadPrompt("X", pad_blue_background, pad_blue_border),
            .spell_1 => gamepadPrompt("Y", pad_yellow_background, pad_yellow_border),
            .dash => gamepadPrompt("A", pad_green_background, pad_green_border),
            .attack_primary => gamepadPrompt("RT", pad_trigger_background, pad_trigger_border),
            .attack_secondary => gamepadPrompt("LT", pad_trigger_background, pad_trigger_border),
            .switch_weapon => gamepadPrompt("RB", pad_bumper_background, pad_bumper_border),
            .pause => gamepadPrompt("START", pad_navigation_background, pad_navigation_border),
            .menu_select => gamepadPrompt("A", pad_green_background, pad_green_border),
            .menu_back => gamepadPrompt("B", pad_red_background, pad_red_border),
            .menu_navigate => gamepadPrompt("D-PAD / L-STICK", pad_navigation_background, pad_navigation_border),
            .tab_prev => gamepadPrompt("LB", pad_bumper_background, pad_bumper_border),
            .tab_next => gamepadPrompt("RB", pad_bumper_background, pad_bumper_border),
        },
    };
}

fn keyboardPrompt(label: []const u8) ActionPrompt {
    return .{
        .label = label,
        .badge_background_color = ui.color(38, 44, 58, 240),
        .badge_border_color = ui.color(80, 92, 118, 220),
        .text_color = ui.color(240, 245, 255, 255),
        .is_controller_button = false,
    };
}

fn gamepadPrompt(label: []const u8, background_color: UiColor, border_color: UiColor) ActionPrompt {
    return .{
        .label = label,
        .badge_background_color = background_color,
        .badge_border_color = border_color,
        .text_color = ui.color(255, 255, 255, 255),
        .is_controller_button = true,
    };
}

// --------------------------------------------------------------------------------------------------
// Unit Tests
// --------------------------------------------------------------------------------------------------

test "DevicePrompts default device is keyboard_mouse" {
    reset();
    try std.testing.expectEqual(InputDevice.keyboard_mouse, getDevice());
    try std.testing.expect(!isGamepad());
}

test "DevicePrompts setDeviceForTest override lifecycle" {
    reset();
    defer reset();

    setDeviceForTest(.gamepad);
    try std.testing.expectEqual(InputDevice.gamepad, getDevice());
    try std.testing.expect(isGamepad());

    setDeviceForTest(.keyboard_mouse);
    try std.testing.expectEqual(InputDevice.keyboard_mouse, getDevice());
    try std.testing.expect(!isGamepad());

    setDeviceForTest(null);
    try std.testing.expectEqual(InputDevice.keyboard_mouse, getDevice());
}

test "DevicePrompts getActionPrompt resolves correct labels and button types" {
    reset();
    defer reset();

    setDeviceForTest(.keyboard_mouse);
    const keyboard_interact = getActionPrompt(.interact);
    try std.testing.expectEqualStrings("F", keyboard_interact.label);
    try std.testing.expect(!keyboard_interact.is_controller_button);

    const keyboard_spell_0 = getActionPrompt(.spell_0);
    try std.testing.expectEqualStrings("Q", keyboard_spell_0.label);

    const keyboard_spell_1 = getActionPrompt(.spell_1);
    try std.testing.expectEqualStrings("E", keyboard_spell_1.label);

    const keyboard_back = getActionPrompt(.menu_back);
    try std.testing.expectEqualStrings("ESC", keyboard_back.label);

    setDeviceForTest(.gamepad);
    const gamepad_interact = getActionPrompt(.interact);
    try std.testing.expectEqualStrings("A", gamepad_interact.label);
    try std.testing.expect(gamepad_interact.is_controller_button);

    const gamepad_spell_0 = getActionPrompt(.spell_0);
    try std.testing.expectEqualStrings("X", gamepad_spell_0.label);
    try std.testing.expect(gamepad_spell_0.is_controller_button);

    const gamepad_spell_1 = getActionPrompt(.spell_1);
    try std.testing.expectEqualStrings("Y", gamepad_spell_1.label);
    try std.testing.expect(gamepad_spell_1.is_controller_button);

    const gamepad_back = getActionPrompt(.menu_back);
    try std.testing.expectEqualStrings("B", gamepad_back.label);
    try std.testing.expect(gamepad_back.is_controller_button);

    const gamepad_tab_previous = getActionPrompt(.tab_prev);
    try std.testing.expectEqualStrings("LB", gamepad_tab_previous.label);

    const gamepad_tab_next = getActionPrompt(.tab_next);
    try std.testing.expectEqualStrings("RB", gamepad_tab_next.label);

    const gamepad_dash = getActionPrompt(.dash);
    try std.testing.expectEqualStrings("A", gamepad_dash.label);

    const gamepad_attack_primary = getActionPrompt(.attack_primary);
    try std.testing.expectEqualStrings("RT", gamepad_attack_primary.label);

    const gamepad_attack_secondary = getActionPrompt(.attack_secondary);
    try std.testing.expectEqualStrings("LT", gamepad_attack_secondary.label);

    const gamepad_switch_weapon = getActionPrompt(.switch_weapon);
    try std.testing.expectEqualStrings("RB", gamepad_switch_weapon.label);

    const gamepad_pause = getActionPrompt(.pause);
    try std.testing.expectEqualStrings("START", gamepad_pause.label);

    const gamepad_navigate = getActionPrompt(.menu_navigate);
    try std.testing.expectEqualStrings("D-PAD / L-STICK", gamepad_navigate.label);

    // Verify Xbox button colors (A: green, B: red, X: blue, Y: yellow)
    try std.testing.expectEqual(@as(f32, 35), gamepad_interact.badge_background_color[0]);
    try std.testing.expectEqual(@as(f32, 145), gamepad_interact.badge_background_color[1]);

    try std.testing.expectEqual(@as(f32, 180), gamepad_back.badge_background_color[0]);
    try std.testing.expectEqual(@as(f32, 40), gamepad_back.badge_background_color[1]);

    try std.testing.expectEqual(@as(f32, 35), gamepad_spell_0.badge_background_color[0]);
    try std.testing.expectEqual(@as(f32, 100), gamepad_spell_0.badge_background_color[1]);

    try std.testing.expectEqual(@as(f32, 195), gamepad_spell_1.badge_background_color[0]);
    try std.testing.expectEqual(@as(f32, 145), gamepad_spell_1.badge_background_color[1]);
}

test "DevicePrompts reset clears direct device changes" {
    reset();
    current_device = .gamepad;
    try std.testing.expect(isGamepad());

    reset();
    try std.testing.expect(!isGamepad());
    try std.testing.expectEqual(InputDevice.keyboard_mouse, getDevice());
}
