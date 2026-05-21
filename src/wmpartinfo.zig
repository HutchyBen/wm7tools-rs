const std = @import("std");
const guid_mod = @import("guid.zig");
const mbr_mod = @import("mbr.zig");
const wmpart_mod = @import("wmpartitions.zig");
const mmap_mod = @import("mmap.zig");

fn partitionTypeToStr(t: u32) []const u8 {
    return switch (t) {
        wmpart_mod.WMPART_DOS3_FAT => "DOS3/FAT",
        wmpart_mod.WMPART_BOOT => "BOOT",
        wmpart_mod.WMPART_XIP_ROM => "XIP from ROM",
        wmpart_mod.WMPART_XIP_RAM => "XIP from RAM",
        wmpart_mod.WMPART_IMGFS => "IMGFS",
        wmpart_mod.WMPART_PADDING => "Padding",
        else => "Unknown",
    };
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) {
        std.debug.print("usage: {s} path/to/image\n", .{args[0]});
        std.process.exit(1);
    }

    var file_data = mmap_mod.FileData.init(init.io, args[1], allocator) catch {
        std.debug.print("failed to open file\n", .{});
        std.process.exit(1);
    };
    defer file_data.deinit();

    if (file_data.data.len < 512) {
        std.debug.print("failed to read header\n", .{});
        std.process.exit(1);
    }

    // Lock and buffer stdout for hyper speed!
    var stdout_buffer: [16384]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
    const writer = &stdout_file_writer.interface;

    var mbr_bytes: [512]u8 = undefined;
    @memcpy(&mbr_bytes, file_data.data[0..512]);
    const mbr_hdr = mbr_mod.Mbr.fromBytes(mbr_bytes);

    if (mbr_hdr.partitions[0].type_id != 0xEF) {
        try writer.print("partition header has type 0x{X:0>2} instead of 0xEF\n", .{mbr_hdr.partitions[0].type_id});
        try writer.flush();
        std.process.exit(1);
    }
    if (mbr_hdr.signature[0] != 0x55 or mbr_hdr.signature[1] != 0xAA) {
        try writer.print("file header has signature 0x{X:0>2},0x{X:0>2} instead of 0x55,0xAA\n", .{mbr_hdr.signature[0], mbr_hdr.signature[1]});
        try writer.flush();
        std.process.exit(1);
    }

    if (file_data.data.len < 1024) {
        try writer.print("failed to read wmstore header\n", .{});
        try writer.flush();
        std.process.exit(1);
    }

    var store_bytes: [512]u8 = undefined;
    @memcpy(&store_bytes, file_data.data[512..1024]);
    const store_hdr = wmpart_mod.WmstoreHdr.fromBytes(store_bytes);

    if (!std.mem.eql(u8, store_hdr.magic[0..8], "_wmstore")) {
        try writer.print("invalid store magic (expected _wmstore)\n", .{});
        try writer.flush();
        std.process.exit(1);
    }

    try writer.print("WMSTORE:\n", .{});
    try writer.print("  Name: {}\n", .{mmap_mod.WcharString{ .chars = &store_hdr.name }});
    try writer.print("  GUID: {}\n", .{guid_mod.Guid.fromBytes(store_hdr.guid)});
    try writer.print("  Max Partition Count: 0x{x}\n", .{store_hdr.num_sectors});
    try writer.print("  Unk2: 0x{x}\n", .{store_hdr.unk2});
    try writer.print("  Unk3: 0x{x}\n", .{store_hdr.unk3});
    try writer.print("  Timestamp: TODO\n", .{});
    try writer.print("  Unk5: 0x{x}\n", .{store_hdr.unk5});

    var offset: usize = 1024;
    var parts: usize = 0;
    for (0..store_hdr.num_sectors) |_| {
        if (offset + 512 > file_data.data.len) {
            try writer.print("failed to read wmpart header\n", .{});
            try writer.flush();
            std.process.exit(1);
        }

        var part_bytes: [512]u8 = undefined;
        @memcpy(&part_bytes, file_data.data[offset .. offset + 512]);
        const part_hdr = wmpart_mod.WmpartHdr.fromBytes(part_bytes);

        if (!std.mem.eql(u8, part_hdr.magic[0..8], "_wmpart_")) {
            break;
        }

        try writer.print("WMPART {}:\n", .{parts});
        try writer.print("  Name: {}\n", .{mmap_mod.WcharString{ .chars = &part_hdr.name }});
        try writer.print("  Unk1: 0x{x}\n", .{part_hdr.unk1});
        try writer.print("  Offset: 0x{x} (@ 0x{x})\n", .{part_hdr.offset_sector, @as(u64, part_hdr.offset_sector) * 512});
        try writer.print("  Unk2: 0x{x}\n", .{part_hdr.unk2});
        try writer.print("  Size: 0x{x} (0x{x})\n", .{part_hdr.size_sectors, @as(u64, part_hdr.size_sectors) * 512});
        try writer.print("  Unk3: 0x{x}\n", .{part_hdr.unk3});
        try writer.print("  Timestamp: TODO\n", .{});
        try writer.print("  Partition Type: {s} (0x{x})\n", .{partitionTypeToStr(part_hdr.partition_type), part_hdr.partition_type});
        try writer.print("  Unk5: 0x{x}\n", .{part_hdr.unk5});
        try writer.print("  Unk6: 0x{x}\n", .{part_hdr.unk6});

        parts += 1;
        offset += 512;
    }

    try writer.flush();
}
