const std = @import("std");
const mem = std.mem;
const stringify = @import("../stringify.zig").stringify;
const testing = std.testing;

const Arena = std.heap.ArenaAllocator;
const Yaml = @import("../Yaml.zig");
const FieldOption = @import("../FieldOption.zig");

test "simple list" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const list = yaml.docs.items[0].list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple list typed as array of strings" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3][]const u8);
    try testing.expectEqual(3, arr.len);
    try testing.expectEqualStrings("a", arr[0]);
    try testing.expectEqualStrings("b", arr[1]);
    try testing.expectEqualStrings("c", arr[2]);
}

test "simple list typed as array of ints" {
    const source =
        \\- 0
        \\- 1
        \\- 2
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3]u8);
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 2 }, &arr);
}

test "list of mixed sign integer" {
    const source =
        \\- 0
        \\- -1
        \\- 2
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3]i8);
    try testing.expectEqualSlices(i8, &[_]i8{ 0, -1, 2 }, &arr);
}

test "several integer bases" {
    const source =
        \\- 10
        \\- -10
        \\- 0x10
        \\- -0X10
        \\- 0o10
        \\- -0O10
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [6]i8);
    try testing.expectEqualSlices(i8, &[_]i8{ 10, -10, 16, -16, 8, -8 }, &arr);
}

test "bools" {
    const source =
        \\- false
        \\- true
        \\- off
        \\- on
        \\- no
        \\- yes
        \\- n
        \\- y
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [8]bool);
    try testing.expectEqualSlices(bool, &[_]bool{ false, true, false, true, false, true, false, true, }, &arr);
}

const TestEnum = enum {
    alpha,
    bravo,
    charlie,
};

test "enums" {
    const source =
        \\- alpha
        \\- bravo
        \\- charlie
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3]TestEnum);
    try testing.expectEqualSlices(TestEnum, &[_]TestEnum{ .alpha, .bravo, .charlie }, &arr);
}

test "invalid enum" {
    const source =
        \\- delta
        \\- echo
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = yaml.parse(arena.allocator(), [2]TestEnum);
    try testing.expectError(Yaml.Error.EnumTagMissing, result);
}

test "simple map untyped" {
    const source =
        \\a: 0
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
}

test "simple map untyped with a list of maps" {
    const source =
        \\a: 0
        \\b:
        \\  - foo: 1
        \\    bar: 2
        \\  - foo: 3
        \\    bar: 4
        \\c: 1
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
    try testing.expectEqualStrings("2", map.get("b").?.list[0].map.get("bar").?.scalar);
    try testing.expectEqualStrings("3", map.get("b").?.list[1].map.get("foo").?.scalar);
    try testing.expectEqualStrings("4", map.get("b").?.list[1].map.get("bar").?.scalar);
}

test "simple map untyped with a list of maps. no indent" {
    const source =
        \\b:
        \\- foo: 1
        \\c: 1
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
}

test "simple map untyped with a list of maps. no indent 2" {
    const source =
        \\a: 0
        \\b:
        \\- foo: 1
        \\  bar: 2
        \\- foo: 3
        \\  bar: 4
        \\c: 1
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
    try testing.expectEqualStrings("2", map.get("b").?.list[0].map.get("bar").?.scalar);
    try testing.expectEqualStrings("3", map.get("b").?.list[1].map.get("foo").?.scalar);
    try testing.expectEqualStrings("4", map.get("b").?.list[1].map.get("bar").?.scalar);
}

test "simple map typed" {
    const source =
        \\a: 0
        \\b: hello there
        \\c: 'wait, what?'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct { a: usize, b: []const u8, c: []const u8 });
    try testing.expectEqual(@as(usize, 0), simple.a);
    try testing.expectEqualStrings("hello there", simple.b);
    try testing.expectEqualStrings("wait, what?", simple.c);
}

test "struct fields with default values" {
    const source =
        \\c: 'wait, what?'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a: usize = 0,
        b: []const u8 = "hello there",
        c: []const u8
    });
    try testing.expectEqual(@as(usize, 0), simple.a);
    try testing.expectEqualStrings("hello there", simple.b);
    try testing.expectEqualStrings("wait, what?", simple.c);
}

