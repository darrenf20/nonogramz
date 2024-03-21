pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const err = gpa.deinit();
        if (err == .leak) std.debug.print("<< MEMORY LEAK DETECTED >>\n", .{});
    }

    var data = puzzle.Data{ .allocator = allocator };
    defer data.deinit();

    // Window configuration
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(800, 800, "NonogramZ");
    defer rl.CloseWindow();
    rl.SetWindowMinSize(320, 240);
    rl.SetTargetFPS(10);

    // Main loop
    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_F)) {
            if (rl.IsWindowMaximized()) rl.RestoreWindow() else rl.MaximizeWindow();
        }

        if (rl.IsFileDropped()) {
            //if (data.bytes.len != 0) free_prob_grid(allocator, prob_grid);
            try data.init();
            //prob_grid = try create_prob_grid(data);
        }

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(rl.WHITE);

        const w = rl.GetScreenWidth();
        const h = rl.GetScreenHeight();

        if (data.bytes.len == 0) {
            const text = "Drop puzzle file here";
            const size = @divFloor(4 * w, 100);
            const len = rl.MeasureText(text, size);
            const x = @divFloor(w, 2) - @divFloor(len, 2);
            const y = @divFloor(h, 2) - @divFloor(size, 2);
            rl.DrawText(text, x, y, size, rl.GRAY);
        } else {
            data.evaluate_grid();
            const graph = gui.Graph.init(&data, w, h);
            graph.handle_mouse_button_input();
            try graph.draw();
        }

        rl.EndDrawing();
    }
}

const std = @import("std");
const puzzle = @import("puzzle");
const gui = @import("gui");
const maths = @import("maths");
const rl = @cImport({
    @cInclude("raylib.h");
});
