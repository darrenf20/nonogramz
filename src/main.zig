const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    rl.InitWindow(800, 600, "Nonogram-Zig");

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.RAYWHITE);
        rl.DrawText("Nonogram", 190, 200, 20, rl.LIGHTGRAY);
        rl.EndDrawing();
    }

    defer rl.CloseWindow();
}
