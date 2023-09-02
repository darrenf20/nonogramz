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

    var data = Puzzle_Data{ .allocator = allocator };
    defer data.deinit();

    const win_w = 800;
    const win_h = 800;
    rl.InitWindow(win_w, win_h, "Nonogram");
    defer rl.CloseWindow();

    while (!rl.WindowShouldClose()) {
        if (rl.IsFileDropped()) try data.init();

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(rl.DARKGRAY);

        if (data.bytes.len == 0) {
            const text = "Drop puzzle file here";
            const size = 40;
            rl.DrawText(
                text,
                win_w / 2 - @divTrunc(rl.MeasureText(text, size), 2),
                win_h / 2 - (size / 2),
                size,
                rl.LIGHTGRAY,
            );
        } else {
            data.draw(win_w, win_h);
        }

        rl.EndDrawing();
    }
}

const Puzzle_Data = struct {
    allocator: std.mem.Allocator,
    bytes: []u8 = &.{},
    row_info: [][]usize = undefined,
    col_info: [][]usize = undefined,
    grid: [][]u1 = undefined,

    fn init(self: *Puzzle_Data) !void {
        self.deinit();

        var dropped: rl.FilePathList = rl.LoadDroppedFiles();
        const file = try std.fs.openFileAbsoluteZ(
            @as([*:0]u8, @ptrCast(&(dropped.paths.*[0]))),
            .{},
        );
        rl.UnloadDroppedFiles(dropped);
        self.bytes = try file.readToEndAlloc(
            self.allocator,
            try file.getEndPos(),
        );
        file.close();

        // Populate puzzle info
        // TODO: error checking, validation
        var iterator = std.mem.splitScalar(u8, self.bytes, '\n');
        var num_it = std.mem.splitScalar(u8, iterator.next().?, ',');
        var col_len = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
        var row_len = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);

        self.row_info = try self.allocator.alloc([]usize, row_len);
        self.col_info = try self.allocator.alloc([]usize, col_len);

        self.grid = try self.allocator.alloc([]u1, row_len);
        for (self.grid) |*row| {
            row.* = try self.allocator.alloc(u1, col_len);
            for (row.*) |*square| square.* = 0;
        }

        _ = iterator.next().?; // skip blank line
        for (self.col_info) |*line| {
            var slice: []const u8 = iterator.next().?;
            var len = std.mem.count(u8, slice, ",") + 1;
            line.* = try self.allocator.alloc(usize, len);
            num_it = std.mem.splitScalar(u8, slice, ',');
            for (line.*) |*sq| {
                sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
            }
        }

        _ = iterator.next().?; // skip blank line
        for (self.row_info) |*line| {
            var slice: []const u8 = iterator.next().?;
            var len = std.mem.count(u8, slice, ",") + 1;
            line.* = try self.allocator.alloc(usize, len);
            num_it = std.mem.splitScalar(u8, slice, ',');
            for (line.*) |*sq| {
                sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
            }
        }
    }

    fn deinit(self: *Puzzle_Data) void {
        if (self.bytes.len == 0) return;

        self.allocator.free(self.bytes);

        for (self.row_info) |line| self.allocator.free(line);
        self.allocator.free(self.row_info);

        for (self.col_info) |line| self.allocator.free(line);
        self.allocator.free(self.col_info);

        for (self.grid) |line| self.allocator.free(line);
        self.allocator.free(self.grid);
    }

    fn draw(self: Puzzle_Data, window_w: usize, window_h: usize) void {
        const size = @as(c_int, @intCast(@min(window_w, window_h) * 5 / 100));
        const gap: c_int = 5;
        const x0 = @as(c_int, @intCast(window_w / 10));
        var y = @as(c_int, @intCast(window_h / 10));

        for (self.grid, 1..) |row, i| {
            var x = x0;
            for (row, 1..) |sq, j| {
                const colour = if (sq == 0) rl.WHITE else rl.BLACK;
                rl.DrawRectangle(x, y, size, size, colour);
                x += size + if (j % 5 == 0) 2 * gap else gap;
            }
            y += size + if (i % 5 == 0) 2 * gap else gap;
        }
    }
};
