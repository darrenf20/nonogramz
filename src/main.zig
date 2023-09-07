const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const err = gpa.deinit();
        if (err == .leak) std.debug.print("<< MEMORY LEAK DETECTED >>\n", .{});
    }

    var data = Data{ .ally = allocator };
    defer data.deinit();

    // Window configuration
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(800, 800, "NonogramZ");
    defer rl.CloseWindow();
    rl.SetWindowMinSize(320, 240);
    rl.SetTargetFPS(60);

    // Main loop
    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_F)) {
            if (rl.IsWindowMaximized()) rl.RestoreWindow() else rl.MaximizeWindow();
        }
        if (rl.IsFileDropped()) try data.init();

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(rl.WHITE);

        const win_w = rl.GetScreenWidth();
        const win_h = rl.GetScreenHeight();

        if (data.bytes.len == 0) {
            const text = "Drop puzzle file here";
            const size = @divFloor(4 * win_w, 100);
            const len = rl.MeasureText(text, size);
            const x = @divFloor(win_w, 2) - @divFloor(len, 2);
            const y = @divFloor(win_h, 2) - @divFloor(size, 2);
            rl.DrawText(text, x, y, size, rl.GRAY);
        } else {
            const x = data.x_offset + @as(c_int, @intCast(data.col_info.len));
            const y = data.y_offset + @as(c_int, @intCast(data.row_info.len));
            //const window_scale =
            //    @as(f64, @floatFromInt(win_w)) / @as(f64, @floatFromInt(win_h));
            //const grid_scale =
            //    @as(f64, @floatFromInt(x)) / @as(f64, @floatFromInt(y));
            var size_x: c_int = @divFloor(@divFloor(9 * win_w, 10), x);
            var size_y: c_int = @divFloor(@divFloor(9 * win_h, 10), y);
            var size = @min(size_x, size_y);

            const gap = @divFloor(size, 15);
            data.draw_grid_lines(size, gap);
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
    //    var x: c_int = self.x_offset + 4 * gap;
    //    var y: c_int = gap;

    //    // Draw column number text
    //    for (self.col_info) |line| {
    //        y = gap;
    //        for (line) |num| {
    //            const txt = try self.bufZ(num);
    //            rl.DrawText(txt, x, y, size, rl.BLACK);
    //            y += size + gap;
    //        }
    //        x += size + gap;
    //    }

    //    // Draw row number text
    //    x = gap;
    //    for (self.row_info) |line| {
    //        y += size + gap;
    //        for (line) |num| {
    //            const txt = try self.bufZ(num);
    //            rl.DrawText(txt, x, y, size, rl.BLACK);
    //            x += size + gap;
    //        }
    //    }

    //    // Draw puzzle grid
    //    y = self.y_offset;
    //    for (self.grid, 1..) |row, i| {
    //        x = self.x_offset;
    //        for (row, 1..) |sq, j| {
    //            const colour = if (sq == 0) rl.WHITE else rl.BLACK;
    //            rl.DrawRectangle(x, y, size, size, colour);
    //            x += size + if (j % 5 == 0) 2 * gap else gap;
    //        }
    //        y += size + if (i % 5 == 0) 2 * gap else gap;
    //    }
    //}

    fn bufZ(self: *Data, num: usize) ![:0]u8 {
        const slice = try std.fmt.bufPrint(self.buffer, "{}", .{num});
        self.buffer[slice.len] = 0;
        return self.buffer[0..slice.len :0];
    }

    fn draw_grid_lines(self: Data, size: c_int, gap: c_int) void {
        const x_min = self.x_offset * (size + gap) + gap;
        const y_min = self.y_offset * (size + gap) + gap;

        const rows = @as(c_int, @intCast(self.row_info.len));
        const cols = @as(c_int, @intCast(self.col_info.len));

        const x_max = x_min + gap + cols * (size + gap) + (@divFloor(cols, 5) + 1) * gap;
        const y_max = y_min + gap + rows * (size + gap) + (@divFloor(rows, 5) + 1) * gap;

        var x: c_int = gap;
        var y: c_int = gap;

        // Draw horizontal lines for column numbers
        for (0..@as(usize, @intCast(self.y_offset))) |_| {
            for (0..@as(usize, @intCast(gap))) |_| {
                rl.DrawLine(x_min, y, x_max, y, rl.BLACK);
                y += 1;
            }
            y += size;
        }

        // Draw horizontal lines for puzzle space
        for (0..self.row_info.len + 1) |i| {
            const thickness = if (i % 5 == 0) 2 * gap else gap;
            for (0..@as(usize, @intCast(thickness))) |_| {
                rl.DrawLine(gap, y, x_max, y, rl.BLACK);
                y += 1;
            }
            y += size;
        }

        // Draw vertical lines for row numbers
        for (0..@as(usize, @intCast(self.x_offset))) |_| {
            for (0..@as(usize, @intCast(gap))) |_| {
                rl.DrawLine(x, y_min, x, y_max, rl.BLACK);
                x += 1;
            }
            x += size;
        }

        // Draw vertical lines for puzzle space
        for (0..self.col_info.len + 1) |i| {
            const thickness = if (i % 5 == 0) 2 * gap else gap;
            for (0..@as(usize, @intCast(thickness))) |_| {
                rl.DrawLine(x, gap, x, y_max, rl.BLACK);
                x += 1;
            }
            x += size;
        }
    }
};
