const std = @import("std");

pub fn ArrayLookupTable(comptime Key: type, comptime Value: type, comptime size: usize) type {
    return struct {
        const Self = @This();

        pub const K = Key;
        pub const V = Value;

        table: []Value,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const table = try allocator.alloc(Value, size);
            errdefer allocator.free(table);
            return .{ .table = table };
        }

        pub fn fromSlice(allocator: std.mem.Allocator, slice: []u8) !Self {
            if (slice.len != size * @sizeOf(Value)) return error.InvalidTableSize;
            const table = try allocator.alloc(Value, size);
            @memcpy(std.mem.sliceAsBytes(table), slice);
            return Self{ .table = table };
        }

        pub fn toSlice(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
            const table = try allocator.dupe(Value, self.table);
            return std.mem.sliceAsBytes(table);
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.table);
            self.* = undefined;
        }

        pub fn fill(self: *Self, value: Value) void {
            @memset(self.table, value);
        }

        pub inline fn get(self: *const Self, key: Key) Value {
            return self.table[key % size];
        }

        pub inline fn set(self: *Self, key: Key, value: Value) void {
            self.table[key % size] = value;
        }
    };
}

pub fn SlidingWindowIterator(comptime size: usize) type {
    return struct {
        const Self = @This();

        data: []const u8,
        index: usize,

        pub inline fn init(data: []const u8) Self {
            return .{
                .data = data,
                .index = 0,
            };
        }

        pub inline fn reset(self: *Self) Self {
            self.index = 0;
        }

        pub inline fn next(self: *Self) ?[]const u8 {
            if (self.data.len < size) return null;
            if (self.index > self.data.len - size) return null;
            const data = self.data[self.index..][0..size];
            self.index += 1;
            return data;
        }
    };
}

test SlidingWindowIterator {
    const data = "AABBCC";
    const Windows = SlidingWindowIterator(2);
    var window_iterator = Windows.init(data);
    try std.testing.expectEqualStrings("AA", window_iterator.next().?);
    try std.testing.expectEqualStrings("AB", window_iterator.next().?);
    try std.testing.expectEqualStrings("BB", window_iterator.next().?);
    try std.testing.expectEqualStrings("BC", window_iterator.next().?);
    try std.testing.expectEqualStrings("CC", window_iterator.next().?);
    try std.testing.expectEqual(null, window_iterator.next());
}

fn fibonacciPrime(comptime bits: comptime_int) comptime_int {
    const target: comptime_int = 5 << (2 * (bits - 1));
    var x: comptime_int = @as(comptime_int, 1) << (bits + 1);
    while (true) {
        const next = (x + target / x) >> 1;
        if (next >= x) break;
        x = next;
    }
    return (x - (@as(comptime_int, 1) << (bits - 1))) | 1;
}

pub fn SliceHasher(comptime Data: type, comptime Hash: type, comptime seed: Hash) type {
    const data_info = @typeInfo(Data);
    const hash_info = @typeInfo(Hash);

    if (data_info != .int or data_info.int.signedness != .unsigned)
        @compileError("SliceHasher requires an unsigned integer Data type, got: " ++ @typeName(Data));
    if (hash_info != .int or hash_info.int.signedness != .unsigned)
        @compileError("SliceHasher requires an unsigned integer Hash type, got: " ++ @typeName(Hash));
    if (@bitSizeOf(Data) > @bitSizeOf(Hash))
        @compileError("Data bit size must be <= Hash bit size");

    return struct {
        const PRIME: Hash = fibonacciPrime(@bitSizeOf(Hash));
        const INITIAL: Hash = PRIME ^ (seed | 1);

        pub inline fn hash(slice: []const Data) Hash {
            var acc: Hash = INITIAL;
            for (slice) |item| {
                acc = (acc ^ @as(Hash, item)) *% PRIME;
            }
            return acc;
        }
    };
}

test SliceHasher {
    const ByteHasher = SliceHasher(u8, u64, 0);
    const h1 = ByteHasher.hash("hello world");
    try std.testing.expect(h1 != 0);
}