test "typed nested structs" {
    const source =
        \\a:
        \\  b: hello there
        \\  c: 'wait, what?'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a: struct {
            b: []const u8,
            c: []const u8,
        },
    });
    try testing.expectEqualStrings("hello there", simple.a.b);
    try testing.expectEqualStrings("wait, what?", simple.a.c);
}

test "typed union with nested struct" {
    const source =
        \\a:
        \\  b: hello there
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), union(enum) {
        tag_a: struct {
            a: struct {
                b: []const u8,
            },
        },
        tag_c: struct {
            c: struct {
                d: []const u8,
            },
        },
    });
    try testing.expectEqualStrings("hello there", simple.tag_a.a.b);
}

test "typed union with nested struct 2" {
    const source =
        \\c:
        \\  d: hello there
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), union(enum) {
        tag_a: struct {
            a: struct {
                b: []const u8,
            },
        },
        tag_c: struct {
            c: struct {
                d: []const u8,
            },
        },
    });
    try testing.expectEqualStrings("hello there", simple.tag_c.c.d);
}

test "single quoted string" {
    const source =
        \\- 'hello'
        \\- 'here''s an escaped quote'
        \\- 'newlines and tabs\nare not\tsupported'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3][]const u8);
    try testing.expectEqual(arr.len, 3);
    try testing.expectEqualStrings("hello", arr[0]);
    try testing.expectEqualStrings("here's an escaped quote", arr[1]);
    try testing.expectEqualStrings("newlines and tabs\\nare not\\tsupported", arr[2]);
}

test "double quoted string" {
    const source =
        \\- "hello"
        \\- "\"here\" are some escaped quotes"
        \\- "newlines and tabs\nare\tsupported"
        \\- "let's have
        \\some fun!"
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [4][]const u8);
    try testing.expectEqual(arr.len, 4);
    try testing.expectEqualStrings("hello", arr[0]);
    try testing.expectEqualStrings(
        \\"here" are some escaped quotes
    , arr[1]);
    try testing.expectEqualStrings("newlines and tabs\nare\tsupported", arr[2]);
    try testing.expectEqualStrings(
        \\let's have
        \\some fun!
    , arr[3]);
}

test "commas in string" {
    const source =
        \\a: 900,50,50
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a: []const u8,
    });
    try testing.expectEqualStrings("900,50,50", simple.a);
}

test "multidoc typed as a slice of structs" {
    const source =
        \\---
        \\a: 0
        \\---
        \\a: 1
        \\...
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    {
        const result = try yaml.parse(arena.allocator(), [2]struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }

    {
        const result = try yaml.parse(arena.allocator(), []struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }
}

test "multidoc typed as a struct is an error" {
    const source =
        \\---
        \\a: 0
        \\---
        \\b: 1
        \\...
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), struct { a: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), struct { b: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), struct { a: usize, b: usize }));
}

test "multidoc typed as a slice of structs with optionals" {
    const source =
        \\---
        \\a: 0
        \\c: 1.0
        \\---
        \\a: 1
        \\b: different field
        \\...
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = try yaml.parse(arena.allocator(), []struct { a: usize, b: ?[]const u8, c: ?f16 });
    try testing.expectEqual(result.len, 2);

    try testing.expectEqual(result[0].a, 0);
    try testing.expect(result[0].b == null);
    try testing.expect(result[0].c != null);
    try testing.expectEqual(result[0].c.?, 1.0);

    try testing.expectEqual(result[1].a, 1);
    try testing.expect(result[1].b != null);
    try testing.expectEqualStrings("different field", result[1].b.?);
    try testing.expect(result[1].c == null);
}

test "empty yaml can be represented as void" {
    const source = "";

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = try yaml.parse(arena.allocator(), void);
    try testing.expect(@TypeOf(result) == void);
}

test "nonempty yaml cannot be represented as void" {
    const source =
        \\a: b
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), void));
}

test "typed array size mismatch" {
    const source =
        \\- 0
        \\- 0
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse(arena.allocator(), [1]usize));
    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse(arena.allocator(), [5]usize));
}

