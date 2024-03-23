const std = @import("std");

const Init = @import("./commands/init.zig");
const Query = @import("./commands/query.zig");

const process = std.process;
const debug = std.debug;
const mem = std.mem;
const io = std.io;
const heap = std.heap;
const ArrayList = std.ArrayList;

const stdout = io.getStdOut().writer();
const stderr = io.getStdErr().writer();

const known_commands = [_][]const u8{ "init", "query" };

fn checkCommandExistence(command: []const u8) bool {
    for (known_commands) |cmd| {
        if (mem.eql(u8, cmd, command)) {
            return true;
        }
    }

    return false;
}

const CLIValidationErrors = error{
    InexistentCommand,
    InvalidArguments,
};

fn checkCLI(items: [][]const u8) CLIValidationErrors!void {
    if (items.len == 0) {
        return CLIValidationErrors.InvalidArguments;
    }

    if (!checkCommandExistence(items[0])) {
        return CLIValidationErrors.InexistentCommand;
    }
}

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};

    defer if (gpa.deinit() == .leak) {
        stderr.print("Memory leak has been detected!\n", .{}) catch unreachable;
    };

    const allocator = gpa.allocator();

    var args = process.args();
    args.deinit();

    var i: u16 = 0;
    var collected_arguments = ArrayList([]u8).init(allocator);

    defer {
        for (collected_arguments.items) |x|
            allocator.free(x);
        collected_arguments.deinit();
    }

    while (args.next()) |argument| : (i += 1) {
        if (i == 0) continue;
        try collected_arguments.append(try allocator.dupe(u8, argument));
    }

    checkCLI(collected_arguments.items) catch |err| {
        switch (err) {
            CLIValidationErrors.InexistentCommand => {
                try stderr.print("error: Command {s} does not exist!\n", .{collected_arguments.items[0]});
                process.exit(1);
            },
            CLIValidationErrors.InvalidArguments => {
                try stderr.print("error: Invalid arguments!\n", .{});
                process.exit(1);
            },
        }
    };

    const command = collected_arguments.items[0];

    if (mem.eql(u8, "init", command)) {
        if (collected_arguments.items.len != 2) {
            try stderr.print("error: you have to specify the shell of initialisation\n", .{});
            process.exit(1);
        }

        const shell = collected_arguments.items[1];

        var init = Init.init(allocator, shell) catch |err| {
            switch (err) {
                Init.InitErrors.InvalidShell => {
                    try stderr.print("error: Invalid provided shell {s}!\n", .{shell});
                    process.exit(1);
                },
                Init.InitErrors.OutOfMemory => {
                    try stderr.print("error: Cannot allocate memory? (OOM)\n", .{});
                    process.exit(1);
                },
            }
        };

        defer init.deinit();

        init.printInitialisationCode() catch {
            try stderr.print("Unable to print initialisation code for shell {s}!\n", .{shell});
            process.exit(1);
        };
    }

    if (mem.eql(u8, "query", command)) {
        if (collected_arguments.items.len != 2) {
            try stderr.print("error: you have to specify the potential path!\n", .{});
            process.exit(1);
        }

        const path = collected_arguments.items[1];

        var query = try Query.init(allocator, path);
        defer query.deinit();

        try query.printMatch();
    }
}