pub fn ValueHasher(comptime Data: type, comptime Hash: type, comptime seed: Data) type {
    const data_info = @typeInfo(Data);
    const hash_info = @typeInfo(Hash);

    if (data_info != .int or data_info.int.signedness != .unsigned)
        @compileError("ValueHasher requires an unsigned integer Data type, got: " ++ @typeName(Data));
    if (hash_info != .int or hash_info.int.signedness != .unsigned)
        @compileError("ValueHasher requires an unsigned integer Hash type, got: " ++ @typeName(Hash));
    if (@bitSizeOf(Data) < @bitSizeOf(Hash))
        @compileError("Data bit size must be >= Hash bit size");

    return struct {
        const PRIME: Data = fibonacciPrime(@bitSizeOf(Data)) ^ (seed | 1);
        const SHIFT = @bitSizeOf(Data) - @bitSizeOf(Hash);

        pub inline fn hash(value: Data) Hash {
            return @truncate((value *% PRIME) >> SHIFT);
        }
    };
}

test ValueHasher {
    const Hasher = ValueHasher(u64, u16, 0);

    const h1 = Hasher.hash(1);
    const h2 = Hasher.hash(2);
    try std.testing.expect(h1 != h2);
}

pub fn AngularSimilarity(comptime Signature: type, comptime Float: type) type {
    const sig_info = @typeInfo(Signature);
    if (sig_info != .int or sig_info.int.signedness != .unsigned)
        @compileError("AngularSimilarity requires an unsigned integer Signature type, got: " ++ @typeName(Signature));

    const float_info = @typeInfo(Float);
    if (float_info != .float)
        @compileError("AngularSimilarity requires a float Float type, got: " ++ @typeName(Float));

    const FACTOR: Float = std.math.pi / @as(Float, @floatFromInt(@bitSizeOf(Signature)));

    return struct {
        pub inline fn calculate(a: Signature, b: Signature) Float {
            const dist: Float = @floatFromInt(@popCount(a ^ b));
            return @cos(dist * FACTOR);
        }
    };
}

test AngularSimilarity {
    const Sim = AngularSimilarity(u64, f32);

    const a: u64 = 0b1010;
    const b: u64 = 0b1010;
    const c: u64 = ~a;

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Sim.calculate(a, b), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), Sim.calculate(a, c), 1e-6);
}

pub fn CorpusStats(comptime Key: type, comptime Count: type, comptime Weight: type, comptime size: usize) type {
    const weight_info = @typeInfo(Weight);
    if (weight_info != .float)
        @compileError("CorpusStats requires a float Weight type, got: " ++ @typeName(Weight));

    const Table = ArrayLookupTable(Key, Count, size);

    return struct {
        const Self = @This();

        counts: Table,
        total: usize = 0,

        pub fn init(allocator: std.mem.Allocator) !Self {
            var counts = try Table.init(allocator);
            errdefer counts.deinit(allocator);

            counts.fill(0);
            return .{
                .counts = counts,
                .total = 0,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.counts.deinit(allocator);
            self.* = undefined;
        }

        pub inline fn add(self: *Self, token: Key) void {
            self.counts.set(token, self.counts.get(token) + 1);
            self.total += 1;
        }

        pub inline fn weight(self: *const Self, token: Key) Weight {
            if (self.total == 0) return 0.0;
            const count = self.counts.get(token);
            if (count == 0) return 0.0;
            const p: Weight = @as(Weight, @floatFromInt(count)) / @as(Weight, @floatFromInt(self.total));
            return -@log2(p);
        }
    };
}

test CorpusStats {
    var stats = try CorpusStats(u16, u32, f32, 256).init(std.testing.allocator);
    defer stats.deinit(std.testing.allocator);

    stats.add(1);
    stats.add(1);
    stats.add(2);
    stats.add(3);

    try std.testing.expectEqual(@as(f32, 0.0), stats.weight(99));
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), stats.weight(1), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), stats.weight(2), 1e-6);
}

