const std = @import("std");
const QueryMatcher = @import("../backend/query-matcher.zig");

const io = std.io;
const mem = std.mem;
const process = std.process;
const os = std.os;
const fmt = std.fmt;
const fs = std.fs;

const Self = @This();

const stdout = io.getStdOut().writer();
const stderr = io.getStdErr().writer();

allocator: mem.Allocator,
path: []const u8,
query_matcher: *QueryMatcher,

pub fn init(allocator: mem.Allocator, path: []const u8) !*Self {
    var instance = try allocator.create(Self);
    instance.allocator = allocator;
    instance.path = try allocator.dupe(u8, path);
    instance.query_matcher = try QueryMatcher.init(instance.allocator);
    return instance;
}

fn regularCDBehavior(self: *Self) !?[]const u8 {
    var opened_dir = fs.cwd().openDir(self.path, .{}) catch |err| {
        switch (err) {
            fs.Dir.OpenError.FileNotFound => {
                return null;
            },
            else => {
                try stdout.print("Cannot try to open dir {s}: {s}!\n", .{ self.path, @errorName(err) });
                process.exit(1);
            },
        }
    };

    defer opened_dir.close();

    return self.path;
}

pub fn printMatch(self: *Self) !void {
    if (try self.regularCDBehavior()) |path| {
        try self.query_matcher.dbAppendPath(path);
        try stdout.print("{s}\n", .{path});
        return;
    }

    if (try self.query_matcher.queryWithMatch()) |path| {
        defer self.allocator.free(path);
        try stdout.print("{s}\n", .{path});
        return;
    }

    try stderr.print("viacd: {s} not found\n", .{self.path});
}

pub fn deinit(self: *Self) void {
    self.query_matcher.deinit();
    self.allocator.free(self.path);
    self.allocator.destroy(self);
}
