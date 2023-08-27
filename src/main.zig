const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    rl.InitWindow(800, 800, "File Drop");
    defer rl.CloseWindow();

    var filepath: [2048]u8 = undefined;
    var has_file: bool = false;

    while (!rl.WindowShouldClose()) {
        // Detect file
        if (rl.IsFileDropped()) {
            var dropped: rl.FilePathList = rl.LoadDroppedFiles();
            defer rl.UnloadDroppedFiles(dropped);
            @memcpy(&filepath, @as([*]u8, @ptrCast(&(dropped.paths.*[0]))));
            has_file = true;
        }

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(rl.DARKGRAY);

        if (!has_file) {
            rl.DrawText("Drop file here", 200, 380, 20, rl.LIGHTGRAY);
        } else {
            rl.DrawText(@as([*c]const u8, &filepath), 10, 380, 20, rl.LIGHTGRAY);
        }

        rl.EndDrawing();
    }
}
