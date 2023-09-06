const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const ally = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.print("* Memory leak detected *\n", .{});
    }

    const win_w = 800;
    const win_h = 800;

    //const size = @as(c_int, @intCast(@min(win_w, win_h) * 4 / 100));
    const size: c_int = 50;
    const gap: c_int = @divFloor(size, 15);
    var data = Data{ .ally = ally, .size = size, .gap = gap };
    defer data.deinit();

    // Window configuration
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(win_w, win_h, "Nonogram");
    defer rl.CloseWindow();
    rl.SetWindowMinSize(320, 240);
    rl.SetTargetFPS(30);

    // Main loop
    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_F)) {
            if (rl.IsWindowMaximized()) rl.RestoreWindow() else rl.MaximizeWindow();
        }
        if (rl.IsFileDropped()) try data.init();

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(rl.WHITE);

        if (data.bytes.len == 0) {
            const text = "Drop puzzle file here";
            const sz = @divFloor(5 * rl.GetScreenWidth(), 100);
            const len = rl.MeasureText(text, sz);
            const x = @divFloor(rl.GetScreenWidth(), 2) - @divFloor(len, 2);
            const y = @divFloor(rl.GetScreenHeight(), 2) - @divFloor(sz, 2);
            rl.DrawText(text, x, y, sz, rl.GRAY);
        } else {
            //data.draw(win_w, win_h);
            data.draw_grid_lines();
        }

        rl.EndDrawing();
    }
}

