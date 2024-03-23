const std = @import("std");
const Utils = @import("../utils.zig");

const io = std.io;
const mem = std.mem;
const fs = std.fs;
const os = std.os;
const process = std.process;
const fmt = std.fmt;
const ArrayList = std.ArrayList;

const Self = @This();

const stdout = io.getStdOut().writer();
const stderr = io.getStdErr().writer();

pub const DBAccessError = error{DBNotOpenedYet} || anyerror;

allocator: mem.Allocator,
dbpath: []u8,
opened_db: ?fs.File,

pub const DBReader = struct {
    opened_db: fs.File,
    allocator: mem.Allocator,

    const DBEntry = struct {
        content: []u8,
        score: usize,
        allocator: mem.Allocator,

        pub fn init(allocator: mem.Allocator, content: []u8, score: usize) !*DBEntry {
            var instance = try allocator.create(DBEntry);
            instance.allocator = allocator;
            instance.content = content;
            instance.score = score;
            return instance;
        }

        pub fn deinit(self: *DBEntry) void {
            self.allocator.free(self.content);
            self.allocator.destroy(self);
        }
    };

    pub fn init(allocator: mem.Allocator, opened_db: fs.File) !*DBReader {
        var instance = try allocator.create(DBReader);
        instance.allocator = allocator;
        instance.opened_db = opened_db;
        return instance;
    }

    // NOTE: This method assumes that the given `query_matcher` already has
    // an opened db connection stream.
    pub fn initFromQueryMatcher(query_matcher: *Self) !*DBReader {
        return DBReader.init(query_matcher.allocator, query_matcher.opened_db.?);
    }

    pub fn readAll(self: *DBReader) !ArrayList(*DBEntry) {
        const reader = self.opened_db.reader();

        var entries = ArrayList(*DBEntry).init(self.allocator);
        var buf: [1024]u8 = undefined;
        var i: usize = 0;

        while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| : (i += 1) {
            const content = try self.allocator.dupe(u8, line);
            const score = i + 1;
            try entries.append(try DBEntry.init(self.allocator, content, score));
        }

        return entries;
    }

    pub fn deinitDBEntries(self: *DBReader, entries: ArrayList(*DBEntry)) void {
        _ = self;

        for (entries.items) |item| {
            item.deinit();
        }

        entries.deinit();
    }

    pub fn deinit(self: *DBReader) void {
        self.allocator.destroy(self);
    }
};

pub fn init(allocator: mem.Allocator) !*Self {
    var instance = try allocator.create(Self);

    instance.allocator = allocator;

    try instance.initialiseDatabase();
    try instance.openDB();

    return instance;
}

fn openDB(self: *Self) !void {
    self.opened_db = fs.openFileAbsolute(self.dbpath, .{ .mode = .read_write }) catch |err| {
        try stderr.print("Cannot open viacd database stream: {s}!\n", .{@errorName(err)});
        process.exit(1);
    };
}

fn initialiseDatabase(self: *Self) !void {
    var home = os.getenv("HOME");

    if (home == null) {
        try stderr.print("fatal: Cannot get the home variable?\n", .{});
        process.exit(1);
    }

    const paths = [_][]const u8{ home.?, ".cache", "viacd" };
    const cachedir = try fs.path.join(self.allocator, &paths);
    defer self.allocator.free(cachedir);

    var dir = try Utils.xmkdir(cachedir);
    defer dir.close();

    _ = dir.statFile("viacd.db") catch {
        var dbfile = try dir.createFile("viacd.db", .{});
        dbfile.close();
    };

    self.dbpath = try fs.path.join(self.allocator, &[_][]const u8{ home.?, ".cache", "viacd", "viacd.db" });
}

pub fn isInDB(self: *Self, path: []const u8) DBAccessError!bool {
    if (self.opened_db == null) {
        return error.DBNotOpenedYet;
    }

    const db_file = self.opened_db.?;
    const reader = db_file.reader();

    var buf: [1024]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        if (mem.eql(u8, line, path)) {
            return true;
        }
    }

    return false;
}

// TODO: Atm this is only taking in mind the score, this should also
// perform a fuzzy finding by using the path as the query value.
// NOTE: This function returns an allocated string, so caller has
// to make sure to free the returned value after calling this.
pub fn queryWithMatch(self: *Self) DBAccessError!?[]u8 {
    var db_reader = try DBReader.initFromQueryMatcher(self);
    var entries = try db_reader.readAll();

    defer {
        db_reader.deinitDBEntries(entries);
        db_reader.deinit();
    }

    var result: ?[]u8 = null;
    var possible_match: ?[]u8 = null;
    var act_score: usize = 0;

    for (entries.items) |entry| {
        if (entry.*.score > act_score) {
            act_score = entry.*.score;
            possible_match = entry.*.content;
        }
    }

    if (possible_match == null or act_score == 0) {
        return null;
    }

    // copying since at the end, possible_match will get freed
    // by the call of `DBEntry.deinit()`.
    if (possible_match) |match| {
        result = try self.allocator.dupe(u8, match);
    }

    return result;
}

pub fn dbAppendPath(self: *Self, path: []const u8) !void {
    if (try self.isInDB(path)) {
        return;
    }

    if (self.opened_db) |db| {
        const fmtted = try fmt.allocPrint(self.allocator, "{s}\n", .{path});
        defer self.allocator.free(fmtted);
        try db.writer().writeAll(fmtted);
    }
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.dbpath);
    self.allocator.destroy(self);
}
