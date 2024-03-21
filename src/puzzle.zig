pub const State = enum { blank, cross, square };

pub const Data = struct {
    allocator: std.mem.Allocator,
    bytes: []u8 = &.{},

    row_info: [][]usize = undefined,
    col_info: [][]usize = undefined,
    grid: [][]State = undefined,
    is_solved: bool = false,

    x_nums: usize = 0, // max number of blocks for a row
    y_nums: usize = 0, // max number of blocks for a column

    pub fn init(self: *Data) !void {
        self.deinit();

        var dropped: rl.FilePathList = rl.LoadDroppedFiles();
        const file = try std.fs.openFileAbsoluteZ(
            @as([*:0]u8, @ptrCast(&(dropped.paths.*[0]))), // simplify?
            .{},
        );
        rl.UnloadDroppedFiles(dropped);
        self.bytes = try file.readToEndAlloc(self.allocator, try file.getEndPos());
        file.close();

        // Custom file format
        // Populate puzzle info
        // TODO: error checking, validation
        var iterator = std.mem.splitScalar(u8, self.bytes, '\n');
        var num_it = std.mem.splitScalar(u8, iterator.next().?, ' ');
        var col_len = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
        var row_len = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);

        self.row_info = try self.allocator.alloc([]usize, row_len);
        self.col_info = try self.allocator.alloc([]usize, col_len);

        // Zero-initialise grid
        self.grid = try self.allocator.alloc([]State, row_len);
        for (self.grid) |*row| {
            row.* = try self.allocator.alloc(State, col_len);
            for (row.*) |*square| square.* = .blank;
        }

        _ = iterator.next().?; // skip blank line
        for (self.col_info) |*line| {
            var str: []const u8 = iterator.next().?;
            num_it = std.mem.splitScalar(u8, str, ' ');

            var len = std.mem.count(u8, str, " ") + 1;
            line.* = try self.allocator.alloc(usize, len);

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
            line.* = try self.allocator.alloc(usize, len);

            var offset: usize = 0;
            for (line.*) |*sq| {
                sq.* = try std.fmt.parseUnsigned(usize, num_it.next().?, 10);
                offset += 1;
            }
            if (offset > self.x_nums) self.x_nums = offset;
        }
    }

    pub fn deinit(self: *Data) void {
        if (self.bytes.len == 0) return;

        self.allocator.free(self.bytes);

        for (self.row_info) |line| self.allocator.free(line);
        self.allocator.free(self.row_info);

        for (self.col_info) |line| self.allocator.free(line);
        self.allocator.free(self.col_info);

        for (self.grid) |line| self.allocator.free(line);
        self.allocator.free(self.grid);

        self.x_nums = 0;
        self.y_nums = 0;
    }

    pub fn evaluate_grid(self: *Data) void {
        for (self.row_info, self.grid) |clues, line| {
            var clue_total: usize = 0;
            for (clues) |n| clue_total += n;
            var line_total: usize = 0;
            for (line) |n| line_total += @intFromEnum(n) / 2;
            if (clue_total != line_total) {
                self.is_solved = false;
                return;
            }
        }

        for (self.col_info, 0..) |clues, j| {
            var clue_total: usize = 0;
            for (clues) |n| clue_total += n;
            var line_total: usize = 0;
            for (0..self.grid.len) |i| {
                line_total += @intFromEnum(self.grid[i][j]) / 2;
            }
            if (clue_total != line_total) {
                self.is_solved = false;
                return;
            }
        }

        self.is_solved = true;
    }
};

const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
