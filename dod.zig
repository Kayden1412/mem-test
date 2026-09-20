const std = @import("std");
const Io = std.Io;
const Clock = Io.Clock;
const GradeArr = std.EnumArray(Monster.Grade, usize);
const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-";
const N = 1e5;

const Monster = struct {
    level: u32,
    grade: Grade,
    element: Element,
    name: []const u8,

    const Element = enum {
        water,
        fire,
        earth,
        wind,
        lightning,
    };
    const Grade = enum { a, b, c, d, e };
    const V2 = struct {
        level: []u32,
        grade: []Monster.Grade,
        element: []Monster.Element,
        name: [][]const u8,
    };
};

fn printGradeCount(
    grade_arr: GradeArr,
    writer: *Io.Writer,
) !void {
    inline for (std.enums.values(Monster.Grade)) |grade| {
        try writer.print("Grade {c}: {d}\n", .{
            std.ascii.toUpper(@tagName(grade)[0]),
            grade_arr.get(grade),
        });
    }
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    const gpa = arena.allocator();
    const io = init.io;

    var stdout_writer = Io.File.stdout().writer(io, &.{});
    const stdout = &stdout_writer.interface;

    var stderr_writer = Io.File.stderr().writer(io, &.{});
    const stderr = &stderr_writer.interface;

    var rand = std.Random.DefaultPrng.init(@intCast(std.Io.Timestamp.now(io, .real).toMicroseconds()));
    const rng = rand.random();
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    const count = std.fmt.parseInt(usize, if (args.len >= 2) args[1] else "100_000", 10) catch |err| {
        switch (err) {
            error.InvalidCharacter => {
                for (args[1], 0..) |c, i| {
                    if (!std.ascii.isDigit(c)) {
                        try stderr.print("./dod {s}\n", .{args[1]});
                        _ = try stderr.splatByte(' ', 6 + i);
                        try stderr.writeAll("^\n");
                        try stderr.print("Invalid Char {c} at pos {d}\n", .{
                            c,
                            i + 1,
                        });
                        std.process.exit(1);
                    }
                }
            },
            error.Overflow => std.process.fatal("{s} can't fit in usize\n", .{args[1]}),
        }
        unreachable;
    };

    try stdout.print("{d} Monsters\n", .{count});

    {
        const mons = try gpa.alloc(Monster, count);
        var grade_arr: GradeArr = .initFill(0);

        defer {
            const free_time = Clock.now(.awake, io);
            _ = arena.reset(.free_all);
            stdout.print("Free Time: {f}\n", .{free_time.untilNow(io, .awake)}) catch unreachable;
        }

        const gen_start = Clock.now(.awake, io);
        for (mons) |*m| {
            m.* = Monster{
                .level = rng.intRangeAtMost(u32, 1, 100),
                .element = rng.enumValue(Monster.Element),
                .grade = rng.enumValue(Monster.Grade),
                .name = blk: {
                    const len = rng.intRangeLessThan(usize, 3, 20);
                    const name = try gpa.alloc(u8, len);
                    rng.bytes(name);
                    break :blk name;
                },
            };
        }
        const gen_end = gen_start.untilNow(io, .awake);
        const start = Clock.now(.awake, io);

        const min_lvl, const max_lvl, const avg_lvl = blk: {
            var max: u32 = 0;
            var min: u32 = 1;
            var sum: usize = 0;
            for (mons) |m| {
                min = @min(min, m.level);
                max = @max(max, m.level);
                sum += m.level;
            }
            break :blk .{ min, max, sum / mons.len };
        };
        for (mons) |m| {
            grade_arr.set(m.grade, grade_arr.get(m.grade) + 1);
        }

        const end = start.untilNow(io, .awake);
        try stdout.print(
            \\AOS
            \\Gen: {f}
            \\Calc: {f}
            \\Min Lvl: {d}
            \\Max Lvl: {d}
            \\Avg Lvl: {d}
            \\
        , .{
            gen_end,
            end,
            min_lvl,
            max_lvl,
            avg_lvl,
        });

        try printGradeCount(grade_arr, stdout);
    }

    {
        var mons: Monster.V2 = .{
            .level = try gpa.alloc(u32, count),
            .grade = try gpa.alloc(Monster.Grade, count),
            .element = try gpa.alloc(Monster.Element, count),
            .name = try gpa.alloc([]const u8, count),
        };

        var grade_arr: GradeArr = .initFill(0);

        defer {
            const free_time = Clock.now(.awake, io);
            _ = arena.reset(.free_all);
            stdout.print("Free Time: {f}\n", .{free_time.untilNow(io, .awake)}) catch unreachable;
        }

        const gen_start = Clock.now(.awake, io);
        for (0..count) |i| {
            mons.level[i] = rng.intRangeAtMost(u32, 1, 100);
            mons.element[i] = rng.enumValue(Monster.Element);
            mons.grade[i] = rng.enumValue(Monster.Grade);
            mons.name[i] = blk: {
                const len = rng.intRangeLessThan(usize, 3, 20);
                const name = try gpa.alloc(u8, len);
                rng.bytes(name);
                break :blk name;
            };
        }
        const gen_end = gen_start.untilNow(io, .awake);
        const start = Clock.now(.awake, io);

        const min_lvl, const max_lvl, const avg_lvl = blk: {
            const Vec = @Vector(4, u32);
            const vec_len = mons.level.len / 4;
            var vec_min: Vec = @splat(100);
            var vec_max: Vec = @splat(1);
            var vec_sum: Vec = @splat(0);

            for (0..vec_len) |i| {
                const offset = i * 4;
                const vec: Vec = mons.level[offset..][0..4].*;
                vec_min = @min(vec_min, vec);
                vec_max = @max(vec_max, vec);
                vec_sum += vec;
            }

            var min: u32 = 100;
            var max: u32 = 1;
            var sum: usize = 0;
            for (@as([4]u32, @bitCast(vec_min))) |v| min = @min(min, v);
            for (@as([4]u32, @bitCast(vec_max))) |v| max = @max(max, v);
            for (@as([4]u32, @bitCast(vec_sum))) |v| sum += v;

            for (mons.level[vec_len * 4 ..]) |m| {
                min = @min(min, m);
                max = @max(max, m);
                sum += m;
            }

            break :blk .{ min, max, sum / count };
        };

        for (mons.grade) |grade| grade_arr.set(grade, grade_arr.get(grade) + 1);

        const end = start.untilNow(io, .awake);

        try stdout.print(
            \\SOA
            \\Gen: {f}
            \\Calc: {f}
            \\Min Lvl: {d}
            \\Max Lvl: {d}
            \\Avg Lvl: {d}
            \\
        , .{
            gen_end,
            end,
            min_lvl,
            max_lvl,
            avg_lvl,
        });
        try printGradeCount(grade_arr, stdout);
    }

    {
        var mons: std.MultiArrayList(Monster) = try .initCapacity(gpa, count);
        var grade_arr: GradeArr = .initFill(0);
        defer {
            const free_time = Clock.now(.awake, io);
            _ = arena.reset(.free_all);
            stdout.print("Free Time: {f}\n", .{free_time.untilNow(io, .awake)}) catch unreachable;
        }

        const gen_start = Clock.now(.awake, io);
        for (0..count) |_| {
            try mons.append(gpa, Monster{
                .level = rng.intRangeAtMost(u32, 1, 100),
                .element = rng.enumValue(Monster.Element),
                .grade = rng.enumValue(Monster.Grade),
                .name = blk: {
                    const len = rng.intRangeLessThan(usize, 3, 20);
                    const name = try gpa.alloc(u8, len);
                    rng.bytes(name);
                    break :blk name;
                },
            });
        }

        const gen_end = gen_start.untilNow(io, .awake);
        const start = Clock.now(.awake, io);

        const min_lvl, const max_lvl, const avg_lvl = blk: {
            var max: u32 = 0;
            var min: u32 = 1;
            var sum: usize = 0;

            for (mons.items(.level)) |m| {
                min = @min(min, m);
                max = @max(max, m);
                sum += m;
            }
            break :blk .{ min, max, sum / count };
        };

        for (mons.items(.grade)) |grade| grade_arr.set(grade, grade_arr.get(grade) + 1);

        const end = start.untilNow(io, .awake);
        std.debug.print(
            \\SOA MultiArrayList
            \\Gen: {f}
            \\Calc: {f}
            \\Min Lvl: {d}
            \\Max Lvl: {d}
            \\Avg Lvl: {d}
            \\
        , .{
            gen_end,
            end,
            min_lvl,
            max_lvl,
            avg_lvl,
        });
        try printGradeCount(grade_arr, stdout);
    }
}
