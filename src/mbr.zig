const std = @import("std");

pub const Partition = struct {
    attributes: u8,
    start_chs: [3]u8,
    type_id: u8,
    end_chs: [3]u8,
    lba_start: u32,
    num_sectors: u32,

    pub fn fromBytes(bytes: [16]u8) Partition {
        return .{
            .attributes = bytes[0],
            .start_chs = bytes[1..4].*,
            .type_id = bytes[4],
            .end_chs = bytes[5..8].*,
            .lba_start = std.mem.readInt(u32, bytes[8..12], .little),
            .num_sectors = std.mem.readInt(u32, bytes[12..16], .little),
        };
    }
};

pub const Mbr = struct {
    bootstrap: [0x1B8]u8,
    disk_id: [4]u8,
    reserved: [2]u8,
    partitions: [4]Partition,
    signature: [2]u8,

    pub fn fromBytes(bytes: [512]u8) Mbr {
        var partitions: [4]Partition = undefined;
        for (0..4) |i| {
            const offset = 0x1B8 + 4 + 2 + i * 16;
            var part_bytes: [16]u8 = undefined;
            @memcpy(&part_bytes, bytes[offset .. offset + 16]);
            partitions[i] = Partition.fromBytes(part_bytes);
        }
        return .{
            .bootstrap = bytes[0..0x1B8].*,
            .disk_id = bytes[0x1B8 .. 0x1B8 + 4].*,
            .reserved = bytes[0x1B8 + 4 .. 0x1B8 + 6].*,
            .partitions = partitions,
            .signature = bytes[510..512].*,
        };
    }
};