test "comments" {
    const source =
        \\
        \\key: # this is the key
        \\# first value
        \\
        \\- val1
        \\
        \\# second value
        \\- val2
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        key: []const []const u8,
    });
    try testing.expect(simple.key.len == 2);
    try testing.expectEqualStrings("val1", simple.key[0]);
    try testing.expectEqualStrings("val2", simple.key[1]);
}

test "promote ints to floats in a list mixed numeric types" {
    const source =
        \\a_list: [0, 1.0]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a_list: []const f64,
    });
    try testing.expectEqualSlices(f64, &[_]f64{ 0.0, 1.0 }, simple.a_list);
}

test "demoting floats to ints in a list is an error" {
    const source =
        \\a_list: [0, 1.0]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(error.InvalidCharacter, yaml.parse(arena.allocator(), struct {
        a_list: []const u64,
    }));
}

test "duplicate map keys" {
    const source =
        \\a: b
        \\a: c
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try testing.expectError(error.DuplicateMapKey, yaml.load(testing.allocator));
}

fn testStringifyWithOptions(expected: []const u8, input: anytype, comptime options: ?[]const FieldOption) !void {
    var output = std.ArrayList(u8).init(testing.allocator);
    defer output.deinit();

    try stringify(testing.allocator, input, output.writer(), options);
    try testing.expectEqualStrings(expected, output.items);
}

fn testStringify(expected: []const u8, input: anytype) !void { 
    return testStringifyWithOptions(expected, input, null);
}

test "stringify an int" {
    try testStringify("128", @as(u32, 128));
}

test "stringify ints in different formats" {
    const Struct = struct {
        bin: u32,
        oct: u32,
        oct_c: u32,
        dec: u32,
        hex: u32,
        HEX: u32,
        def: u32,
        def_int: u32,
    };

    const vals = Struct{
        .bin = 0b110011011,
        .oct = 0o101,
        .oct_c = 0o174,
        .dec = 4816,
        .hex = 0x192a3b4c,
        .HEX = 0x5D6E7F80,
        .def = 2698741,
        .def_int = 42949842,
    };

    const options = [_]FieldOption{
        FieldOption.define(Struct, "bin", .{ .format = .{ .int = .binary } }),
        FieldOption.define(Struct, "oct", .{ .format = .{ .int = .octal } }),
        FieldOption.define(Struct, "oct_c", .{ .format = .{ .int = .octal_c } }),
        FieldOption.define(Struct, "dec", .{ .format = .{ .int = .decimal } }),
        FieldOption.define(Struct, "hex", .{ .format = .{ .int = .hex_lower } }),
        FieldOption.define(Struct, "HEX", .{ .format = .{ .int = .hex_upper } }),
        FieldOption.define(Struct, "def", .{}),
        FieldOption.define(Struct, "def_int", .{ .format = .{ .int = .default } }),
    };

    try testStringifyWithOptions(
        \\bin: 0b110011011
        \\oct: 0o101
        \\oct_c: 0174
        \\dec: 4816
        \\hex: 0x192a3b4c
        \\HEX: 0X5D6E7F80
        \\def: 2698741
        \\def_int: 42949842
        , vals, &options);
}

test "stringify int with invalid format option" {
    const Struct = struct {
        int: u32,
    };

    try testing.expectError(error.TypeMismatch, testStringifyWithOptions("", Struct{.int = 10},
        &[_]FieldOption{FieldOption.define(Struct, "int", .{ .format = .{ .float = .decimal } })}));
}

test "stringify a float" {
    try testStringify("128.386", @as(f32, 128.386));
}

test "stringify floats in different formats" {
    const Struct = struct {
        dec: f32,
        exp: f32,
        def: f32,
        def_flt: f32,
    };

    const vals = Struct{
        .dec = 4816.167,
        .exp = 7.115e14,
        .def = 116.198,
        .def_flt = 981.6512,
    };

    const options = [_]FieldOption{
        FieldOption.define(Struct, "dec", .{ .format = .{ .float = .decimal } }),
        FieldOption.define(Struct, "exp", .{ .format = .{ .float = .scientific } }),
        FieldOption.define(Struct, "def", .{}),
        FieldOption.define(Struct, "def_flt", .{ .format = .{ .float = .default } }),
    };

    try testStringifyWithOptions(
        \\dec: 4816.167
        \\exp: 7.115e14
        \\def: 116.198
        \\def_flt: 981.6512
        , vals, &options);
}

