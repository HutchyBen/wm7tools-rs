const std = @import("std");

pub const Guid = struct {
    p1: u32,
    p2: u16,
    p3: u16,
    p4: u16,
    p5: [6]u8,

    pub fn fromBytes(bytes: [16]u8) Guid {
        return .{
            .p1 = std.mem.readInt(u32, bytes[0..4], .little),
            .p2 = std.mem.readInt(u16, bytes[4..6], .little),
            .p3 = std.mem.readInt(u16, bytes[6..8], .little),
            .p4 = std.mem.readInt(u16, bytes[8..10], .little),
            .p5 = bytes[10..16].*,
        };
    }

    pub fn format(
        self: Guid,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        // Matches the exact C-style hex-width formatting quirk of the original codebase
        try writer.print("{x:0>8}-{x:0>2}-{x:0>2}-{x:0>2}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{
            self.p1, self.p2, self.p3, self.p4,
            self.p5[0], self.p5[1], self.p5[2], self.p5[3], self.p5[4], self.p5[5]
        });
    }
};