pub fn SimHasher(
    comptime Token: type,
    comptime Signature: type,
    comptime Float: type,
    comptime Count: type,
    comptime stats_size: usize,
    comptime seed: Token,
) type {
    const sig_info = @typeInfo(Signature);
    if (sig_info != .int or sig_info.int.signedness != .unsigned)
        @compileError("SimHasher requires an unsigned integer Signature type, got: " ++ @typeName(Signature));

    const float_info = @typeInfo(Float);
    if (float_info != .float)
        @compileError("SimHasher requires a float Float type, got: " ++ @typeName(Float));

    return struct {
        const Self = @This();
        pub const Stats = CorpusStats(Token, Count, Float, stats_size);
        pub const Hasher = ValueHasher(Token, Signature, seed);

        pub const BITS: u16 = @bitSizeOf(Signature);

        acc: [BITS]Float = [_]Float{0.0} ** BITS,

        pub fn init() Self {
            return .{};
        }

        pub inline fn add(self: *Self, token: Token, stats: *const Stats) void {
            const w: Float = stats.weight(token);
            if (w == 0.0) return;

            const h: Signature = Hasher.hash(token);
            inline for (0..BITS) |i| {
                const bit_set = (h & (@as(Signature, 1) << i)) != 0;
                self.acc[i] += if (bit_set) w else -w;
            }
        }

        pub fn finish(self: *const Self) Signature {
            const m = median(&self.acc);
            var sig: Signature = 0;
            inline for (0..BITS) |i| {
                const bit = @as(Signature, @intFromBool(self.acc[i] > m));
                sig |= bit << i;
            }
            return sig;
        }

        pub fn median(values: *const [BITS]Float) Float {
            var sorted = values.*;
            std.mem.sort(Float, &sorted, {}, std.sort.asc(Float));
            return sorted[BITS / 2];
        }
    };
}

