const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.print("* Memory leak detected *\n", .{});
    }

    const allocator = gpa.allocator();
    var bytes: []u8 = &.{};
    defer allocator.free(bytes);

    rl.InitWindow(800, 800, "Nonogram");
    defer rl.CloseWindow();

    while (!rl.WindowShouldClose()) {
        // Detect file
        if (rl.IsFileDropped()) {
            var dropped: rl.FilePathList = rl.LoadDroppedFiles();
            defer rl.UnloadDroppedFiles(dropped);

            const file = try std.fs.openFileAbsoluteZ(
                @as([*:0]u8, @ptrCast(&(dropped.paths.*[0]))),
                .{},
            );
            defer file.close();

            if (bytes.len != 0) allocator.free(bytes);
            bytes = try allocator.alloc(u8, try file.getEndPos());
        }

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(rl.DARKGRAY);

        if (bytes.len == 0) {
            rl.DrawText("Drop puzzle file here", 200, 380, 20, rl.LIGHTGRAY);
        } else {
            rl.DrawText("File detected", 10, 380, 20, rl.LIGHTGRAY);
        }

        rl.EndDrawing();
    }
}
