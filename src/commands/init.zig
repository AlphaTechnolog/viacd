const std = @import("std");

const mem = std.mem;
const io = std.io;

const Self = @This();
const stdout = io.getStdOut().writer();

const known_shells = [_][]const u8{"bash"};

allocator: mem.Allocator,
shell: []const u8,

pub const ShellValidationError = error{InvalidShell};
pub const InitErrors = mem.Allocator.Error || ShellValidationError;
pub const InitialisationCodeError = error{CannotFindInitialisationCode};

pub fn init(allocator: mem.Allocator, shell: []const u8) InitErrors!*Self {
    var instance = try allocator.create(Self);
    instance.allocator = allocator;
    instance.shell = shell;
    try instance.checkShell();
    return instance;
}

fn checkShell(self: *Self) ShellValidationError!void {
    for (known_shells) |shell| {
        if (mem.eql(u8, self.shell, shell)) {
            return;
        }
    }

    return error.InvalidShell;
}

fn obtainInitialisationCode(self: *Self) InitialisationCodeError![]const u8 {
    const bashInitialisationCode = @embedFile("../initialisations/bash.init.sh");

    if (mem.eql(u8, self.shell, "bash")) {
        return bashInitialisationCode;
    }

    return InitialisationCodeError.CannotFindInitialisationCode;
}

pub fn printInitialisationCode(self: *Self) !void {
    const initialisation_code = try self.obtainInitialisationCode();
    try stdout.print("{s}\n", .{initialisation_code});
}

pub fn deinit(self: *Self) void {
    self.allocator.destroy(self);
}
