const lm = @import("loom");
const King = @import("King.zig").KingEnemy;
const Queen = @import("Queen.zig").QueenEnemy;

var toggle_alternate: bool = false;

pub fn BossEnemy(position: lm.Vector2) !*lm.Entity {
    toggle_alternate = !toggle_alternate;
    if (toggle_alternate) {
        return try King(position);
    } else {
        return try Queen(position);
    }
}
