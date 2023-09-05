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

    const size = @as(c_int, @intCast(@min(win_w, win_h) * 4 / 100));
    const gap: c_int = @divFloor(size, 15);
    var data = Data{ .ally = ally, .size = size, .gap = gap };
    defer data.deinit();

    rl.InitWindow(win_w, win_h, "Nonogram");
    defer rl.CloseWindow();

    rl.SetTargetFPS(30);
    while (!rl.WindowShouldClose()) {
        if (rl.IsFileDropped()) try data.init();

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(rl.DARKGRAY);

        if (data.bytes.len == 0) {
            const text = "Drop puzzle file here";
            const font_size = 40;
            rl.DrawText(
                text,
                win_w / 2 - @divTrunc(rl.MeasureText(text, font_size), 2),
                win_h / 2 - (font_size / 2),
                font_size,
                rl.LIGHTGRAY,
            );
        } else {
            data.draw();
        }

        rl.EndDrawing();
    }
}

const Data = struct {
    ally: std.mem.Allocator,

    bytes: []u8 = &.{},
    buffer: [256]u8 = undefined,

    row_info: [][]usize = undefined,
    col_info: [][]usize = undefined,
    grid: [][]u1 = undefined,

    // try making these usize
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

            for (line.*) |*sq| {
                sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
            }

            var offset = @as(c_int, @intCast(len)) * (self.size + self.gap);
            if (offset > self.y_offset) self.y_offset = offset;
        }

        _ = iterator.next().?; // skip blank line
        for (self.row_info) |*line| {
            var str: []const u8 = iterator.next().?;
            num_it = std.mem.splitScalar(u8, str, ' ');

            var len = std.mem.count(u8, str, " ") + 1;
            line.* = try self.ally.alloc(usize, len);

            for (line.*) |*sq| {
                sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
            }

            const cstr = self.bufZ(str);
            var offset = rl.MeasureText(cstr, self.size) + 3 * self.gap;
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

    fn draw(self: *Data) void {
        var x: c_int = self.x_offset + 4 * self.gap;
        var y: c_int = 0;

        var iter = std.mem.splitScalar(u8, self.bytes, '\n');
        _ = iter.next().?; // skip x len, y len
        _ = iter.next().?; // skip blank line

        // Draw column number text
        for (0..self.col_info.len) |_| {
            y = 0;
            var num_it = std.mem.splitScalar(u8, iter.next().?, ' ');
            while (num_it.next()) |num| {
                const txt = self.bufZ(num);
                rl.DrawText(txt, x, y, self.size, rl.WHITE);
                y += self.size + self.gap;
            }
            x += self.size + self.gap;
        }

        // Draw row number text
        _ = iter.next().?; // skip blank line
        x = 0;
        y = self.y_offset + 2 * self.gap;
        while (iter.next()) |line| {
            const txt = self.bufZ(line);
            rl.DrawText(txt, x, y, self.size, rl.WHITE);
            y += self.size + self.gap;
        }

        // Draw puzzle grid
        y = self.y_offset;
        for (self.grid, 1..) |row, i| {
            x = self.x_offset;
            for (row, 1..) |sq, j| {
                const colour = if (sq == 0) rl.WHITE else rl.BLACK;
                rl.DrawRectangle(x, y, self.size, self.size, colour);
                x += self.size + if (j % 5 == 0) 2 * self.gap else self.gap;
            }
            y += self.size + if (i % 5 == 0) 2 * self.gap else self.gap;
        }
    }

    fn bufZ(self: *Data, text: []const u8) [:0]u8 {
        @memcpy(self.buffer[0..text.len], text);
        self.buffer[text.len] = 0;
        return self.buffer[0..text.len :0];
    }
};