test SimHasher {
    const Sim = SimHasher(u64, u64, f32, u32, 256, 0);

    var stats = try Sim.Stats.init(std.testing.allocator);
    defer stats.deinit(std.testing.allocator);

    const doc1 = [_]u64{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const doc2 = [_]u64{ 1, 2, 3, 4, 5, 6, 7, 9 };

    for (doc1) |t| stats.add(t);
    for (doc2) |t| stats.add(t);

    var h1 = Sim.init();
    for (doc1) |t| h1.add(t, &stats);
    const sig1 = h1.finish();

    var h2 = Sim.init();
    for (doc2) |t| h2.add(t, &stats);
    const sig2 = h2.finish();

    try std.testing.expect(sig1 != 0);
    try std.testing.expect(sig2 != 0);

    const sim = AngularSimilarity(u64, f32).calculate(sig1, sig2);
    try std.testing.expect(sim > 0.8);
}
pub fn Signer(
    comptime size: usize,
    comptime Token: type,
    comptime Signature: type,
    comptime Float: type,
    comptime Count: type,
    comptime stats_size: usize,
    comptime seed: Token,
) type {
    return struct {
        const Self = @This();

        pub const Window = SlidingWindowIterator(size);
        pub const TokenHasher = SliceHasher(u8, Token, seed);
        pub const Sim = SimHasher(Token, Signature, Float, Count, stats_size, seed);
        pub const Stats = Sim.Stats;

        pub const Trainer = struct {
            stats: *Stats,

            pub inline fn add(self: Trainer, window: []const u8) void {
                self.stats.add(TokenHasher.hash(window));
            }
        };

        sim: Sim = Sim.init(),
        stats: *const Stats,

        pub fn init(stats: *const Stats) Self {
            return .{
                .sim = Sim.init(),
                .stats = stats,
            };
        }

        pub inline fn trainer(stats: *Stats) Trainer {
            return .{ .stats = stats };
        }

        pub inline fn reset(self: *Self) void {
            self.sim = Sim.init();
        }

        pub inline fn add(self: *Self, window: []const u8) void {
            self.sim.add(TokenHasher.hash(window), self.stats);
        }

        pub inline fn finish(self: *const Self) Signature {
            return self.sim.finish();
        }
    };
}

pub fn SignatureIndex(comptime Signature: type, comptime Float: type) type {
    return struct {
        const Self = @This();
        pub const Similarity = AngularSimilarity(Signature, Float);

        pub const Scanner = struct {
            signatures: []const Signature,
            query: Signature,
            cursor: usize = 0,

            pub inline fn next(self: *Scanner) ?Float {
                if (self.cursor >= self.signatures.len) return null;
                const similarity = Similarity.calculate(self.query, self.signatures[self.cursor]);
                self.cursor += 1;
                return similarity;
            }

            pub inline fn reset(self: *Scanner, query: Signature) void {
                self.query = query;
                self.cursor = 0;
            }
        };

        signatures: std.ArrayListUnmanaged(Signature) = .empty,

        pub fn init() Self {
            return .{};
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.signatures.deinit(allocator);
            self.* = undefined;
        }

        pub fn add(self: *Self, allocator: std.mem.Allocator, sig: Signature) !usize {
            const id = self.signatures.items.len;
            try self.signatures.append(allocator, sig);
            return id;
        }

        pub inline fn get(self: *const Self, id: usize) Signature {
            return self.signatures.items[id];
        }

        pub inline fn count(self: *const Self) usize {
            return self.signatures.items.len;
        }

        pub inline fn score(self: *const Self, id: usize, query: Signature) Float {
            return Similarity.calculate(query, self.signatures.items[id]);
        }

        pub inline fn scan(self: *const Self, query: Signature) Scanner {
            return .{
                .signatures = self.signatures.items,
                .query = query,
                .cursor = 0,
            };
        }
    };
}

test Signer {
    const DocSigner = Signer(3, u64, u64, f32, u32, 256, 0);

    var stats = try DocSigner.Stats.init(std.testing.allocator);
    defer stats.deinit(std.testing.allocator);

    const text1 = "the quick brown fox jumps over the lazy dog";
    const text2 = "the quick brown fox jumps over the fast dog";

    const trainer = DocSigner.trainer(&stats);
    var w1 = DocSigner.Window.init(text1);
    while (w1.next()) |w| trainer.add(w);

    var w2 = DocSigner.Window.init(text2);
    while (w2.next()) |w| trainer.add(w);

    var s1 = DocSigner.init(&stats);
    w1 = DocSigner.Window.init(text1);
    while (w1.next()) |w| s1.add(w);
    const sig1 = s1.finish();

    var s2 = DocSigner.init(&stats);
    w2 = DocSigner.Window.init(text2);
    while (w2.next()) |w| s2.add(w);
    const sig2 = s2.finish();

    try std.testing.expect(sig1 != 0);
    try std.testing.expect(sig2 != 0);

    const sim = AngularSimilarity(u64, f32).calculate(sig1, sig2);
    try std.testing.expect(sim > 0.8);
}

const ModelPipeline = Signer(3, u64, u64, f32, u32, std.math.maxInt(u16), 0);
const SimilarityCalc = AngularSimilarity(u64, f32);
const c_alloc = std.heap.c_allocator;

pub const Model = struct {
    stats: ModelPipeline.Stats,

    pub fn init(allocator: std.mem.Allocator) !*Model {
        const self = try allocator.create(Model);
        errdefer allocator.destroy(self);

        self.stats = try ModelPipeline.Stats.init(allocator);
        return self;
    }

    pub fn deinit(self: *Model, allocator: std.mem.Allocator) void {
        self.stats.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn train(self: *Model, text: []const u8) void {
        const trainer = ModelPipeline.trainer(&self.stats);
        var w = ModelPipeline.Window.init(text);
        while (w.next()) |token| trainer.add(token);
    }

    pub fn sign(self: *const Model, text: []const u8) u64 {
        var signer = ModelPipeline.init(&self.stats);
        var w = ModelPipeline.Window.init(text);
        while (w.next()) |token| signer.add(token);
        return signer.finish();
    }
};

pub export fn frag_model_create() ?*Model {
    return Model.init(c_alloc) catch null;
}

pub export fn frag_model_destroy(model: ?*Model) void {
    if (model) |m| m.deinit(c_alloc);
}

pub export fn frag_train(model: *Model, text: [*]const u8, len: usize) void {
    model.train(text[0..len]);
}

pub export fn frag_sign(model: *const Model, text: [*]const u8, len: usize) u64 {
    return model.sign(text[0..len]);
}

pub export fn frag_distance(a: u64, b: u64) u32 {
    return @popCount(a ^ b);
}

pub export fn frag_similarity(a: u64, b: u64) f32 {
    return SimilarityCalc.calculate(a, b);
}
