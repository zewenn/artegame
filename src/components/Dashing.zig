const lm = @import("loom");

const Stats = @import("Stats.zig");
const Self = @This();

const DASH_STAMINA_COST: f32 = 50.0;
const STAMINA_REGENERATION_DELAY_SECONDS: f32 = 0.5;
const STAMINA_REGENERATION_AMOUNT_PER_TICK: f32 = 1.0;

const Dash = struct {
    direction: lm.Vector2,
    cooldown_seconds: f32,

    pub fn init(direction: lm.Vector2, cooldown_seconds: f32) Dash {
        return Dash{
            .direction = direction,
            .cooldown_seconds = cooldown_seconds,
        };
    }
};

transform: ?*lm.Transform = null,
stats: ?*Stats = null,

dashes: ?lm.List(Dash) = null,
last_dash_at_seconds: f32 = -1,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.dashes = .init(lm.allocators.scene());
    self.transform = try entity.pullComponent(lm.Transform);
    self.stats = try entity.pullComponent(Stats);
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const dashes = &(self.dashes orelse return);

    const active_dash_count = dashes.len();
    if (active_dash_count == 0) return;

    self.last_dash_at_seconds = lm.time.gameTime();

    for (1..active_dash_count + 1) |step| {
        const index = active_dash_count - step;
        const dash: *Dash = &dashes.items()[index];

        if (dash.cooldown_seconds < 0) dash.cooldown_seconds = 0;
        if (dash.cooldown_seconds == 0) {
            _ = dashes.swapRemove(index);
            continue;
        }

        dash.cooldown_seconds -= lm.time.deltaTime();

        const speed_pixels_per_second = stats.current.movement_speed * stats.current.dash_speed_multiplier;
        const displacement_pixels = dash.direction
            .multiply(lm.time.deltaTimeVector2())
            .multiply(lm.Vec2(speed_pixels_per_second, speed_pixels_per_second));

        transform.position = transform.position.add(lm.vec2ToVec3(displacement_pixels));
    }
}

pub fn Tick(self: *Self) !void {
    if (lm.time.gameTime() - self.last_dash_at_seconds < STAMINA_REGENERATION_DELAY_SECONDS) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    stats.current.stamina = @min(stats.max.stamina, stats.current.stamina + STAMINA_REGENERATION_AMOUNT_PER_TICK);
}

pub fn End(self: *Self) void {
    if (self.dashes) |*dashes| dashes.deinit();
    self.dashes = null;
}

pub fn apply(self: *Self, direction_vector: lm.Vector2) void {
    const stats = self.stats orelse return;
    if (self.isDashing()) return;
    if (stats.current.stamina < DASH_STAMINA_COST) return;

    const dashes = &(self.dashes orelse return);
    dashes.append(.init(direction_vector, stats.current.dash_time)) catch return;
    stats.current.stamina -= DASH_STAMINA_COST;
}

pub fn applyEx(self: *Self, direction_vector: lm.Vector2, cooldown_seconds: f32, reduce_stamina: bool) void {
    const stats = self.stats orelse return;
    const dashes = &(self.dashes orelse return);

    dashes.append(.init(direction_vector, cooldown_seconds)) catch return;
    if (reduce_stamina) {
        stats.current.stamina -= DASH_STAMINA_COST;
    }
}

pub inline fn isDashing(self: *Self) bool {
    const dashes = &(self.dashes orelse return false);
    return dashes.len() > 0;
}
