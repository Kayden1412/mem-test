const std = @import("std");
const GradeArr = std.EnumArray(Monster.Grade, usize);
const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-";
const N = 1e5;

const CountingAllocator = struct {
    child: std.mem.Allocator,
    bytes_allocated: usize = 0,
    alloc_count: usize = 0,
    resize_count: usize = 0,
    remap_count: usize = 0,

    pub fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        ptr_align: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.bytes_allocated += len;
        self.alloc_count += 1;
        return self.child.vtable.alloc(self.child.ptr, len, ptr_align, ret_addr);
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        if (new_len > buf.len) {
            self.bytes_allocated += new_len - buf.len; // nambah
        } else {
            self.bytes_allocated -= buf.len - new_len; // ngurang
        }
        self.resize_count += 1;
        return self.child.vtable.resize(self.child.ptr, buf, buf_align, new_len, ret_addr);
    }

    fn remap(
        ctx: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        // remap = free lama + alloc baru. Jadi update hitungannya
        self.bytes_allocated -= memory.len;
        self.bytes_allocated += new_len;
        self.remap_count += 1;
        return self.child.vtable.remap(self.child.ptr, memory, alignment, new_len, ret_addr);
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.bytes_allocated -= buf.len;
        self.child.vtable.free(self.child.ptr, buf, buf_align, ret_addr);
    }
};
//
// //
// //
// //
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

    const Grade = enum {
        a,
        b,
        c,
        d,
        e,
    };
};

