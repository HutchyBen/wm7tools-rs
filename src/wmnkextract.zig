const std = @import("std");
const guid_mod = @import("guid.zig");
const mbr_mod = @import("mbr.zig");
const wmpart_mod = @import("wmpartitions.zig");
const wmnk_mod = @import("wmnk.zig");
const mmap_mod = @import("mmap.zig");

const OUT_FOLDER = "XIP";

fn writeBufToFile(io: std.Io, filename: []const u8, buffer: []const u8) void {
    if (std.fs.path.dirname(filename)) |dir_path| {
        std.Io.Dir.cwd().createDirPath(io, dir_path) catch {};
    }
    const file = std.Io.Dir.cwd().createFile(io, filename, .{}) catch {
        std.debug.print("failed to write '{s}'\n", .{filename});
        return;
    };
    defer file.close(io);
    file.writeStreamingAll(io, buffer) catch {
        std.debug.print("failed to write '{s}'\n", .{filename});
    };
}

fn getCString(nk: []const u8, offset: usize) []const u8 {
    if (offset >= nk.len) {
        return &[_]u8{};
    }
    const slice = nk[offset..];
    var len: usize = 0;
    while (len < slice.len and slice[len] != 0) {
        len += 1;
    }
    return slice[0..len];
}

fn getNkStartAndSizeInMemory(
    data: []const u8,
    offset: *u64,
    size: *u64,
) !void {
    if (data.len < 0x1000) {
        return error.FileTooSmall;
    }
    const tmp_buf = data[0..0x1000];

    // check if this is a raw NK image
    if (std.mem.eql(u8, tmp_buf[0x40..0x44], "ECEC")) {
        offset.* = 0;
        size.* = data.len;
        return;
    }

    // check if this is a WMSTORE structure
    if (tmp_buf[510] == 0x55 and tmp_buf[511] == 0xAA) {
        if (std.mem.eql(u8, tmp_buf[512..520], "_wmstore")) {
            var found_nk: ?struct { offset_sector: u32, size_sectors: u32 } = null;
            const first_partition_size_sectors = std.mem.readInt(u32, tmp_buf[1024 + 84 .. 1024 + 88], .little);

            var i: usize = 0;
            while (i < 6) : (i += 1) {
                if (i >= first_partition_size_sectors) {
                    break;
                }
                const part_offset = 1024 + i * 512;
                if (part_offset + 512 > tmp_buf.len) {
                    break;
                }
                const part_magic = tmp_buf[part_offset .. part_offset + 8];
                if (!std.mem.eql(u8, part_magic, "_wmpart_")) {
                    break;
                }
                const part_type = std.mem.readInt(u32, tmp_buf[part_offset + 100..][0..4], .little);
                const part_name = tmp_buf[part_offset + 8 .. part_offset + 14];

                const nk_name = &[_]u8{ 'N', 0, 'K', 0, 0, 0 };
                if (part_type == wmpart_mod.WMPART_XIP_RAM and std.mem.eql(u8, part_name, nk_name)) {
                    const offset_sector = std.mem.readInt(u32, tmp_buf[part_offset + 76..][0..4], .little);
                    const size_sectors = std.mem.readInt(u32, tmp_buf[part_offset + 84..][0..4], .little);
                    found_nk = .{ .offset_sector = offset_sector, .size_sectors = size_sectors };
                    break;
                }
            }

            if (found_nk) |nk_part| {
                offset.* = @as(u64, nk_part.offset_sector) * 0x200;
                size.* = @as(u64, nk_part.size_sectors) * 0x200;
                return;
            } else {
                return error.NoNkPartition;
            }
        }
    }

    return error.UnknownFormat;
}

