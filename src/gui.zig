pub const Graph = struct {
    data: *puzzle.Data,
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

    pub fn init(data: *puzzle.Data, win_w: c_int, win_h: c_int) Graph {
        const x_nums = data.x_nums;
        const y_nums = data.y_nums;
        const num_rows = data.row_info.len;
        const num_cols = data.col_info.len;
        const x = @as(c_int, @intCast(x_nums + num_cols));
        const y = @as(c_int, @intCast(y_nums + num_rows));
        var size_x: c_int = @divFloor(@divFloor(9 * win_w, 10), x);
        var size_y: c_int = @divFloor(@divFloor(9 * win_h, 10), y);
        const size = @max(1, @min(size_x, size_y));
        const gap = @max(1, @divFloor(size, 15));
        const x_len = x * (size + gap) +
            @as(c_int, @intCast((num_cols / 5) + 2)) * gap;
        const y_len = y * (size + gap) +
            @as(c_int, @intCast((num_rows / 5) + 2)) * gap;
        const x0 = @divFloor(win_w - x_len, 2);
        const y0 = @divFloor(win_h - y_len, 2);

        return Graph{
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

    pub fn draw(self: Graph) !void {
        self.shade_number_sections();
        self.draw_grid_lines();
        try self.draw_numbers(); // get rid of error check?
        self.draw_tiles();
    }

    pub fn shade_number_sections(self: Graph) void {
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

    pub fn draw_grid_lines(self: Graph) void {
        // Draw horizontal lines
        var y: c_int = self.y0;
        for (0..self.y_nums + self.num_rows + 1) |i| {
            var thickness: c_int = self.gap;
            if (i >= self.y_nums and (i - self.y_nums) % 5 == 0) thickness *= 2;
            rl.DrawRectangle(self.x0, y, self.x_len, thickness, rl.BLACK);
            y += thickness + self.size;
        }

        // Draw vertical lines
        var x: c_int = self.x0;
        for (0..self.x_nums + self.num_cols + 1) |i| {
            var thickness: c_int = self.gap;
            if (i >= self.x_nums and (i - self.x_nums) % 5 == 0) thickness *= 2;
            rl.DrawRectangle(x, self.y0, thickness, self.y_len, rl.BLACK);
            x += thickness + self.size;
        }

        // Blank out the upper-left corner
        const w = @as(c_int, @intCast(self.x_nums)) * (self.size + self.gap);
        const h = @as(c_int, @intCast(self.y_nums)) * (self.size + self.gap);
        rl.DrawRectangle(self.x0, self.y0, w, h, rl.WHITE);
    }

    pub fn draw_numbers(self: Graph) !void {
        const sq = self.size + self.gap;

        for (self.data.row_info, 0..) |line, i_| {
            const i = @as(c_int, @intCast(i_));

            for (line, 0..) |num, j_| {
                const j = @as(c_int, @intCast(self.x_nums - line.len + j_));
                const text = try bufZ(num);
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
                const text = try bufZ(num);
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

    pub fn draw_tiles(self: Graph) void {
        const fill = if (self.data.is_solved) rl.VIOLET else rl.BLACK;
        const len = self.size - 2 * self.gap;

        for (self.data.grid, 0..) |row, i| {
            for (row, 0..) |sq, j| {
                const pos = self.screen_from_grid(i, j);
                const x = pos[0] + 2 * self.gap;
                const y = pos[1] + 2 * self.gap;

                if (sq == .cross) {
                    var a: rl.Vector2 = .{
                        .x = @floatFromInt(x),
                        .y = @floatFromInt(y),
                    };
                    var b: rl.Vector2 = .{
                        .x = @floatFromInt(x + len),
                        .y = @floatFromInt(y + len),
                    };
                    rl.DrawLineEx(a, b, @floatFromInt(self.gap), rl.GRAY);

                    a = .{
                        .x = @floatFromInt(x),
                        .y = @floatFromInt(y + len),
                    };
                    b = .{
                        .x = @floatFromInt(x + len),
                        .y = @floatFromInt(y),
                    };
                    rl.DrawLineEx(a, b, @floatFromInt(self.gap), rl.GRAY);
                } else {
                    const colour = if (sq == .blank) rl.WHITE else fill;
                    rl.DrawRectangle(x, y, len, len, colour);
                }
            }
        }
    }

    fn bufZ(num: usize) ![:0]u8 {
        const S = struct {
            var buffer: [4]u8 = undefined;
        };
        const slice = try std.fmt.bufPrint(&S.buffer, "{}", .{num});
        S.buffer[slice.len] = 0;
        return S.buffer[0..slice.len :0];
    }

    fn grid_from_screen(self: Graph, x: c_int, y: c_int) ?[2]usize {
        const sq = self.size + self.gap;
        const x0 = self.x0 + @as(c_int, @intCast(self.x_nums)) * sq + self.gap;
        const y0 = self.y0 + @as(c_int, @intCast(self.y_nums)) * sq + self.gap;
        const x1 = self.x0 + self.x_len - self.gap - 1;
        const y1 = self.y0 + self.y_len - self.gap - 1;

        if (x < x0 or x > x1 or y < y0 or y > y1) return null;
        const i = @divFloor(y - y0 - @divFloor(y, 5 * sq) * self.gap, sq);
        const j = @divFloor(x - x0 - @divFloor(x, 5 * sq) * self.gap, sq);
        if (i < 0 or j < 0) return null;

        return [2]usize{ @as(usize, @intCast(i)), @as(usize, @intCast(j)) };
    }

    fn screen_from_grid(self: Graph, i: usize, j: usize) [2]c_int {
        const sq = self.size + self.gap;
        const x0 = self.x0 + @as(c_int, @intCast(self.x_nums)) * sq + self.gap;
        const y0 = self.y0 + @as(c_int, @intCast(self.y_nums)) * sq + self.gap;

        const ci = @as(c_int, @intCast(i));
        const cj = @as(c_int, @intCast(j));

        const x = x0 + cj * sq + @divFloor(cj, 5) * self.gap;
        const y = y0 + ci * sq + @divFloor(ci, 5) * self.gap;
        return [2]c_int{ x, y };
    }

    pub fn handle_mouse_button_input(self: Graph) void {
        const mouse_x = rl.GetMouseX();
        const mouse_y = rl.GetMouseY();

        if (self.grid_from_screen(mouse_x, mouse_y)) |pos| {
            var state: ?puzzle.State = null;
            if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) state = .cross;
            if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) state = .square;
            if (state) |symbol| {
                const sq = &self.data.grid[pos[0]][pos[1]];
                sq.* = if (sq.* == symbol) .blank else symbol;
            }
        }
    }
};

const std = @import("std");
const puzzle = @import("puzzle");
const rl = @cImport({
    @cInclude("raylib.h");
});