const Data = struct {
    ally: std.mem.Allocator,

    bytes: []u8 = &.{},
    buffer: [4]u8 = undefined,

    row_info: [][]usize = undefined,
    col_info: [][]usize = undefined,
    grid: [][]u1 = undefined,

    size: c_int,
    gap: c_int,
    x_offset: c_int = 0,
    y_offset: c_int = 0,

    fn init(self: *Data) !void {
        self.deinit();

        var dropped: rl.FilePathList = rl.LoadDroppedFiles();
        const file = try std.fs.openFileAbsoluteZ(
            @as([*:0]u8, @ptrCast(&(dropped.paths.*[0]))), // simplify?
            .{},
        );
        rl.UnloadDroppedFiles(dropped);
        self.bytes = try file.readToEndAlloc(self.ally, try file.getEndPos());
        file.close();

        // Populate puzzle info
        // TODO: error checking, validation
        var iterator = std.mem.splitScalar(u8, self.bytes, '\n');
        var num_it = std.mem.splitScalar(u8, iterator.next().?, ' ');
        var col_len = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
        var row_len = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);

        self.row_info = try self.ally.alloc([]usize, row_len);
        self.col_info = try self.ally.alloc([]usize, col_len);

        // Zero-initialise grid
        self.grid = try self.ally.alloc([]u1, row_len);
        for (self.grid) |*row| {
            row.* = try self.ally.alloc(u1, col_len);
            for (row.*) |*square| square.* = 0;
        }

        _ = iterator.next().?; // skip blank line
        for (self.col_info) |*line| {
            var str: []const u8 = iterator.next().?;
            num_it = std.mem.splitScalar(u8, str, ' ');

            var len = std.mem.count(u8, str, " ") + 1;
            line.* = try self.ally.alloc(usize, len);

            var offset: c_int = 0;
            for (line.*) |*sq| {
                sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
                offset += 1;
            }
            if (offset > self.y_offset) self.y_offset = offset;
        }

        _ = iterator.next().?; // skip blank line
        for (self.row_info) |*line| {
            var str: []const u8 = iterator.next().?;
            num_it = std.mem.splitScalar(u8, str, ' ');

            var len = std.mem.count(u8, str, " ") + 1;
            line.* = try self.ally.alloc(usize, len);

            var offset: c_int = 0;
            for (line.*) |*sq| {
                sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
                offset += 1;
            }
            if (offset > self.x_offset) self.x_offset = offset;
        }
    }

    fn deinit(self: *Data) void {
        if (self.bytes.len == 0) return;

        self.ally.free(self.bytes);

        for (self.row_info) |line| self.ally.free(line);
        self.ally.free(self.row_info);

        for (self.col_info) |line| self.ally.free(line);
        self.ally.free(self.col_info);

        for (self.grid) |line| self.ally.free(line);
        self.ally.free(self.grid);

        self.x_offset = 0;
        self.y_offset = 0;
    }

    //fn draw(self: *Data) !void {
    //    var x: c_int = self.x_offset + 4 * self.gap;
    //    var y: c_int = self.gap;

    //    // Draw column number text
    //    for (self.col_info) |line| {
    //        y = self.gap;
    //        for (line) |num| {
    //            const txt = try self.bufZ(num);
    //            rl.DrawText(txt, x, y, self.size, rl.BLACK);
    //            y += self.size + self.gap;
    //        }
    //        x += self.size + self.gap;
    //    }

    //    // Draw row number text
    //    x = self.gap;
    //    for (self.row_info) |line| {
    //        y += self.size + self.gap;
    //        for (line) |num| {
    //            const txt = try self.bufZ(num);
    //            rl.DrawText(txt, x, y, self.size, rl.BLACK);
    //            x += self.size + self.gap;
    //        }
    //    }

    //    // Draw puzzle grid
    //    y = self.y_offset;
    //    for (self.grid, 1..) |row, i| {
    //        x = self.x_offset;
    //        for (row, 1..) |sq, j| {
    //            const colour = if (sq == 0) rl.WHITE else rl.BLACK;
    //            rl.DrawRectangle(x, y, self.size, self.size, colour);
    //            x += self.size + if (j % 5 == 0) 2 * self.gap else self.gap;
    //        }
    //        y += self.size + if (i % 5 == 0) 2 * self.gap else self.gap;
    //    }
    //}

    fn bufZ(self: *Data, num: usize) ![:0]u8 {
        const slice = try std.fmt.bufPrint(self.buffer, "{}", .{num});
        self.buffer[slice.len] = 0;
        return self.buffer[0..slice.len :0];
    }

    fn draw_grid_lines(self: Data) void {
        const x_min = self.x_offset * (self.size + self.gap) + self.gap;
        const y_min = self.y_offset * (self.size + self.gap) + self.gap;

        const rows = @as(c_int, @intCast(self.row_info.len));
        const cols = @as(c_int, @intCast(self.col_info.len));

        //const x_max =
        //    (self.x_offset + cols) * (self.size + self.gap) +
        //    @divFloor(cols, 5) * self.gap + self.gap;
        //const y_max =
        //    (self.y_offset + rows) * (self.size + self.gap) +
        //    @divFloor(rows, 5) * self.gap + self.gap;

        const x_max =
            x_min +
            cols * (self.size + self.gap) +
            (@divFloor(cols, 5) + 1) * self.gap;
        const y_max =
            y_min +
            rows * (self.size + self.gap) +
            (@divFloor(rows, 5) + 1) * self.gap;

        var x: c_int = self.gap;
        var y: c_int = self.gap;

        // Draw horizontal lines for column numbers
        for (0..@as(usize, @intCast(self.y_offset))) |_| {
            for (0..@as(usize, @intCast(self.gap))) |_| {
                rl.DrawLine(x_min, y, x_max, y, rl.BLACK);
                y += 1;
            }
            y += self.size;
        }

        // Draw horizontal lines for puzzle space
        for (0..self.row_info.len + 1) |i| {
            const thickness = if (i % 5 == 0) 2 * self.gap else self.gap;
            for (0..@as(usize, @intCast(thickness))) |_| {
                rl.DrawLine(self.gap, y, x_max, y, rl.BLACK);
                y += 1;
            }
            y += self.size;
        }

        // Draw vertical lines for row numbers
        for (0..@as(usize, @intCast(self.x_offset))) |_| {
            for (0..@as(usize, @intCast(self.gap))) |_| {
                rl.DrawLine(x, y_min, x, y_max, rl.BLACK);
                x += 1;
            }
            x += self.size;
        }

        // Draw vertical lines for puzzle space
        for (0..self.col_info.len + 1) |i| {
            const thickness = if (i % 5 == 0) 2 * self.gap else self.gap;
            for (0..@as(usize, @intCast(thickness))) |_| {
                rl.DrawLine(x, self.gap, x, y_max, rl.BLACK);
                x += 1;
            }
            x += self.size;
        }
    }
};
