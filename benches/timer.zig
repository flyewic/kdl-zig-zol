//! Minimal monotonic timer for benchmarks, replacing the removed
//! `std.time.Timer` with the `std.Io.Clock` API introduced in Zig 0.17.

const std = @import("std");

pub const Timer = struct {
    start_ts: std.Io.Clock.Timestamp,
    last_ts: std.Io.Clock.Timestamp,

    pub fn start() !Timer {
        const now = std.Io.Clock.Timestamp.now(std.Options.debug_io, .awake);
        return .{ .start_ts = now, .last_ts = now };
    }

    /// Elapsed nanoseconds since `start`, without resetting.
    pub fn read(self: *const Timer) u64 {
        return @intCast(self.start_ts.untilNow(std.Options.debug_io).raw.nanoseconds);
    }

    /// Elapsed nanoseconds since the previous `lap` (or `start`), then resets.
    pub fn lap(self: *Timer) u64 {
        const now = std.Io.Clock.Timestamp.now(std.Options.debug_io, .awake);
        const elapsed = self.last_ts.untilNow(std.Options.debug_io).raw.nanoseconds;
        self.last_ts = now;
        return @intCast(elapsed);
    }
};
