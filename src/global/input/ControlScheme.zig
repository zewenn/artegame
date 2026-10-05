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

/// Resolves an 8-directional normalized vector from raw arrow directional inputs.
/// Returns null when no keys are pressed or opposing keys cancel each other out.
pub fn resolveEightDirectionalVector(vector: lm.Vector2) ?lm.Vector2 {
    if (vector.length() == 0) return null;
    return vector.normalize();
}

test "ControlScheme default is keyboard_and_mouse and supports test overrides" {
    reset();
    defer reset();

    try std.testing.expectEqual(ControlScheme.keyboard_and_mouse, getControlScheme());
    try std.testing.expectEqualStrings("KEYBOARD & MOUSE", getControlScheme().displayName());

    setControlScheme(.keyboard_only);
    try std.testing.expectEqual(ControlScheme.keyboard_only, getControlScheme());
    try std.testing.expectEqualStrings("KEYBOARD ONLY", getControlScheme().displayName());

    setControlSchemeForTest(.keyboard_and_mouse);
    try std.testing.expectEqual(ControlScheme.keyboard_and_mouse, getControlScheme());

    setControlSchemeForTest(null);
    try std.testing.expectEqual(ControlScheme.keyboard_only, getControlScheme());
}

test "resolveEightDirectionalVector produces exact 8 cardinal/diagonal directions" {
    // Up
    const up_vector = resolveEightDirectionalVector(.init(0, -1));
    try std.testing.expect(up_vector != null);
    try std.testing.expectApproxEqAbs(@as(f32, 0), up_vector.?.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1), up_vector.?.y, 0.001);

    // Down
    const down_vector = resolveEightDirectionalVector(.init(0, 1));
    try std.testing.expect(down_vector != null);
    try std.testing.expectApproxEqAbs(@as(f32, 0), down_vector.?.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), down_vector.?.y, 0.001);

    // Left
    const left_vector = resolveEightDirectionalVector(.init(-1, 0));
    try std.testing.expect(left_vector != null);
    try std.testing.expectApproxEqAbs(@as(f32, -1), left_vector.?.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), left_vector.?.y, 0.001);

    // Right
    const right_vector = resolveEightDirectionalVector(.init(1, 0));
    try std.testing.expect(right_vector != null);
    try std.testing.expectApproxEqAbs(@as(f32, 1), right_vector.?.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), right_vector.?.y, 0.001);

    // Diagonal Up-Right
    const up_right_vector = resolveEightDirectionalVector(.init(1, -1));
    try std.testing.expect(up_right_vector != null);
    const diagonal_component: f32 = std.math.sqrt(@as(f32, 0.5));
    try std.testing.expectApproxEqAbs(diagonal_component, up_right_vector.?.x, 0.001);
    try std.testing.expectApproxEqAbs(-diagonal_component, up_right_vector.?.y, 0.001);

    // Diagonal Down-Left
    const down_left_vector = resolveEightDirectionalVector(.init(-1, 1));
    try std.testing.expect(down_left_vector != null);
    try std.testing.expectApproxEqAbs(-diagonal_component, down_left_vector.?.x, 0.001);
    try std.testing.expectApproxEqAbs(diagonal_component, down_left_vector.?.y, 0.001);

    // Opposing cancellation
    const canceled_vector = resolveEightDirectionalVector(.init(0, 0));
    try std.testing.expect(canceled_vector == null);
}