test "stringify float with invalid format option" {
    const Struct = struct {
        float: f32,
    };

    try testing.expectError(error.TypeMismatch, testStringifyWithOptions("", Struct{.float = 10.13},
        &[_]FieldOption{FieldOption.define(Struct, "float", .{ .format = .{ .boolean = .on_off } })}));
}

test "stringify a simple struct" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });
}

test "stringify a struct with an optional" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });

    try testStringify(
        \\a: 1
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = null, .c = 2.5 });
}

const StructOfFloatsWithADefault = struct { a: i64, b: f64 = 1.5, c: f64 };

test "stringify a struct with a default value" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , StructOfFloatsWithADefault{ .a = 1, .b = 2.0, .c = 2.5 });

    try testStringify(
        \\a: 1
        \\c: 2.5
    , StructOfFloatsWithADefault{ .a = 1, .b = 1.5, .c = 2.5 });
}

test "stringify a struct and force a default value to be included" {
    try testStringifyWithOptions(
        \\a: 1
        \\b: 1.5
        \\c: 2.5
    , StructOfFloatsWithADefault{ .a = 1, .b = 1.5, .c = 2.5 }
    , &[_]FieldOption{FieldOption.define(
        StructOfFloatsWithADefault,
        "b",
        .{ .flags = .{.output_default_value = true }})});
}

test "stringify a struct with all optionals" {
    try testStringify("", struct { a: ?i64, b: ?f64 }{ .a = null, .b = null });
}

test "stringify an optional" {
    try testStringify("", null);
    try testStringify("", @as(?u64, null));
}

test "stringify a union" {
    const Dummy = union(enum) {
        x: u64,
        y: f64,
    };
    try testStringify("a: 1", struct { a: Dummy }{ .a = .{ .x = 1 } });
    try testStringify("a: 2.1", struct { a: Dummy }{ .a = .{ .y = 2.1 } });
}

test "stringify a string" {
    try testStringify("a: name", struct { a: []const u8 }{ .a = "name" });
    try testStringify("name", "name");
}

test "stringify a list" {
    try testStringify("[ 1, 2, 3 ]", @as([]const u64, &.{ 1, 2, 3 }));
    try testStringify("[ 1, 2, 3 ]", .{ @as(i64, 1), 2, 3 });
    try testStringify("[ 1, name, 3 ]", .{ 1, "name", 3 });

    const arr: [3]i64 = .{ 1, 2, 3 };
    try testStringify("[ 1, 2, 3 ]", arr);
}

test "stringify a bool" {
    try testStringify("false", false);
    try testStringify("true", true);
}

test "stringify bools differently" {
    const BoolStruct = struct {
        a: bool,
        b: bool,
        c: bool,
        d: bool,
    };

    const options = [_]FieldOption{
        FieldOption.define(BoolStruct, "a", .{ .format = .{ .boolean = .y_n }}),
        FieldOption.define(BoolStruct, "b", .{ .format = .{ .boolean = .yes_no }}),
        FieldOption.define(BoolStruct, "c", .{ .format = .{ .boolean = .on_off }}),
        FieldOption.define(BoolStruct, "d", .{ .format = .{ .boolean = .true_false }}),
    };

    try testStringifyWithOptions(
        \\a: n
        \\b: no
        \\c: off
        \\d: false
    , BoolStruct{ .a = false, .b = false, .c = false, .d = false }
    , &options);

    try testStringifyWithOptions(
        \\a: y
        \\b: yes
        \\c: on
        \\d: true
    , BoolStruct{ .a = true, .b = true, .c = true, .d = true }
    , &options);
}

test "stringify an enum" {
    try testStringify("alpha", TestEnum.alpha);
    try testStringify("bravo", TestEnum.bravo);
    try testStringify("charlie", TestEnum.charlie);
}
