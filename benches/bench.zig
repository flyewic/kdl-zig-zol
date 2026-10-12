const std = @import("std");
const kdl = @import("kdl");
const Timer = @import("timer.zig").Timer;

const default_files = [_][]const u8{
    "tests/kdl-spec/tests/benchmarks/html-standard.kdl",
    "tests/kdl-spec/tests/benchmarks/html-standard-compact.kdl",
};

pub fn main(init: std.process.Init) !void {
    var gpa = std.heap.SafeAllocator.init(std.heap.page_allocator, .{});
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    var args = init.minimal.args.iterate();
    _ = args.skip(); // skip executable

    var paths: std.ArrayListUnmanaged([]const u8) = .empty;
    defer paths.deinit(allocator);

    while (args.next()) |arg| {
        try paths.append(allocator, arg);
    }

    const files = if (paths.items.len == 0) default_files[0..] else paths.items;

    for (files) |path| {
        const input = std.Io.Dir.cwd().readFileAlloc(init.io, path, allocator, .limited(256 * 1024 * 1024)) catch |err| {
            std.debug.print("bench: failed to read {s}: {}\n", .{ path, err });
            return err;
        };
        defer allocator.free(input);

        var timer = try Timer.start();
        var doc = try kdl.parse(allocator, input);
        const parse_ns = timer.lap();

        var sink = std.Io.Writer.Allocating.init(allocator);
        defer sink.deinit();
        try kdl.serialize(&doc, &sink.writer, .{});
        const serialize_ns = timer.lap();

        doc.deinit();

        std.debug.print(
            "{s}: {d} bytes, parse {d} ms, serialize {d} ms\n",
            .{
                path,
                input.len,
                @divTrunc(parse_ns, std.time.ns_per_ms),
                @divTrunc(serialize_ns, std.time.ns_per_ms),
            },
        );
    }

    // Synthetic benchmark for parseAsInto
    {
        const Item = struct {
            name: []const u8 = "",
            id: i32 = 0,
            score: f64 = 0.0,
            active: bool = false,
        };

        const count = 100_000;
        var builder = std.Io.Writer.Allocating.init(allocator);
        defer builder.deinit();

        var i: usize = 0;
        while (i < count) : (i += 1) {
            try builder.writer.print("item name=\"item{d}\" id={d} score=99.5 active=#true\n", .{ i, i });
        }

        const input = try builder.toOwnedSlice();
        defer allocator.free(input);

        var timer = try Timer.start();

        // Parse as []Item
        var items: []Item = undefined;
        // Note: we use an arena for the items to hold strings etc
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        try kdl.decode(&items, arena.allocator(), input, .{ .copy_strings = false });

        const parse_ns = timer.lap();

        std.debug.print(
            "synthetic decode ({} items): {d} bytes, {d} ms\n",
            .{
                items.len,
                input.len,
                @divTrunc(parse_ns, std.time.ns_per_ms),
            },
        );
    }
}
