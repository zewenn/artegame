const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const ControlScheme = @import("ControlScheme.zig");

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

pub const PromptStyle = struct {
    badge_background_color: UiColor,
    badge_border_color: UiColor,
    text_color: UiColor,
    is_controller_button: bool,
};

pub const PromptBinding = struct {
    keyboard_and_mouse_label: []const u8,
    keyboard_only_label: ?[]const u8 = null,
    gamepad_label: []const u8,
    gamepad_style: PromptStyle,
};

const keyboard_style: PromptStyle = .{
    .badge_background_color = ui.color(38, 44, 58, 240),
    .badge_border_color = ui.color(80, 92, 118, 220),
    .text_color = ui.color(240, 245, 255, 255),
    .is_controller_button = false,
};

fn gamepadStyle(background_color: UiColor, border_color: UiColor) PromptStyle {
    return .{
        .badge_background_color = background_color,
        .badge_border_color = border_color,
        .text_color = ui.color(255, 255, 255, 255),
        .is_controller_button = true,
    };
}

const pad_green_style = gamepadStyle(ui.color(35, 145, 75, 250), ui.color(65, 200, 110, 255));
const pad_red_style = gamepadStyle(ui.color(180, 40, 50, 250), ui.color(230, 70, 80, 255));
const pad_blue_style = gamepadStyle(ui.color(35, 100, 210, 250), ui.color(75, 140, 255, 255));
const pad_yellow_style = gamepadStyle(ui.color(195, 145, 25, 250), ui.color(245, 195, 55, 255));
const pad_bumper_style = gamepadStyle(ui.color(55, 60, 75, 250), ui.color(130, 140, 160, 220));
const pad_trigger_style = gamepadStyle(ui.color(45, 50, 65, 250), ui.color(120, 130, 150, 220));
const pad_navigation_style = gamepadStyle(ui.color(40, 45, 58, 240), ui.color(90, 100, 125, 200));

const action_bindings: std.EnumArray(PromptAction, PromptBinding) = .init(.{
    .interact = .{
        .keyboard_and_mouse_label = "F",
        .gamepad_label = "A",
        .gamepad_style = pad_green_style,
    },
    .spell_0 = .{
        .keyboard_and_mouse_label = "Q",
        .gamepad_label = "X",
        .gamepad_style = pad_blue_style,
    },
    .spell_1 = .{
        .keyboard_and_mouse_label = "E",
        .gamepad_label = "Y",
        .gamepad_style = pad_yellow_style,
    },
    .dash = .{
        .keyboard_and_mouse_label = "SPACE",
        .gamepad_label = "A",
        .gamepad_style = pad_green_style,
    },
    .attack_primary = .{
        .keyboard_and_mouse_label = "LMB",
        .keyboard_only_label = "ARROWS",
        .gamepad_label = "RT",
        .gamepad_style = pad_trigger_style,
    },
    .attack_secondary = .{
        .keyboard_and_mouse_label = "RMB",
        .keyboard_only_label = "SHIFT+ARROWS",
        .gamepad_label = "LT",
        .gamepad_style = pad_trigger_style,
    },
    .switch_weapon = .{
        .keyboard_and_mouse_label = "TAB",
        .gamepad_label = "RB",
        .gamepad_style = pad_bumper_style,
    },
    .pause = .{
        .keyboard_and_mouse_label = "ESC",
        .gamepad_label = "START",
        .gamepad_style = pad_navigation_style,
    },
    .menu_select = .{
        .keyboard_and_mouse_label = "ENTER",
        .gamepad_label = "A",
        .gamepad_style = pad_green_style,
    },
    .menu_back = .{
        .keyboard_and_mouse_label = "ESC",
        .gamepad_label = "B",
        .gamepad_style = pad_red_style,
    },
    .menu_navigate = .{
        .keyboard_and_mouse_label = "WASD / ARROWS",
        .gamepad_label = "D-PAD / L-STICK",
        .gamepad_style = pad_navigation_style,
    },
    .tab_prev = .{
        .keyboard_and_mouse_label = "Q",
        .gamepad_label = "LB",
        .gamepad_style = pad_bumper_style,
    },
    .tab_next = .{
        .keyboard_and_mouse_label = "E",
        .gamepad_label = "RB",
        .gamepad_style = pad_bumper_style,
    },
});

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