fn run(io: std.Io, args: []const [:0]const u8, allocator: std.mem.Allocator) !void {
    if (args.len < 2) {
        std.debug.print("usage: {s} path/to/image\n", .{args[0]});
        return error.MissingArg;
    }

    var file_data = mmap_mod.FileData.init(io, args[1], allocator) catch {
        std.debug.print("failed to open file\n", .{});
        return error.FailedToOpenFile;
    };
    defer file_data.deinit();

    // Lock and buffer stdout for hyper speed!
    var stdout_buffer: [16384]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const writer = &stdout_file_writer.interface;

    var nk_offset: u64 = 0;
    var nk_size: u64 = 0;
    getNkStartAndSizeInMemory(file_data.data, &nk_offset, &nk_size) catch |err| {
        std.debug.print("failed to find NK header\n", .{});
        return err;
    };

    const nk_start = @as(usize, @intCast(nk_offset));
    const nk_end = nk_start + @as(usize, @intCast(nk_size));
    if (nk_end > file_data.data.len) {
        try writer.print("failed to read NK data from file\n", .{});
        try writer.flush();
        return error.NkOutOfBounds;
    }
    const nk = file_data.data[nk_start..nk_end];

    // guess base address
    const rom_hdr_virt = std.mem.readInt(u32, nk[0x44..0x48], .little);
    const rom_hdr_real = std.mem.readInt(u32, nk[0x48..0x4C], .little);
    var base_address = rom_hdr_virt -% rom_hdr_real;
    try writer.print("Base: 0x{x:0>8}\n", .{base_address});

    const romhdr_offset = @as(usize, @intCast(rom_hdr_real));
    if (romhdr_offset + 84 > nk.len) {
        try writer.print("Actually, 0x00000000? Something's wrong, but trying our best...\n", .{});
        try writer.flush();
        return error.InvalidRomHdrOffset;
    }

    var romhdr_bytes: [84]u8 = undefined;
    @memcpy(&romhdr_bytes, nk[romhdr_offset .. romhdr_offset + 84]);
    const romhdr = wmnk_mod.WmnkRomHdr.fromBytes(romhdr_bytes);

    if (romhdr.physfirst != base_address) {
        try writer.print("Actually, 0x{x:0>8}? Something's wrong, but trying our best...\n", .{romhdr.physfirst});
        base_address = romhdr.physfirst;
    }

    try writer.print("DLLs: 0x{x:0>8}-0x{x:0>8}\n", .{romhdr.dllfirst, romhdr.dlllast});
    try writer.print("Phys: 0x{x:0>8}-0x{x:0>8}\n", .{romhdr.physfirst, romhdr.physlast});
    try writer.print("RAM:  0x{x:0>8}-0x{x:0>8} (Free @ 0x{x:0>8})\n", .{romhdr.ul_ram_start, romhdr.ul_ram_end, romhdr.ul_ram_free});
    try writer.print("Modules: {}, Files: {}, Copyentries: {}\n", .{romhdr.nummods, romhdr.numfiles, romhdr.ul_copy_entries});

    // Write ROM header
    const romhdr_path = try std.fmt.allocPrint(allocator, "{s}/romhdr.bin", .{OUT_FOLDER});
    defer allocator.free(romhdr_path);
    writeBufToFile(io, romhdr_path, nk[romhdr_offset .. romhdr_offset + 84]);

    var entry_offset = romhdr_offset + 84;

    // Modules loop
    for (0..romhdr.nummods) |_| {
        if (entry_offset + 32 > nk.len) break;

        var entry_bytes: [32]u8 = undefined;
        @memcpy(&entry_bytes, nk[entry_offset .. entry_offset + 32]);
        const toc = wmnk_mod.WmnkTocEntry.fromBytes(entry_bytes);

        const name_offset = @as(usize, @intCast(toc.lpsz_file_name -% base_address));
        const name = getCString(nk, name_offset);

        try writer.print("0x{x:0>8} = Module: {s} (size: 0x{x}, attr: 0x{x})\n", .{toc.ul_load_offset, name, toc.n_file_size, toc.dw_file_attributes});

        entry_offset += 32;
    }

    // Files loop
    for (0..romhdr.numfiles) |_| {
        if (entry_offset + 28 > nk.len) break;

        var entry_bytes: [28]u8 = undefined;
        @memcpy(&entry_bytes, nk[entry_offset .. entry_offset + 28]);
        const file_entry = wmnk_mod.WmnkFilesEntry.fromBytes(entry_bytes);

        const name_offset = @as(usize, @intCast(file_entry.lpsz_file_name -% base_address));
        const name = getCString(nk, name_offset);

        try writer.print("0x{x:0>8} = File: {s} (size: 0x{x}, comp: 0x{x}, attr: 0x{x})\n", .{file_entry.ul_load_offset, name, file_entry.n_real_file_size, file_entry.n_comp_file_size, file_entry.dw_file_attributes});

        if (file_entry.n_real_file_size == file_entry.n_comp_file_size) {
            const file_data_offset = @as(usize, @intCast(file_entry.ul_load_offset -% base_address));
            const file_data_len = @as(usize, @intCast(file_entry.n_real_file_size));
            if (file_data_offset + file_data_len <= nk.len) {
                const extracted_data = nk[file_data_offset .. file_data_offset + file_data_len];
                const filepath = try std.fmt.allocPrint(allocator, "{s}/{s}", .{OUT_FOLDER, name});
                defer allocator.free(filepath);
                writeBufToFile(io, filepath, extracted_data);
            }
        }

        entry_offset += 28;
    }

    try writer.flush();
}

pub fn main(init: std.process.Init) void {
    const allocator = init.gpa;
    const args = init.minimal.args.toSlice(init.arena.allocator()) catch {
        std.process.exit(1);
    };

    run(init.io, args, allocator) catch {
        std.process.exit(1);
    };
}
