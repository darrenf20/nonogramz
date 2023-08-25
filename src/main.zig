const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    rl.InitWindow(800, 800, "Nonogram-Zig");
    defer rl.CloseWindow();

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.DARKGRAY);
        rl.DrawText("Nonogram", 300, 380, 40, rl.LIGHTGRAY);
        rl.EndDrawing();
    }
}