const MonsterV2 = struct {
    level: []u32,
    grade: []Monster.Grade,
    element: []Monster.Element,
    name: [][]const u8,
};

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    const gpa = arena.allocator();
    const io = init.io;

    var rand = std.Random.DefaultPrng.init(@intCast(std.Io.Timestamp.now(io, .real).toMicroseconds()));
    const rng = rand.random();
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    const count = std.fmt.parseInt(usize, if (args.len >= 2) args[1] else "100_000", 10) catch |err| {
        switch (err) {
            error.InvalidCharacter => {
                for (args[1], 0..) |c, i| {
                    if (!std.ascii.isDigit(c)) {
                        std.debug.print("./dod {s}\n", .{args[1]});
                        for (0..(6 + i)) |_| std.debug.print(" ", .{});
                        std.debug.print("^\n", .{});
                        std.process.fatal("Invalid Char {c} at pos {d}\n", .{
                            c,
                            i + 1,
                        });
                    }
                }
            },
            error.Overflow => std.process.fatal("{s} can't fit in usize\n", .{args[1]}),
        }
        unreachable;
    };

    std.debug.print("{d} Monsters\n", .{count});
    {
        const mons = try gpa.alloc(Monster, count);

        var grade_arr: std.EnumArray(Monster.Grade, usize) = .initFill(0);

        defer {
            const free_time = std.Io.Clock.now(.awake, io);
            _ = arena.reset(.free_all);
            // for (mons) |m| gpa.free(m.name);
            //gpa.free(mons);
            std.debug.print("Free Time: {f}\n", .{free_time.untilNow(io, .awake)});
        }

        const gen_start = std.Io.Clock.now(.awake, io);
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
        const start = std.Io.Clock.now(.awake, io);

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
        std.debug.print(
            \\AOS
            \\Gen: {f}
            \\Calc: {f}
            \\Min Lvl: {d}
            \\Max Lvl: {d}
            \\Avg Lvl: {d}
            \\Grade A: {d}
            \\Grade B: {d}
            \\Grade C: {d}
            \\Grade: D: {d}
            \\Grade E: {d}
            \\
        , .{
            gen_end,
            end,
            min_lvl,
            max_lvl,
            avg_lvl,
            grade_arr.get(.a),
            grade_arr.get(.b),
            grade_arr.get(.c),
            grade_arr.get(.d),
            grade_arr.get(.e),
        });
    }

    {
        var mons: MonsterV2 = .{
            .level = try gpa.alloc(u32, count),
            .grade = try gpa.alloc(Monster.Grade, count),
            .element = try gpa.alloc(Monster.Element, count),
            .name = try gpa.alloc([]const u8, count),
        };

        var grade_arr: std.EnumArray(Monster.Grade, usize) = .initFill(0);

        defer {
            const free_time = std.Io.Clock.now(.awake, io);
            _ = arena.reset(.free_all);
            std.debug.print("Free Time: {f}\n", .{free_time.untilNow(io, .awake)});
        }

        const gen_start = std.Io.Clock.now(.awake, io);
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
        const start = std.Io.Clock.now(.awake, io);
        //
        // const min_lvl, const max_lvl, const avg_lvl = blk: {
        //     var max: u32 = 0;
        //     var min: u32 = 1;
        //     var sum: usize = 0;
        //     for (mons.level) |m| {
        //         min = @min(min, m);
        //         max = @max(max, m);
        //         sum += m;
        //     }
        //     break :blk .{ min, max, sum / count };
        // };

        const min_lvl, const max_lvl, const avg_lvl = blk: {
            const Vec = @Vector(4, u32); // 8x u32 = 256bit. Ganti 16 kalo CPU support AVX512
            const vec_len = mons.level.len / 4;
            //const rem_len = mons.level.len % 8;

            var vec_min: Vec = @splat(100); // init max
            var vec_max: Vec = @splat(1); // init min
            var vec_sum: Vec = @splat(0);

            // Loop vector
            for (0..vec_len) |i| {
                const offset = i * 4;
                const vec: Vec = mons.level[offset..][0..4].*; // load 8 u32 sekaligus
                vec_min = @min(vec_min, vec);
                vec_max = @max(vec_max, vec);
                vec_sum += vec;
            }

            // Reduce vector ke scalar
            var min: u32 = 100;
            var max: u32 = 1;
            var sum: usize = 0;
            for (@as([4]u32, @bitCast(vec_min))) |v| min = @min(min, v);
            for (@as([4]u32, @bitCast(vec_max))) |v| max = @max(max, v);
            for (@as([4]u32, @bitCast(vec_sum))) |v| sum += v;

            // Sisa yang nggak pas 8
            for (mons.level[vec_len * 4 ..]) |m| {
                min = @min(min, m);
                max = @max(max, m);
                sum += m;
            }

            break :blk .{ min, max, sum / count };
        };

        for (mons.grade) |grade| grade_arr.set(grade, grade_arr.get(grade) + 1);

        const end = start.untilNow(io, .awake);

        std.debug.print(
            \\SOA
            \\Gen: {f}
            \\Calc: {f}
            \\Min Lvl: {d}
            \\Max Lvl: {d}
            \\Avg Lvl: {d}
            \\Grade A: {d}
            \\Grade B: {d}
            \\Grade C: {d}
            \\Grade: D: {d}
            \\Grade E: {d}
            \\
        , .{
            gen_end,
            end,
            min_lvl,
            max_lvl,
            avg_lvl,
            grade_arr.get(.a),
            grade_arr.get(.b),
            grade_arr.get(.c),
            grade_arr.get(.d),
            grade_arr.get(.e),
        });
    }

    {
        var mons: std.MultiArrayList(Monster) = try .initCapacity(gpa, count);
        var grade_arr: std.EnumArray(Monster.Grade, usize) = .initFill(0);
        defer {
            const free_time = std.Io.Clock.now(.awake, io);
            _ = arena.reset(.free_all);

            std.debug.print("Free Time: {f}\n", .{free_time.untilNow(io, .awake)});
        }

        const gen_start = std.Io.Clock.now(.awake, io);
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
        const start = std.Io.Clock.now(.awake, io);

        const min_lvl, const max_lvl, const avg_lvl = blk: {
            var max: u32 = 0;
            var min: u32 = 1;
            var sum: usize = 0;

            for (mons.items(.level)) |m| {
                //std.debug.print("Lvl: {d}\n", .{m});
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
            \\Grade A: {d}
            \\Grade B: {d}
            \\Grade C: {d}
            \\Grade: D: {d}
            \\Grade E: {d}
            \\
        , .{
            gen_end,
            end,
            min_lvl,
            max_lvl,
            avg_lvl,
            grade_arr.get(.a),
            grade_arr.get(.b),
            grade_arr.get(.c),
            grade_arr.get(.d),
            grade_arr.get(.e),
        });
    }
}
