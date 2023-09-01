const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.print("* Memory leak detected *\n", .{});
    }

    var bytes: []u8 = &.{};
    var row_info: [][]usize = undefined;
    var col_info: [][]usize = undefined;
    var grid: [][]u1 = undefined;
    defer {
        if (bytes.len != 0) {
            allocator.free(bytes);

            for (row_info) |line| allocator.free(line);
            allocator.free(row_info);

            for (col_info) |line| allocator.free(line);
            allocator.free(col_info);

            for (grid) |line| allocator.free(line);
            allocator.free(grid);
        }
    }

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
            if (bytes.len != 0) allocator.free(bytes);
            bytes = try file.readToEndAlloc(allocator, try file.getEndPos());
            file.close();

            // Populate puzzle info
            var iterator = std.mem.splitScalar(u8, bytes, '\n');
            var num_it = std.mem.splitScalar(u8, iterator.next().?, ',');
            var col_len = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
            var row_len = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);

            row_info = try allocator.alloc([]usize, row_len);
            col_info = try allocator.alloc([]usize, col_len);

            grid = try allocator.alloc([]u1, row_len);
            for (grid) |*row| {
                row.* = try allocator.alloc(u1, col_len);
                for (row.*) |*square| square.* = 0;
            }

            _ = iterator.next().?; // skip blank line
            for (col_info) |*line| {
                var slice: []const u8 = iterator.next().?;
                var len = std.mem.count(u8, slice, ",") + 1;
                line.* = try allocator.alloc(usize, len);
                num_it = std.mem.splitScalar(u8, slice, ',');
                for (line.*) |*sq| {
                    sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
                }
            }

            _ = iterator.next().?; // skip blank line
            for (row_info) |*line| {
                var slice: []const u8 = iterator.next().?;
                var len = std.mem.count(u8, slice, ",") + 1;
                line.* = try allocator.alloc(usize, len);
                num_it = std.mem.splitScalar(u8, slice, ',');
                for (line.*) |*sq| {
                    sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
                }
            }
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

    // Debugging purposes -- remove
    if (bytes.len != 0) {
        std.debug.print("Column numbers:\n", .{});
        for (col_info) |line| {
            for (line) |sq| std.debug.print("{} ", .{sq});
            std.debug.print("\n", .{});
        }
        std.debug.print("\nRow numbers:\n", .{});
        for (row_info) |line| {
            for (line) |sq| std.debug.print("{} ", .{sq});
            std.debug.print("\n", .{});
        }
    }
}
