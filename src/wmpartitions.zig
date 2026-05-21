const std = @import("std");

pub const WMPART_DOS3_FAT: u32 = 0x04;
pub const WMPART_UNK_0X1B: u32 = 0x1B;
pub const WMPART_BOOT: u32 = 0x20;
pub const WMPART_XIP_ROM: u32 = 0x22;
pub const WMPART_XIP_RAM: u32 = 0x23;
pub const WMPART_IMGFS: u32 = 0x25;
pub const WMPART_UNK_0X29: u32 = 0x29;
pub const WMPART_PADDING: u32 = 0x2A;

pub const WmstoreHdr = struct {
    magic: [8]u8,
    guid: [16]u8,
    name: [0x20]i16,
    num_sectors: u32,
    unk2: u32,
    unk3: u32,
    timestamp: u64,
    unk5: u32,
    padding: [0x190]u8,

    pub fn fromBytes(bytes: [512]u8) WmstoreHdr {
        var name: [0x20]i16 = undefined;
        for (0..0x20) |i| {
            const offset = 8 + 16 + i * 2;
            name[i] = std.mem.readInt(i16, bytes[offset..][0..2], .little);
        }
        return .{
            .magic = bytes[0..8].*,
            .guid = bytes[8..24].*,
            .name = name,
            .num_sectors = std.mem.readInt(u32, bytes[88..92], .little),
            .unk2 = std.mem.readInt(u32, bytes[92..96], .little),
            .unk3 = std.mem.readInt(u32, bytes[96..100], .little),
            .timestamp = std.mem.readInt(u64, bytes[100..108], .little),
            .unk5 = std.mem.readInt(u32, bytes[108..112], .little),
            .padding = bytes[112..512].*,
        };
    }
};

pub const WmpartHdr = struct {
    magic: [8]u8,
    name: [0x20]i16,
    unk1: u32,
    offset_sector: u32,
    unk2: u32,
    size_sectors: u32,
    unk3: u32,
    timestamp: u64,
    partition_type: u32,
    unk5: u32,
    unk6: u32,
    padding: [0x190]u8,

    pub fn fromBytes(bytes: [512]u8) WmpartHdr {
        var name: [0x20]i16 = undefined;
        for (0..0x20) |i| {
            const offset = 8 + i * 2;
            name[i] = std.mem.readInt(i16, bytes[offset..][0..2], .little);
        }
        return .{
            .magic = bytes[0..8].*,
            .name = name,
            .unk1 = std.mem.readInt(u32, bytes[72..76], .little),
            .offset_sector = std.mem.readInt(u32, bytes[76..80], .little),
            .unk2 = std.mem.readInt(u32, bytes[80..84], .little),
            .size_sectors = std.mem.readInt(u32, bytes[84..88], .little),
            .unk3 = std.mem.readInt(u32, bytes[88..92], .little),
            .timestamp = std.mem.readInt(u64, bytes[92..100], .little),
            .partition_type = std.mem.readInt(u32, bytes[100..104], .little),
            .unk5 = std.mem.readInt(u32, bytes[104..108], .little),
            .unk6 = std.mem.readInt(u32, bytes[108..112], .little),
            .padding = bytes[112..512].*,
        };
    }
};
