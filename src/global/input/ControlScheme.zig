const std = @import("std");
const lm = @import("loom");

/// Defines the input control scheme used for player aiming and attack mechanics.
pub const ControlScheme = enum {
    keyboard_and_mouse,
    keyboard_only,

    pub fn displayName(self: ControlScheme) []const u8 {
        return switch (self) {
            .keyboard_and_mouse => "KEYBOARD & MOUSE",
            .keyboard_only => "KEYBOARD ONLY",
        };
    }
};

pub var active_control_scheme: ControlScheme = .keyboard_and_mouse;
pub var test_override_scheme: ?ControlScheme = null;
var last_mouse_position = lm.vec2();

pub fn getControlScheme() ControlScheme {
    return test_override_scheme orelse active_control_scheme;
}

pub fn setControlScheme(scheme: ControlScheme) void {
    active_control_scheme = scheme;
}

pub fn setControlSchemeForTest(scheme: ?ControlScheme) void {
    test_override_scheme = scheme;
}

pub fn reset() void {
    active_control_scheme = .keyboard_and_mouse;
    test_override_scheme = null;
}

pub fn Update() void {
    const mouse_position = lm.mouse.getPosition();

    if (!mouse_position.equals(last_mouse_position)) {
        last_mouse_position = mouse_position;
        active_control_scheme = .keyboard_and_mouse;
        return;
    }

    if (!isAnyArrowKeyHeld() and !isAnyArrowKeyPressed()) return;

    active_control_scheme = .keyboard_only;
}

/// Reads the arrow keys and returns the combined 8-directional movement/aim vector.
pub fn getArrowVector() lm.Vector2 {
    var vector = lm.Vec2(0, 0);
    if (lm.keyboard.getKey(.up)) vector.y -= 1;
    if (lm.keyboard.getKey(.down)) vector.y += 1;
    if (lm.keyboard.getKey(.left)) vector.x -= 1;
    if (lm.keyboard.getKey(.right)) vector.x += 1;
    return vector;
}

/// Checks if any arrow key was pressed down on this frame.
pub fn isAnyArrowKeyPressed() bool {
    return lm.keyboard.getKeyDown(.up) or
        lm.keyboard.getKeyDown(.down) or
        lm.keyboard.getKeyDown(.left) or
        lm.keyboard.getKeyDown(.right);
}

/// Checks if any arrow key is currently held down.
pub fn isAnyArrowKeyHeld() bool {
    return lm.keyboard.getKey(.up) or
        lm.keyboard.getKey(.down) or
        lm.keyboard.getKey(.left) or
        lm.keyboard.getKey(.right);
}

/// Checks if either the left or right shift key is currently held down.
pub fn isShiftModifierActive() bool {
    return lm.keyboard.getKey(.left_shift) or lm.keyboard.getKey(.right_shift);
}
