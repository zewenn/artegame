const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");
const AudioManager = @import("../../global/audio/AudioManager.zig");

const Self = @This();

const FOOTSTEP_INTERVAL_SECONDS: f32 = 0.35;

footstep_timer_seconds: f32 = 0,
stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,
animator: ?*lm.Animator = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.dashing = try entity.pullComponent(Dashing);
    self.animator = try entity.pullComponent(lm.Animator);
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) {
        lm.audio.stop("audio/sfx/walking.mp3");
        return;
    }

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const animator: *lm.Animator = try lm.ensureComponent(self.animator);

    if (dashing.isDashing() or !stats.canMove()) return;

    const move_vector = readMoveVector();

    if (isDashRequested()) {
        dashing.apply(move_vector);
        return;
    }

    try self.updateWalkAnimationAndAudio(animator, move_vector);

    const speed = stats.current.movement_speed;
    const displacement_pixels = move_vector
        .normalize()
        .multiply(lm.time.deltaTimeVector2())
        .multiply(.init(speed, speed));

    transform.position = transform.position.add(lm.vec2ToVec3(displacement_pixels));
}

fn readMoveVector() lm.Vector2 {
    var move_vector = lm.Vec2(0, 0);

    if (lm.keyboard.getKey(.w)) move_vector.y -= 1;
    if (lm.keyboard.getKey(.s)) move_vector.y += 1;
    if (lm.keyboard.getKey(.a)) move_vector.x -= 1;
    if (lm.keyboard.getKey(.d)) move_vector.x += 1;

    const gamepad_stick = lm.gamepad.getStickVector(0, .left, 0.1);
    if (gamepad_stick.length() != 0) {
        return gamepad_stick;
    }

    return move_vector;
}

fn isDashRequested() bool {
    return lm.keyboard.getKeyDown(.space) or
        lm.gamepad.getButtonDown(0, .right_face_down) or
        lm.gamepad.getButtonDown(0, .left_trigger_1);
}

fn updateWalkAnimationAndAudio(self: *Self, animator: *lm.Animator, move_vector: lm.Vector2) !void {
    if (move_vector.length() <= 0) {
        self.footstep_timer_seconds = 0.0;
        lm.audio.stop("audio/sfx/walking.mp3");
        return;
    }

    self.footstep_timer_seconds -= lm.time.deltaTime();
    if (self.footstep_timer_seconds <= 0) {
        AudioManager.playSfxPitched("audio/sfx/walking.mp3", 0.45, 0.15);
        self.footstep_timer_seconds = FOOTSTEP_INTERVAL_SECONDS;
    }

    if (move_vector.x <= 0) {
        animator.stop("walk-right");
        try animator.play("walk-left");
        return;
    }

    animator.stop("walk-left");
    try animator.play("walk-right");
}
