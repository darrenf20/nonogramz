
fn create_prob_grid(data: Data) ![][]f64 {
    var grid = try data.allocator.alloc([]f64, data.row_info.len);
    for (grid, 0..) |*line, i| {
        line.* = try data.allocator.alloc(f64, data.col_info.len);

        const n = data.col_info.len;
        var m: usize = 0;
        for (data.row_info[i]) |s| m += s;
        const k = data.row_info[i].len;
        const c = maths.nCr(n - m + 1, k);

        for (line.*) |*sq| {
            if (data.row_info[i][0] == 0) {
                sq.* = 0.0;
            } else {
                sq.* = 1.0 / @as(f64, @floatFromInt(c));
            }
        }
    }
    return grid;
}

fn free_prob_grid(allocator: std.mem.Allocator, grid: [][]f64) void {
    for (grid) |line| allocator.free(line);
    allocator.free(grid);
}
