const std = @import("std");
const FieldOption = @This();

pub const SupportedBoolForm = enum {
    y_n,
    yes_no,
    on_off,
    true_false,

    pub const string_table = [@typeInfo(SupportedBoolForm).@"enum".fields.len][2][]const u8 {
        .{"n", "y"},
        .{"no", "yes"},
        .{"off", "on"},
        .{"false", "true"},
    };

    pub const default = @This().true_false;
    pub const max_len: usize = blk: {
        var longest = 0;
        for (string_table) |entry| {
            for (entry) |s| {
                longest = @max(longest, s.len);
            }
        }
        break :blk longest;
    };

    pub fn isTruthy(string: []const u8) bool {return isAcceptedForm(string, true);}
    pub fn isFalsy(string: []const u8) bool {return isAcceptedForm(string, false);}

    fn isAcceptedForm(string: []const u8, truthy: bool) bool {
        for (string_table) |entry| {
            const expected = entry[@intFromBool(truthy)];
            if (std.mem.eql(u8, string, expected)) return true;
        }

        return false;
    }
};

pub const SupportedIntForm = enum {
    binary,
    octal,
    octal_c, // TODO - Support reading this form *back in* as std.fmt.parseInt does not
    decimal,
    hex_lower,
    hex_upper,

    pub const default = @This().decimal;

    pub inline fn formatString(self: SupportedIntForm) []const u8 {
        return switch (self) {
            .binary => "0b{b}",
            .octal => "0o{o}",
            .octal_c => "0{o}",
            .decimal => "{d}",
            .hex_lower => "0x{x}",
            .hex_upper => "0X{X}",
        };
    }
};

pub const SupportedFloatForm = enum {
    decimal,
    scientific,

    pub const default = @This().decimal;

    pub inline fn formatString(self: SupportedFloatForm) []const u8 {
        return switch (self) {
            .decimal => "{d}",
            .scientific => "{e}",
        };
    }
};

pub const ParseCallback = *const fn (type, *anyopaque, anytype) callconv(.@"inline") anyerror!void;
pub const EncodeCallback = *const fn (type, anytype) callconv(.@"inline") anyerror!*anyopaque;

pub const Settings = struct {
    format: union(enum) {
        default: void,
        boolean: SupportedBoolForm,
        int: SupportedIntForm,
        float: SupportedFloatForm,
    } = .default,
    T: ?type = null,
    parse_cb: ?ParseCallback = null,
    encode_cb: ?EncodeCallback = null,
    flags: packed struct {
        output_default_value: bool = false,
    } = .{},
};

field_name: []const u8,
settings: Settings,

pub inline fn define(parent: type, field_name: []const u8, settings: Settings) FieldOption {
    const info = @typeInfo(parent);
    if (info != .@"struct") unreachable;
    var field_exists = false;

    inline for (info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, field_name)) {
            field_exists = true;
            break;
        }
    }
    if (!field_exists) unreachable;

    return FieldOption{
        .field_name = @typeName(parent) ++ field_name,
        .settings = settings
    };
}

pub inline fn parseArrayList(comptime T: type, target: *anyopaque, raw: anytype) anyerror!void {
    const slice: T = raw;
    var list: *std.ArrayList(@typeInfo(T).pointer.child) = @alignCast(@ptrCast(target));
    try list.appendSlice(slice);
}

pub inline fn encodeArrayList(comptime T: type, input: anytype) anyerror!*anyopaque {
    const list_type = @typeInfo(T).pointer.child;
    const list: std.ArrayList(list_type) = input;
    return @ptrCast(@constCast(&list.items));
}