fn isGamepadActive() bool {
    if (!lm.gamepad.isAvailable(0)) return false;
    if (lm.gamepad.anyButton()) return true;

    const stick_left = lm.gamepad.getStickVector(0, .left, 0.25);
    const stick_right = lm.gamepad.getStickVector(0, .right, 0.25);
    if (stick_left.x != 0 or stick_left.y != 0 or stick_right.x != 0 or stick_right.y != 0) {
        return true;
    }

    const left_trigger = lm.gamepad.getAxisMovement(0, .left_trigger);
    const right_trigger = lm.gamepad.getAxisMovement(0, .right_trigger);
    return left_trigger > -0.5 or right_trigger > -0.5;
}

fn isKeyboardOrMouseActive() bool {
    if (lm.keyboard.anyKey()) return true;

    const tracked_keys = [_]lm.deps.rl.KeyboardKey{
        .w, .a, .s, .d, .space, .escape, .enter, .q, .e, .f, .tab,
    };
    for (tracked_keys) |key| {
        if (lm.keyboard.getKey(key)) return true;
    }

    if (lm.mouse.getButtonDown(.left) or lm.mouse.getButtonDown(.right) or lm.mouse.getButtonDown(.middle)) {
        return true;
    }
    if (lm.mouse.getWheelMove() != 0.0) return true;

    const mouse_delta = lm.mouse.getDelta();
    return (mouse_delta.x * mouse_delta.x + mouse_delta.y * mouse_delta.y) > 4.0;
}

/// Updates the active input device globally every frame based on recent user input.
pub fn Update() void {
    if (isGamepadActive()) {
        current_device = .gamepad;
        return;
    }

    if (!lm.gamepad.isAvailable(0) or isKeyboardOrMouseActive()) {
        current_device = .keyboard_mouse;
    }
}

pub fn getActionPrompt(action: PromptAction) ActionPrompt {
    return getDeviceActionPrompt(getDevice(), action);
}

pub fn getDeviceActionPrompt(device: InputDevice, action: PromptAction) ActionPrompt {
    const binding = action_bindings.get(action);
    return switch (device) {
        .keyboard_mouse => buildPrompt(
            resolveKeyboardLabel(binding),
            keyboard_style,
        ),
        .gamepad => buildPrompt(
            binding.gamepad_label,
            binding.gamepad_style,
        ),
    };
}

fn resolveKeyboardLabel(binding: PromptBinding) []const u8 {
    if (ControlScheme.getControlScheme() == .keyboard_only) {
        return binding.keyboard_only_label orelse binding.keyboard_and_mouse_label;
    }
    return binding.keyboard_and_mouse_label;
}

fn buildPrompt(label: []const u8, style: PromptStyle) ActionPrompt {
    return .{
        .label = label,
        .badge_background_color = style.badge_background_color,
        .badge_border_color = style.badge_border_color,
        .text_color = style.text_color,
        .is_controller_button = style.is_controller_button,
    };
}

test "DevicePrompts respects ControlScheme in keyboard_mouse mode" {
    reset();
    ControlScheme.reset();
    defer {
        reset();
        ControlScheme.reset();
    }

    setDeviceForTest(.keyboard_mouse);
    ControlScheme.setControlSchemeForTest(.keyboard_and_mouse);
    try std.testing.expectEqualStrings("LMB", getActionPrompt(.attack_primary).label);
    try std.testing.expectEqualStrings("RMB", getActionPrompt(.attack_secondary).label);

    ControlScheme.setControlSchemeForTest(.keyboard_only);
    try std.testing.expectEqualStrings("ARROWS", getActionPrompt(.attack_primary).label);
    try std.testing.expectEqualStrings("SHIFT+ARROWS", getActionPrompt(.attack_secondary).label);
}
