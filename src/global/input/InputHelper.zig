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
    badge_bg: UiColor,
    badge_border: UiColor,
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

        const lt = lm.gamepad.getAxisMovement(0, .left_trigger);
        const rt = lm.gamepad.getAxisMovement(0, .right_trigger);
        if (lt > -0.5 or rt > -0.5) {
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
    const pad_green_bg = ui.color(35, 145, 75, 250);
    const pad_green_border = ui.color(65, 200, 110, 255);

    const pad_red_bg = ui.color(180, 40, 50, 250);
    const pad_red_border = ui.color(230, 70, 80, 255);

    const pad_blue_bg = ui.color(35, 100, 210, 250);
    const pad_blue_border = ui.color(75, 140, 255, 255);

    const pad_yellow_bg = ui.color(195, 145, 25, 250);
    const pad_yellow_border = ui.color(245, 195, 55, 255);

    const pad_bumper_bg = ui.color(55, 60, 75, 250);
    const pad_bumper_border = ui.color(130, 140, 160, 220);

    const pad_trigger_bg = ui.color(45, 50, 65, 250);
    const pad_trigger_border = ui.color(120, 130, 150, 220);

    const pad_nav_bg = ui.color(40, 45, 58, 240);
    const pad_nav_border = ui.color(90, 100, 125, 200);

    return switch (device) {
        .keyboard_mouse => switch (action) {
            .interact => kbmPrompt("F"),
            .spell_0 => kbmPrompt("Q"),
            .spell_1 => kbmPrompt("E"),
            .dash => kbmPrompt("SPACE"),
            .attack_primary => kbmPrompt("LMB"),
            .attack_secondary => kbmPrompt("RMB"),
            .switch_weapon => kbmPrompt("TAB"),
            .pause => kbmPrompt("ESC"),
            .menu_select => kbmPrompt("ENTER"),
            .menu_back => kbmPrompt("ESC"),
            .menu_navigate => kbmPrompt("WASD / ARROWS"),
            .tab_prev => kbmPrompt("Q"),
            .tab_next => kbmPrompt("E"),
        },
        .gamepad => switch (action) {
            .interact => padPrompt("A", pad_green_bg, pad_green_border),
            .spell_0 => padPrompt("X", pad_blue_bg, pad_blue_border),
            .spell_1 => padPrompt("Y", pad_yellow_bg, pad_yellow_border),
            .dash => padPrompt("A", pad_green_bg, pad_green_border),
            .attack_primary => padPrompt("RT", pad_trigger_bg, pad_trigger_border),
            .attack_secondary => padPrompt("LT", pad_trigger_bg, pad_trigger_border),
            .switch_weapon => padPrompt("RB", pad_bumper_bg, pad_bumper_border),
            .pause => padPrompt("START", pad_nav_bg, pad_nav_border),
            .menu_select => padPrompt("A", pad_green_bg, pad_green_border),
            .menu_back => padPrompt("B", pad_red_bg, pad_red_border),
            .menu_navigate => padPrompt("D-PAD / L-STICK", pad_nav_bg, pad_nav_border),
            .tab_prev => padPrompt("LB", pad_bumper_bg, pad_bumper_border),
            .tab_next => padPrompt("RB", pad_bumper_bg, pad_bumper_border),
        },
    };
}

fn kbmPrompt(label: []const u8) ActionPrompt {
    return .{
        .label = label,
        .badge_bg = ui.color(38, 44, 58, 240),
        .badge_border = ui.color(80, 92, 118, 220),
        .text_color = ui.color(240, 245, 255, 255),
        .is_controller_button = false,
    };
}

fn padPrompt(label: []const u8, bg: UiColor, border: UiColor) ActionPrompt {
    return .{
        .label = label,
        .badge_bg = bg,
        .badge_border = border,
        .text_color = ui.color(255, 255, 255, 255),
        .is_controller_button = true,
    };
}

// --------------------------------------------------------------------------------------------------
// Unit Tests
// --------------------------------------------------------------------------------------------------

