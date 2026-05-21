const std = @import("std");

pub const FileData = struct {
    data: []const u8,
    allocator: std.mem.Allocator,
    file: std.Io.File,
    io: std.Io,

    pub fn init(io: std.Io, path: []const u8, allocator: std.mem.Allocator) !FileData {
        const file = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
        errdefer file.close(io);

        var read_buffer: [4096]u8 = undefined;
        var file_reader = file.reader(io, &read_buffer);

        const buf = file_reader.interface.allocRemaining(allocator, .unlimited) catch |err| {
            file.close(io);
            return err;
        };

        return .{
            .data = buf,
            .allocator = allocator,
            .file = file,
            .io = io,
        };
    }

    pub fn deinit(self: *FileData) void {
        self.allocator.free(self.data);
        self.file.close(self.io);
    }
};

pub const WcharString = struct {
    chars: []const i16,

    pub fn format(
        self: WcharString,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        for (self.chars) |c| {
            if (c == 0) break;
            try writer.writeByte(@intCast(c & 0xFF));
        }
    }
};

