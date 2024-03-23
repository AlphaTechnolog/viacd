const std = @import("std");

const io = std.io;
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const ArrayList = std.ArrayList;

pub fn xmkdir(dirname: []const u8) !fs.Dir {
    return fs.openDirAbsolute(dirname, .{}) catch retry: {
        fs.makeDirAbsolute(dirname) catch |err| {
            const stderr = io.getStdErr().writer();
            try stderr.print("Cannot mkdir {s}: {s}\n", .{ dirname, @errorName(err) });
            process.exit(1);
            return err;
        };

        // now it shouldn't fail
        break :retry fs.openDirAbsolute(dirname, .{}) catch unreachable;
    };
}

pub fn findIndexes(allocator: mem.Allocator, string: []const u8, sep: u8) !ArrayList(u32) {
    var ret = try ArrayList(u32).init(allocator);

    for (0..string.len) |i| {
        const char = @as(u8, string[i]);
        if (char == sep) {
            try ret.append(@as(u32, i));
        }
    }

    return ret;
}