test "InputHelper default device is keyboard_mouse" {
    reset();
    try std.testing.expectEqual(InputDevice.keyboard_mouse, getDevice());
    try std.testing.expect(!isGamepad());
}

test "InputHelper setDeviceForTest override lifecycle" {
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

test "InputHelper getActionPrompt resolves correct labels and button types" {
    reset();
    defer reset();

    // Test Keyboard prompts
    setDeviceForTest(.keyboard_mouse);
    const kbm_interact = getActionPrompt(.interact);
    try std.testing.expectEqualStrings("F", kbm_interact.label);
    try std.testing.expect(!kbm_interact.is_controller_button);

    const kbm_spell0 = getActionPrompt(.spell_0);
    try std.testing.expectEqualStrings("Q", kbm_spell0.label);

    const kbm_spell1 = getActionPrompt(.spell_1);
    try std.testing.expectEqualStrings("E", kbm_spell1.label);

    const kbm_back = getActionPrompt(.menu_back);
    try std.testing.expectEqualStrings("ESC", kbm_back.label);

    // Test Gamepad prompts
    setDeviceForTest(.gamepad);
    const pad_interact = getActionPrompt(.interact);
    try std.testing.expectEqualStrings("A", pad_interact.label);
    try std.testing.expect(pad_interact.is_controller_button);

    const pad_spell0 = getActionPrompt(.spell_0);
    try std.testing.expectEqualStrings("X", pad_spell0.label);
    try std.testing.expect(pad_spell0.is_controller_button);

    const pad_spell1 = getActionPrompt(.spell_1);
    try std.testing.expectEqualStrings("Y", pad_spell1.label);
    try std.testing.expect(pad_spell1.is_controller_button);

    const pad_back = getActionPrompt(.menu_back);
    try std.testing.expectEqualStrings("B", pad_back.label);
    try std.testing.expect(pad_back.is_controller_button);

    const pad_tab_prev = getActionPrompt(.tab_prev);
    try std.testing.expectEqualStrings("LB", pad_tab_prev.label);

    const pad_tab_next = getActionPrompt(.tab_next);
    try std.testing.expectEqualStrings("RB", pad_tab_next.label);

    const pad_dash = getActionPrompt(.dash);
    try std.testing.expectEqualStrings("A", pad_dash.label);

    const pad_attack_primary = getActionPrompt(.attack_primary);
    try std.testing.expectEqualStrings("RT", pad_attack_primary.label);

    const pad_attack_secondary = getActionPrompt(.attack_secondary);
    try std.testing.expectEqualStrings("LT", pad_attack_secondary.label);

    const pad_switch_weapon = getActionPrompt(.switch_weapon);
    try std.testing.expectEqualStrings("RB", pad_switch_weapon.label);

    const pad_pause = getActionPrompt(.pause);
    try std.testing.expectEqualStrings("START", pad_pause.label);

    const pad_nav = getActionPrompt(.menu_navigate);
    try std.testing.expectEqualStrings("D-PAD / L-STICK", pad_nav.label);

    // Verify Xbox button colors
    // A button is green
    try std.testing.expectEqual(@as(f32, 35), pad_interact.badge_bg[0]);
    try std.testing.expectEqual(@as(f32, 145), pad_interact.badge_bg[1]);

    // B button is red
    try std.testing.expectEqual(@as(f32, 180), pad_back.badge_bg[0]);
    try std.testing.expectEqual(@as(f32, 40), pad_back.badge_bg[1]);

    // X button is blue
    try std.testing.expectEqual(@as(f32, 35), pad_spell0.badge_bg[0]);
    try std.testing.expectEqual(@as(f32, 100), pad_spell0.badge_bg[1]);

    // Y button is yellow/amber
    try std.testing.expectEqual(@as(f32, 195), pad_spell1.badge_bg[0]);
    try std.testing.expectEqual(@as(f32, 145), pad_spell1.badge_bg[1]);
}

test "InputHelper reset clears direct device changes" {
    reset();
    current_device = .gamepad;
    try std.testing.expect(isGamepad());

    reset();
    try std.testing.expect(!isGamepad());
    try std.testing.expectEqual(InputDevice.keyboard_mouse, getDevice());
}
