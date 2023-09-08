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
            const x = @as(c_int, @intCast(data.x_nums + data.col_info.len));
            const y = @as(c_int, @intCast(data.y_nums + data.row_info.len));
            var size_x: c_int = @divFloor(@divFloor(9 * win_w, 10), x);
            var size_y: c_int = @divFloor(@divFloor(9 * win_h, 10), y);
            const size = @min(size_x, size_y);
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
        const x0 = gap;
        const y0 = gap;
        const x_len = @as(c_int, @intCast(self.x_nums + self.col_info.len)) *
            (size + gap) +
            @as(c_int, @intCast((self.col_info.len % 5) + 1)) * gap;
        const y_len = @as(c_int, @intCast(self.y_nums + self.row_info.len)) *
            (size + gap) +
            @as(c_int, @intCast((self.row_info.len % 5) + 1)) * gap;

        // Draw horizontal lines
        var y: c_int = y0;
        for (0..self.y_nums + self.row_info.len + 1) |i| {
            var thick: c_int = gap;
            if (i >= self.y_nums and (i - self.y_nums) % 5 == 0) thick *= 2;
            rl.DrawRectangle(x0, y, x_len, thick, rl.BLACK);
            y += thick + size;
        }

        // Draw vertical lines
        var x: c_int = x0;
        for (0..self.x_nums + self.col_info.len + 1) |i| {
            var thick: c_int = gap;
            if (i >= self.x_nums and (i - self.x_nums) % 5 == 0) thick *= 2;
            rl.DrawRectangle(x, y0, thick, y_len, rl.BLACK);
            x += thick + size;
        }

        // Blank out the upper-left corner
        const w = @as(c_int, @intCast(self.x_nums)) * (size + gap);
        const h = @as(c_int, @intCast(self.y_nums)) * (size + gap);
        rl.DrawRectangle(x0, y0, w, h, rl.WHITE);
    }
};
