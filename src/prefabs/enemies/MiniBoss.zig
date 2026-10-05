const lm = @import("loom");
const Knight = @import("Knight.zig").KnightEnemy;
const Bishop = @import("Bishop.zig").BishopEnemy;

var toggle_alternate: bool = false;

pub fn MiniBossEnemy(position: lm.Vector2) !*lm.Entity {
    toggle_alternate = !toggle_alternate;
    if (toggle_alternate) {
        return try Knight(position);
    } else {
        return try Bishop(position);
    }
}
