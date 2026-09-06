const lm = @import("loom");
const Melee = @import("Melee.zig");

pub fn BasicEnemy(position: lm.Vector2) !*lm.Entity {
    return Melee.MeleeEnemy(position);
}
