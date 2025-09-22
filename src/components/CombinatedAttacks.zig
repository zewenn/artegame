const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;
const TIMER = 0.1;

const Stats = @import("Stats.zig");
const Self = @This();

remaining_timer: f32 = 0,
cooldown: f32 = 0,
chain_count: usize = 0,

stats: ?*Stats = null,

arena: ?std.heap.ArenaAllocator = null,
allocator: ?std.mem.Allocator = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.arena = .init(lm.allocators.generic());
    self.allocator = self.arena.?.allocator();

    self.stats = try entity.pullComponent(Stats);
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);

    self.remaining_timer -= lm.time.deltaTime();
    self.cooldown -= lm.time.deltaTime();

    if (self.cooldown < 0) self.cooldown = 0;

    if (self.remaining_timer < 0) self.remaining_timer = 0;
    if (self.remaining_timer == 0) self.chain_count = 0;

    if (lm.input.getMouseDown(.left)) {
        self.remaining_timer = 1.25 / stats.current.attack_speed;

        if (self.cooldown < 0.25) {
            if (self.chain_count == 3)
                self.chain_count = 0
            else if (self.remaining_timer > 0)
                self.chain_count = @min(self.chain_count + 1, 3);
        } else {
            self.chain_count = 0;
        }

        self.cooldown = 1 / stats.current.attack_speed;
    }

    const allocator = self.allocator orelse return;
    const arena = &(self.arena orelse return);
    _ = arena.reset(.free_all);

    const text = try std.fmt.allocPrint(allocator, "Chain Count: {d}", .{self.chain_count});
    const cooldown_text = try std.fmt.allocPrint(allocator, "Cooldown: {d}", .{self.cooldown});

    ui.new(.{
        .id = .ID("chain-attack-count"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = 20, .y = 20 },
        },
        .layout = .{ .direction = .top_to_bottom },
    })({
        ui.text(text, .{});
        ui.text(cooldown_text, .{});
    });
}
