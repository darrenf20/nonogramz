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
            const drawer = Drawer.init(&data, win_w, win_h);
            try drawer.draw();
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

    x_nums: usize = 0, // max number of blocks for a row
    y_nums: usize = 0, // max number of blocks for a column

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

        // Custom file format
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

            var offset: usize = 0;
            for (line.*) |*sq| {
                sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
                offset += 1;
            }
            if (offset > self.y_nums) self.y_nums = offset;
        }

        _ = iterator.next().?; // skip blank line
        for (self.row_info) |*line| {
            var str: []const u8 = iterator.next().?;
            num_it = std.mem.splitScalar(u8, str, ' ');

            var len = std.mem.count(u8, str, " ") + 1;
            line.* = try self.ally.alloc(usize, len);

            var offset: usize = 0;
            for (line.*) |*sq| {
                sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
                offset += 1;
            }
            if (offset > self.x_nums) self.x_nums = offset;
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

        self.x_nums = 0;
        self.y_nums = 0;
    }

    fn bufZ(self: *Data, num: usize) ![:0]u8 {
        const slice = try std.fmt.bufPrint(&self.buffer, "{}", .{num});
        self.buffer[slice.len] = 0;
        return self.buffer[0..slice.len :0];
    }
};

const Drawer = struct {
    data: *Data,
    x_nums: usize,
    y_nums: usize,
    num_rows: usize,
    num_cols: usize,
    x0: c_int,
    y0: c_int,
    x_len: c_int,
    y_len: c_int,
    size: c_int,
    gap: c_int,

    fn init(data: *Data, win_w: c_int, win_h: c_int) Drawer {
        const x_nums = data.x_nums;
        const y_nums = data.y_nums;
        const num_rows = data.row_info.len;
        const num_cols = data.col_info.len;
        const x = @as(c_int, @intCast(x_nums + num_cols));
        const y = @as(c_int, @intCast(y_nums + num_rows));
        var size_x: c_int = @divFloor(@divFloor(9 * win_w, 10), x);
        var size_y: c_int = @divFloor(@divFloor(9 * win_h, 10), y);
        const size = @max(4, @min(size_x, size_y));
        const gap = @max(1, @divFloor(size, 15));
        const x_len = x * (size + gap) +
            @as(c_int, @intCast((num_cols / 5) + 2)) * gap;
        const y_len = y * (size + gap) +
            @as(c_int, @intCast((num_rows / 5) + 2)) * gap;
        const x0 = @divFloor(win_w - x_len, 2);
        const y0 = @divFloor(win_h - y_len, 2);

        return Drawer{
            .data = data,
            .x_nums = x_nums,
            .y_nums = y_nums,
            .num_rows = num_rows,
            .num_cols = num_cols,
            .x0 = x0,
            .y0 = y0,
            .x_len = x_len,
            .y_len = y_len,
            .size = size,
            .gap = gap,
        };
    }

    fn draw(self: Drawer) !void {
        self.shade_number_sections();
        self.draw_grid_lines();
        try self.draw_numbers();
    }

    fn shade_number_sections(self: Drawer) void {
        const sq = (self.size + self.gap);
        const num_w =
            @as(c_int, @intCast(self.x_nums)) * (self.size + self.gap);
        const num_h =
            @as(c_int, @intCast(self.y_nums)) * (self.size + self.gap);

        // Shade the sections grey
        rl.DrawRectangle(self.x0, self.y0, self.x_len, num_h, rl.GRAY);
        rl.DrawRectangle(self.x0, self.y0, num_w, self.y_len, rl.GRAY);

        // Highlight the row and column for the square currently hovered over
        if (self.grid_from_screen(rl.GetMouseX(), rl.GetMouseY())) |g_pos| {
            const s_pos = self.screen_from_grid(g_pos[0], g_pos[1]);
            rl.DrawRectangle(self.x0, s_pos[1], num_w, sq, rl.LIGHTGRAY);
            rl.DrawRectangle(s_pos[0], self.y0, sq, num_h, rl.LIGHTGRAY);
        }
    }

    fn draw_grid_lines(self: Drawer) void {
        // Draw horizontal lines
        var y: c_int = self.y0;
        for (0..self.y_nums + self.num_rows + 1) |i| {
            var thick: c_int = self.gap;
            if (i >= self.y_nums and (i - self.y_nums) % 5 == 0) thick *= 2;
            rl.DrawRectangle(self.x0, y, self.x_len, thick, rl.BLACK);
            y += thick + self.size;
        }

        // Draw vertical lines
        var x: c_int = self.x0;
        for (0..self.x_nums + self.num_cols + 1) |i| {
            var thick: c_int = self.gap;
            if (i >= self.x_nums and (i - self.x_nums) % 5 == 0) thick *= 2;
            rl.DrawRectangle(x, self.y0, thick, self.y_len, rl.BLACK);
            x += thick + self.size;
        }

        // Blank out the upper-left corner
        const w = @as(c_int, @intCast(self.x_nums)) * (self.size + self.gap);
        const h = @as(c_int, @intCast(self.y_nums)) * (self.size + self.gap);
        rl.DrawRectangle(self.x0, self.y0, w, h, rl.WHITE);
    }

    fn draw_numbers(self: Drawer) !void {
        const sq = self.size + self.gap;

        for (self.data.row_info, 0..) |line, i_| {
            const i = @as(c_int, @intCast(i_));

            for (line, 0..) |num, j_| {
                const j = @as(c_int, @intCast(self.x_nums - line.len + j_));
                const text = try self.data.bufZ(num);
                const len = rl.MeasureText(text, self.size - 2 * self.gap);

                const x = self.x0 + j * sq +
                    @divFloor(self.size, 2) - @divFloor(len, 2);
                const y = self.y0 + 2 * self.gap +
                    @as(c_int, @intCast(self.y_nums)) * sq +
                    (i * sq) + @divFloor(i, 5) * self.gap;

                rl.DrawText(text, x, y, self.size, rl.BLACK);
            }
        }

        for (self.data.col_info, 0..) |line, j_| {
            const j = @as(c_int, @intCast(j_));

            for (line, 0..) |num, i_| {
                const i = @as(c_int, @intCast(self.y_nums - line.len + i_));
                const text = try self.data.bufZ(num);
                const len = rl.MeasureText(text, self.size - 2 * self.gap);

                const x = self.x0 + 2 * self.gap +
                    @as(c_int, @intCast(self.x_nums)) * sq +
                    (j * sq) + @divFloor(j, 5) * self.gap +
                    @divFloor(self.size, 2) - @divFloor(len, 2);
                const y = self.y0 + i * sq + 2 * self.gap;

                rl.DrawText(text, x, y, self.size, rl.BLACK);
            }
        }
    }

    fn grid_from_screen(self: Drawer, x: c_int, y: c_int) ?[2]c_int {
        const sq = self.size + self.gap;
        const x0 = self.x0 + @as(c_int, @intCast(self.x_nums)) * sq + self.gap;
        const y0 = self.y0 + @as(c_int, @intCast(self.y_nums)) * sq + self.gap;
        const x1 = self.x0 + self.x_len - self.gap - 1;
        const y1 = self.y0 + self.y_len - self.gap - 1;

        if (x < x0 or x > x1 or y < y0 or y > y1) return null;
        const i = @divFloor(y - y0 - @divFloor(y, 5 * sq) * self.gap, sq);
        const j = @divFloor(x - x0 - @divFloor(x, 5 * sq) * self.gap, sq);
        return [2]c_int{ i, j };
    }

    fn screen_from_grid(self: Drawer, i: c_int, j: c_int) [2]c_int {
        const sq = self.size + self.gap;
        const x0 = self.x0 + @as(c_int, @intCast(self.x_nums)) * sq + self.gap;
        const y0 = self.y0 + @as(c_int, @intCast(self.y_nums)) * sq + self.gap;

        const x = x0 + j * sq + @divFloor(j, 5) * self.gap;
        const y = y0 + i * sq + @divFloor(i, 5) * self.gap;
        return [2]c_int{ x, y };
    }
};
