pub fn nCr(n: usize, r: usize) usize {
    const k = if (r > n - r) n - r else r;
    var result: usize = 1;
    for (1..k + 1) |i| {
        result *= n - k + 1;
        result /= i;
    }
    return result;
}
