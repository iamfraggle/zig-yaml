const std = @import("std");

const Yaml = @import("Yaml.zig");
const FieldOption = @import("FieldOption.zig");

pub fn stringify(gpa: std.mem.Allocator, input: anytype, writer: anytype, comptime options: ?[]const FieldOption) Yaml.StringifyError!void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const maybe_value = try Yaml.Value.encode(arena.allocator(), options, input, null);

    if (maybe_value) |value| {
        // TODO should we output as an explicit doc?
        // How can allow the user to specify?
        try value.stringify(writer, .{});
    }
}
