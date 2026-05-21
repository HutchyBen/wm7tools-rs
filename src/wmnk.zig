const std = @import("std");

pub const WmnkHdr = struct {
    boot_code: [0x40]u8,
    magic: [4]u8,
    rom_hdr_virt: u32,
    rom_hdr_real: u32,
    padding: [0xFB4]u8,

    pub fn fromBytes(bytes: [0x1000]u8) WmnkHdr {
        return .{
            .boot_code = bytes[0..0x40].*,
            .magic = bytes[0x40..0x44].*,
            .rom_hdr_virt = std.mem.readInt(u32, bytes[0x44..0x48], .little),
            .rom_hdr_real = std.mem.readInt(u32, bytes[0x48..0x4C], .little),
            .padding = bytes[0x4C..0x1000].*,
        };
    }
};

pub const WmnkRomHdr = struct {
    dllfirst: u32,
    dlllast: u32,
    physfirst: u32,
    physlast: u32,
    nummods: u32,
    ul_ram_start: u32,
    ul_ram_free: u32,
    ul_ram_end: u32,
    ul_copy_entries: u32,
    ul_copy_offset: u32,
    ul_profile_len: u32,
    ul_profile_offset: u32,
    numfiles: u32,
    ul_kernel_flags: u32,
    ul_fs_ram_percent: u32,
    ul_drivglob_start: u32,
    ul_drivglob_len: u32,
    us_cpu_type: u16,
    us_misc_flags: u16,
    p_extensions: u32,
    ul_tracking_start: u32,
    ul_tracking_len: u32,

    pub fn fromBytes(bytes: [84]u8) WmnkRomHdr {
        return .{
            .dllfirst = std.mem.readInt(u32, bytes[0..4], .little),
            .dlllast = std.mem.readInt(u32, bytes[4..8], .little),
            .physfirst = std.mem.readInt(u32, bytes[8..12], .little),
            .physlast = std.mem.readInt(u32, bytes[12..16], .little),
            .nummods = std.mem.readInt(u32, bytes[16..20], .little),
            .ul_ram_start = std.mem.readInt(u32, bytes[20..24], .little),
            .ul_ram_free = std.mem.readInt(u32, bytes[24..28], .little),
            .ul_ram_end = std.mem.readInt(u32, bytes[28..32], .little),
            .ul_copy_entries = std.mem.readInt(u32, bytes[32..36], .little),
            .ul_copy_offset = std.mem.readInt(u32, bytes[36..40], .little),
            .ul_profile_len = std.mem.readInt(u32, bytes[40..44], .little),
            .ul_profile_offset = std.mem.readInt(u32, bytes[44..48], .little),
            .numfiles = std.mem.readInt(u32, bytes[48..52], .little),
            .ul_kernel_flags = std.mem.readInt(u32, bytes[52..56], .little),
            .ul_fs_ram_percent = std.mem.readInt(u32, bytes[56..60], .little),
            .ul_drivglob_start = std.mem.readInt(u32, bytes[60..64], .little),
            .ul_drivglob_len = std.mem.readInt(u32, bytes[64..68], .little),
            .us_cpu_type = std.mem.readInt(u16, bytes[68..70], .little),
            .us_misc_flags = std.mem.readInt(u16, bytes[70..72], .little),
            .p_extensions = std.mem.readInt(u32, bytes[72..76], .little),
            .ul_tracking_start = std.mem.readInt(u32, bytes[76..80], .little),
            .ul_tracking_len = std.mem.readInt(u32, bytes[80..84], .little),
        };
    }
};

pub const WmnkTocEntry = struct {
    dw_file_attributes: u32,
    ft_time: u64,
    n_file_size: u32,
    lpsz_file_name: u32,
    ul_e32_offset: u32,
    ul_o32_offset: u32,
    ul_load_offset: u32,

    pub fn fromBytes(bytes: [32]u8) WmnkTocEntry {
        return .{
            .dw_file_attributes = std.mem.readInt(u32, bytes[0..4], .little),
            .ft_time = std.mem.readInt(u64, bytes[4..12], .little),
            .n_file_size = std.mem.readInt(u32, bytes[12..16], .little),
            .lpsz_file_name = std.mem.readInt(u32, bytes[16..20], .little),
            .ul_e32_offset = std.mem.readInt(u32, bytes[20..24], .little),
            .ul_o32_offset = std.mem.readInt(u32, bytes[24..28], .little),
            .ul_load_offset = std.mem.readInt(u32, bytes[28..32], .little),
        };
    }
};

pub const WmnkFilesEntry = struct {
    dw_file_attributes: u32,
    ft_time: u64,
    n_real_file_size: u32,
    n_comp_file_size: u32,
    lpsz_file_name: u32,
    ul_load_offset: u32,

    pub fn fromBytes(bytes: [28]u8) WmnkFilesEntry {
        return .{
            .dw_file_attributes = std.mem.readInt(u32, bytes[0..4], .little),
            .ft_time = std.mem.readInt(u64, bytes[4..12], .little),
            .n_real_file_size = std.mem.readInt(u32, bytes[12..16], .little),
            .n_comp_file_size = std.mem.readInt(u32, bytes[16..20], .little),
            .lpsz_file_name = std.mem.readInt(u32, bytes[20..24], .little),
            .ul_load_offset = std.mem.readInt(u32, bytes[24..28], .little),
        };
    }
};
