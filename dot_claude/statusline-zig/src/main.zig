// statusline — Claude Code status line, Zig port of statusline.sh
//
// Reads the Claude Code JSON payload from stdin, then prints 1-2 lines:
//   Line 1: model • project dir • git branch/status • context bar • path
//   Line 2: (optional) Teams-plan 5-hour / 7-day usage bars
//
// Modules (in order of the original bash implementation):
//   colors     — ANSI escape constants + colored() + build_bar()
//   json_input — parse stdin JSON into InputData
//   git        — run git sub-processes, return GitSegment
//   context    — build context-window progress bar string
//   usage_api  — load/cache Anthropic usage JSON, build line 2

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;
const process = std.process;
const json = std.json;

// ============================================================
// ANSI color helpers  (mirrors colors.sh)
// ============================================================

const RESET = "\x1b[0m";

// Semantic palette — RGB true-color sequences
const C_CLAUDE_MODEL = "\x1b[38;2;204;120;92m"; // warm terracotta  — model name
const C_PROJECT      = "\x1b[38;2;167;139;250m"; // lavender         — project dir basename
const C_BRANCH       = "\x1b[38;2;246;201;14m";  // vivid yellow     — git branch
const C_MODIFIED     = "\x1b[38;2;249;115;22m";  // orange           — modified files
const C_UNTRACKED    = "\x1b[38;2;239;68;68m";   // red              — untracked files
const C_CTX_LOW      = "\x1b[38;2;34;197;94m";   // green            — context <50% used
const C_CTX_MED      = "\x1b[38;2;234;179;8m";   // amber            — context 50-79% used
const C_CTX_HIGH     = "\x1b[38;2;239;68;68m";   // red              — context >=80% used
const C_CTX_EMPTY    = "\x1b[38;2;30;41;59m";    // dark slate       — empty bar blocks
const C_TIME         = "\x1b[38;2;56;189;248m";  // sky blue         — reset times / icons
const C_GHOST        = "\x1b[38;2;148;163;184m"; // muted slate      — token labels
const C_PATH         = "\x1b[38;2;71;85;105m";   // dim slate        — current directory

// ---------------------------------------------------------------------------
// Nerd Font / emoji codepoints — kept as named constants so the intent is clear.
//
// These are the exact same glyphs used in the bash scripts.  The bash source
// files embed them as raw UTF-8 bytes; here we use literal UTF-8 characters
// for easy visual identification (requires a Nerd Font in your editor).
//
// Line 1 format (statusline.sh):
//   "LEADING [model] • FOLDER project • BRANCH git • FLAME bar usage • PATH dir"
//
// Line 2 format (usage_api.sh):
//   "CLOCK_5H 5h: bar pct • RESET time DIVIDER CALENDAR 7d: bar pct • RESET time"
// ---------------------------------------------------------------------------
const ICON_LEADING  = "";  // U+EE9C  — line 1 leading icon
const ICON_FOLDER   = "";  // U+F07B  — before project dir basename
const ICON_BRANCH   = "";  // U+F418  — before git branch
const ICON_FLAME    = "󰈸"; // U+F0238 — before context bar
const ICON_PATH     = "";  // U+EAF7  — before project path
const ICON_CLOCK_5H = "";  // U+F017  — before 5h label (CTX_LOW coloured)
const ICON_RESET    = "";  // U+F021  — before reset time (TIME coloured)
const ICON_DIVIDER  = "󰇙"; // U+F01D9 — between 5h and 7d blocks
const ICON_CALENDAR = "󰺏"; // U+F0E8F — before 7d label (CTX_LOW coloured)
const ICON_CARD     = "💳"; // U+1F4B3 — extra credits

/// Write `color + text + RESET` to `writer`.
fn colored(writer: anytype, color: []const u8, text: []const u8) !void {
    try writer.writeAll(color);
    try writer.writeAll(text);
    try writer.writeAll(RESET);
}

/// Write a block-character progress bar to `writer`.
/// Thresholds: >=80 → C_CTX_HIGH, >=50 → C_CTX_MED, else C_CTX_LOW.
/// Empty blocks use C_CTX_EMPTY.
fn buildBar(writer: anytype, pct: u32, width: u32) !void {
    const p: u32 = if (pct > 100) 100 else pct;
    const filled: u32 = p * width / 100;
    const empty: u32 = width - filled;

    const bar_color: []const u8 = if (p >= 80) C_CTX_HIGH else if (p >= 50) C_CTX_MED else C_CTX_LOW;

    try writer.writeAll(bar_color);
    for (0..filled) |_| try writer.writeAll("●");
    try writer.writeAll(C_CTX_EMPTY);
    for (0..empty) |_| try writer.writeAll("○");
    try writer.writeAll(RESET);
}

/// Same as buildBar but returns a heap-allocated string.  Caller owns memory.
fn buildBarAlloc(alloc: mem.Allocator, pct: u32, width: u32) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    try buildBar(buf.writer(alloc), pct, width);
    return buf.toOwnedSlice(alloc);
}

// ============================================================
// JSON input parsing  (mirrors the jq call in statusline.sh)
// ============================================================

const InputData = struct {
    model_display: []const u8,
    current_dir: []const u8,
    project_dir: []const u8,
    context_size: u64,
    percent_used: u32,
    current_token_usage: u64,
};

/// Parse the Claude Code JSON payload (read from stdin) into InputData.
/// All string fields are slices into `parsed` arena memory — do not free them
/// separately; call `parsed.deinit()` when done.
fn parseInput(alloc: mem.Allocator, raw: []const u8) !struct {
    data: InputData,
    parsed: json.Parsed(json.Value),
} {
    const parsed = try json.parseFromSlice(json.Value, alloc, raw, .{
        .ignore_unknown_fields = true,
    });

    const root = parsed.value.object;

    // model.display_name
    const model_display: []const u8 = blk: {
        if (root.get("model")) |m| {
            if (m == .object) {
                if (m.object.get("display_name")) |dn| {
                    if (dn == .string) break :blk dn.string;
                }
            }
        }
        break :blk "unknown";
    };

    // workspace.current_dir / workspace.project_dir
    var current_dir: []const u8 = "";
    var project_dir: []const u8 = "";
    if (root.get("workspace")) |ws| {
        if (ws == .object) {
            if (ws.object.get("current_dir")) |cd| {
                if (cd == .string) current_dir = cd.string;
            }
            if (ws.object.get("project_dir")) |pd| {
                if (pd == .string) project_dir = pd.string;
            }
        }
    }
    // Fall back to top-level "cwd" if workspace is absent
    if (current_dir.len == 0) {
        if (root.get("cwd")) |cwd| {
            if (cwd == .string) current_dir = cwd.string;
        }
    }

    // context_window.*
    var context_size: u64 = 200000;
    var percent_used: u32 = 0;
    var current_token_usage: u64 = 0;

    if (root.get("context_window")) |cw| {
        if (cw == .object) {
            if (cw.object.get("context_window_size")) |sz| {
                context_size = switch (sz) {
                    .integer => |v| @intCast(v),
                    .float   => |v| @intFromFloat(v),
                    else     => 200000,
                };
            }
            if (cw.object.get("used_percentage")) |up| {
                const raw_pct: f64 = switch (up) {
                    .integer => |v| @floatFromInt(v),
                    .float   => |v| v,
                    else     => 0,
                };
                percent_used = @intFromFloat(@floor(raw_pct));
            }
            if (cw.object.get("current_usage")) |cu| {
                if (cu == .object) {
                    current_token_usage =
                        jsonGetU64(cu.object, "input_tokens") +
                        jsonGetU64(cu.object, "cache_creation_input_tokens") +
                        jsonGetU64(cu.object, "cache_read_input_tokens");
                }
            }
        }
    }

    return .{
        .data = InputData{
            .model_display       = model_display,
            .current_dir         = current_dir,
            .project_dir         = project_dir,
            .context_size        = context_size,
            .percent_used        = percent_used,
            .current_token_usage = current_token_usage,
        },
        .parsed = parsed,
    };
}

fn jsonGetU64(obj: json.ObjectMap, key: []const u8) u64 {
    const v = obj.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| if (i < 0) 0 else @intCast(i),
        .float   => |f| if (f < 0) 0 else @intFromFloat(f),
        else     => 0,
    };
}

// ============================================================
// Git segment  (mirrors git.sh)
// ============================================================

const GitInfo = struct {
    branch:    []u8,
    staged:    u32,
    modified:  u32,
    deleted:   u32,
    untracked: u32,
};

/// Run a git command with stdout captured; returns null on non-zero exit or error.
fn gitRun(alloc: mem.Allocator, args: []const []const u8) !?[]u8 {
    var child = process.Child.init(args, alloc);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;
    try child.spawn();
    const out = try child.stdout.?.readToEndAlloc(alloc, 256 * 1024);
    const term = try child.wait();
    switch (term) {
        .Exited => |code| if (code != 0) { alloc.free(out); return null; },
        else    => { alloc.free(out); return null; },
    }
    return out;
}

/// Count non-empty lines (equivalent to `wc -l` on captured output).
fn countLines(s: []const u8) u32 {
    if (s.len == 0) return 0;
    var count: u32 = 0;
    var iter = mem.splitScalar(u8, s, '\n');
    while (iter.next()) |line| {
        if (line.len > 0) count += 1;
    }
    return count;
}

/// Collect git info for the cwd.  Returns null when not in a git repo or on
/// detached HEAD.  Caller owns GitInfo.branch.
fn getGitInfo(alloc: mem.Allocator) !?GitInfo {
    // Is this a git repo?
    const check = try gitRun(alloc, &.{ "git", "-c", "gc.auto=0", "rev-parse", "--git-dir" }) orelse return null;
    alloc.free(check);

    // Current branch
    const branch_raw = try gitRun(alloc, &.{ "git", "-c", "gc.auto=0", "branch", "--show-current" }) orelse return null;
    defer alloc.free(branch_raw);
    const branch = mem.trim(u8, branch_raw, " \t\n\r");
    if (branch.len == 0) return null; // detached HEAD

    // Staged (excluding deletions — counted below)
    const staged_raw = try gitRun(alloc, &.{ "git", "-c", "gc.auto=0", "diff", "--cached", "--name-only", "--diff-filter=d" }) orelse
        return GitInfo{ .branch = try alloc.dupe(u8, branch), .staged = 0, .modified = 0, .deleted = 0, .untracked = 0 };
    defer alloc.free(staged_raw);

    // Modified (unstaged, excluding deletions)
    const modified_raw = try gitRun(alloc, &.{ "git", "-c", "gc.auto=0", "diff", "--name-only", "--diff-filter=d" }) orelse return null;
    defer alloc.free(modified_raw);

    // Deleted staged
    const del_staged_raw = try gitRun(alloc, &.{ "git", "-c", "gc.auto=0", "diff", "--cached", "--name-only", "--diff-filter=D" }) orelse return null;
    defer alloc.free(del_staged_raw);

    // Deleted unstaged
    const del_unstaged_raw = try gitRun(alloc, &.{ "git", "-c", "gc.auto=0", "diff", "--name-only", "--diff-filter=D" }) orelse return null;
    defer alloc.free(del_unstaged_raw);

    // Untracked
    const untracked_raw = try gitRun(alloc, &.{ "git", "-c", "gc.auto=0", "ls-files", "--others", "--exclude-standard" }) orelse return null;
    defer alloc.free(untracked_raw);

    return GitInfo{
        .branch    = try alloc.dupe(u8, branch),
        .staged    = countLines(staged_raw),
        .modified  = countLines(modified_raw),
        .deleted   = countLines(del_staged_raw) + countLines(del_unstaged_raw),
        .untracked = countLines(untracked_raw),
    };
}

/// Build the full ANSI-colored git segment string.  Caller owns the returned slice.
fn buildGitSegment(alloc: mem.Allocator) ![]u8 {
    const info = try getGitInfo(alloc) orelse return try alloc.dupe(u8, "");
    defer alloc.free(info.branch);

    var buf: std.ArrayList(u8) = .empty;
    const w = buf.writer(alloc);

    // Branch name is always shown
    try colored(w, C_BRANCH, info.branch);

    if (info.staged > 0) {
        try w.writeByte(' ');
        const s = try fmt.allocPrint(alloc, "+{d}", .{info.staged});
        defer alloc.free(s);
        try colored(w, C_CTX_LOW, s);
    }
    if (info.modified > 0) {
        try w.writeByte(' ');
        const s = try fmt.allocPrint(alloc, "~{d}", .{info.modified});
        defer alloc.free(s);
        try colored(w, C_MODIFIED, s);
    }
    if (info.deleted > 0) {
        try w.writeByte(' ');
        const s = try fmt.allocPrint(alloc, "-{d}", .{info.deleted});
        defer alloc.free(s);
        try colored(w, C_CTX_HIGH, s);
    }
    if (info.untracked > 0) {
        try w.writeByte(' ');
        const s = try fmt.allocPrint(alloc, "?{d}", .{info.untracked});
        defer alloc.free(s);
        try colored(w, C_UNTRACKED, s);
    }

    return buf.toOwnedSlice(alloc);
}

// ============================================================
// Context segment  (mirrors context.sh)
// ============================================================

/// Format an integer as "Nk" when >= 1000, else plain decimal.
fn fmtK(alloc: mem.Allocator, n: u64) ![]u8 {
    return if (n >= 1000)
        fmt.allocPrint(alloc, "{d}k", .{n / 1000})
    else
        fmt.allocPrint(alloc, "{d}", .{n});
}

const CTX_BAR_WIDTH = 10;

/// Returns heap-allocated strings for the bar ("●●○○ 30%") and the usage label ("(30k/200k)").
fn buildContextSegment(
    alloc:          mem.Allocator,
    percent_used:   u32,
    current_tokens: u64,
    context_size:   u64,
) !struct { bar: []u8, usage: []u8 } {
    var bar_buf: std.ArrayList(u8) = .empty;
    try buildBar(bar_buf.writer(alloc), percent_used, CTX_BAR_WIDTH);
    try bar_buf.writer(alloc).print(" {d}%", .{percent_used});
    const bar = try bar_buf.toOwnedSlice(alloc);

    const cur_str = try fmtK(alloc, current_tokens);
    defer alloc.free(cur_str);
    const sz_str = try fmtK(alloc, context_size);
    defer alloc.free(sz_str);
    const usage = try fmt.allocPrint(alloc, "({s}/{s})", .{ cur_str, sz_str });

    return .{ .bar = bar, .usage = usage };
}

// ============================================================
// Usage API  (mirrors usage_api.sh)
// ============================================================

const CACHE_DIR      = "/tmp/claude";
const CACHE_FILE     = CACHE_DIR ++ "/statusline-usage-cache.json";
const DEBUG_FILE     = CACHE_DIR ++ "/statusline-usage-debug.json";
const ERR_FILE       = CACHE_DIR ++ "/statusline-curl-err.txt";
const CACHE_TTL_SECS: i64 = 180;
const USAGE_BAR_WIDTH    = 8;
const API_URL        = "https://api.anthropic.com/api/oauth/usage";
const API_BETA_HEADER = "anthropic-beta: oauth-2025-04-20";
const USER_AGENT     = "claude-code/2.1.34";
const CURL_TIMEOUT   = "8";

const UsageData = struct {
    five_pct:      u32,
    five_reset:    []u8, // ISO string, may be empty; caller must free
    week_pct:      u32,
    week_reset:    []u8, // ISO string, may be empty; caller must free
    extra_enabled: bool,
    extra_pct:     u32,
    extra_used:    u64,
    extra_limit:   u64,
};

/// Read the OAuth access token from ~/.claude/.credentials.json.
fn readAccessToken(alloc: mem.Allocator) !?[]u8 {
    const home = process.getEnvVarOwned(alloc, "HOME") catch return null;
    defer alloc.free(home);

    const creds_path = try fmt.allocPrint(alloc, "{s}/.claude/.credentials.json", .{home});
    defer alloc.free(creds_path);

    const creds_raw = fs.cwd().readFileAlloc(alloc, creds_path, 256 * 1024) catch return null;
    defer alloc.free(creds_raw);

    const parsed = json.parseFromSlice(json.Value, alloc, creds_raw, .{}) catch return null;
    defer parsed.deinit();

    if (parsed.value != .object) return null;
    const oauth = parsed.value.object.get("claudeAiOauth") orelse return null;
    if (oauth != .object) return null;
    const token_v = oauth.object.get("accessToken") orelse return null;
    if (token_v != .string) return null;
    return try alloc.dupe(u8, token_v.string);
}

/// Call the usage API via curl, returning heap-allocated JSON on success.
fn fetchUsageJson(alloc: mem.Allocator) !?[]u8 {
    const token = try readAccessToken(alloc) orelse return null;
    defer alloc.free(token);

    const auth_header = try fmt.allocPrint(alloc, "Authorization: Bearer {s}", .{token});
    defer alloc.free(auth_header);

    var child = process.Child.init(&.{
        "curl", "-s",
        "--max-time",      CURL_TIMEOUT,
        "-H",              "Accept: application/json",
        "-H",              "Content-Type: application/json",
        "-H",              auth_header,
        "-H",              API_BETA_HEADER,
        "-H",              "User-Agent: " ++ USER_AGENT,
        API_URL,
    }, alloc);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;
    try child.spawn();
    const out = try child.stdout.?.readToEndAlloc(alloc, 1024 * 1024);
    _ = try child.wait();

    // Write debug file (best-effort)
    fs.cwd().makePath(CACHE_DIR) catch {};
    if (fs.cwd().createFile(DEBUG_FILE, .{ .truncate = true })) |dbg| {
        dbg.writeAll(out) catch {};
        dbg.close();
    } else |_| {}

    // Validate .five_hour presence
    const parsed = json.parseFromSlice(json.Value, alloc, out, .{}) catch {
        alloc.free(out);
        return null;
    };
    defer parsed.deinit();

    if (parsed.value != .object) { alloc.free(out); return null; }

    if (parsed.value.object.get("five_hour") == null) {
        // Append error message to error log
        if (parsed.value.object.get("error")) |err_v| {
            if (err_v == .object) {
                const etype = if (err_v.object.get("type")) |t| (if (t == .string) t.string else "unknown") else "unknown";
                const emsg  = if (err_v.object.get("message")) |m| (if (m == .string) m.string else "no message") else "no message";
                appendToFile(alloc, ERR_FILE, etype, emsg);
            }
        }
        alloc.free(out);
        return null;
    }

    return out;
}

fn appendToFile(alloc: mem.Allocator, path: []const u8, etype: []const u8, emsg: []const u8) void {
    const f = fs.cwd().openFile(path, .{ .mode = .write_only }) catch
              fs.cwd().createFile(path, .{}) catch return;
    defer f.close();
    f.seekFromEnd(0) catch return;
    const line = fmt.allocPrint(alloc, "[{s}] {s}\n", .{ etype, emsg }) catch return;
    f.writeAll(line) catch {};
}

/// Return the mtime of `path` as Unix seconds, or 0 on error.
fn fileMtime(path: []const u8) i64 {
    const f = fs.cwd().openFile(path, .{}) catch return 0;
    defer f.close();
    const stat = f.stat() catch return 0;
    return @intCast(@divFloor(stat.mtime, std.time.ns_per_s));
}

/// Load usage JSON from the TTL-gated cache, fetching fresh when stale.
fn loadUsageJson(alloc: mem.Allocator) !?[]u8 {
    fs.cwd().makePath(CACHE_DIR) catch {};

    // Remove empty cache file
    if (fs.cwd().openFile(CACHE_FILE, .{})) |f| {
        const st = f.stat() catch { f.close(); unreachable; };
        f.close();
        if (st.size == 0) fs.cwd().deleteFile(CACHE_FILE) catch {};
    } else |_| {}

    // Serve from cache if fresh enough
    const now: i64 = std.time.timestamp();
    if ((now - fileMtime(CACHE_FILE)) < CACHE_TTL_SECS) {
        if (fs.cwd().readFileAlloc(alloc, CACHE_FILE, 1024 * 1024)) |cached| {
            if (cached.len > 0) return cached;
            alloc.free(cached);
        } else |_| {}
    }

    // Fetch fresh copy
    if (try fetchUsageJson(alloc)) |fresh| {
        if (fs.cwd().createFile(CACHE_FILE, .{ .truncate = true })) |wf| {
            wf.writeAll(fresh) catch {};
            wf.close();
        } else |_| {}
        return fresh;
    }

    // Fetch failed — serve stale cache so status line keeps showing last-known data
    return fs.cwd().readFileAlloc(alloc, CACHE_FILE, 1024 * 1024) catch null;
}

fn extractPct(obj: json.ObjectMap, key: []const u8) u32 {
    const v = obj.get(key) orelse return 0;
    const f: f64 = switch (v) {
        .float   => |fv| fv,
        .integer => |iv| @floatFromInt(iv),
        else     => return 0,
    };
    const r = @round(f);
    if (r < 0) return 0;
    if (r > 100) return 100;
    return @intFromFloat(r);
}

fn extractStr(obj: json.ObjectMap, key: []const u8) []const u8 {
    const v = obj.get(key) orelse return "";
    return if (v == .string) v.string else "";
}

fn extractBool(obj: json.ObjectMap, key: []const u8) bool {
    const v = obj.get(key) orelse return false;
    return if (v == .bool) v.bool else false;
}

fn extractU64(obj: json.ObjectMap, key: []const u8) u64 {
    const v = obj.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| if (i < 0) 0 else @intCast(i),
        .float   => |f| if (f < 0) 0 else @intFromFloat(f),
        else     => 0,
    };
}

/// Parse usage JSON into UsageData.  Returns null when .five_hour absent.
/// Caller must free five_reset and week_reset strings on the returned struct.
fn parseUsageJson(alloc: mem.Allocator, raw: []const u8) !?UsageData {
    const parsed = json.parseFromSlice(json.Value, alloc, raw, .{}) catch return null;
    defer parsed.deinit();

    if (parsed.value != .object) return null;
    const root = parsed.value.object;

    const five_v = root.get("five_hour") orelse return null;
    if (five_v != .object) return null;

    const seven_v = root.get("seven_day") orelse return null;
    if (seven_v != .object) return null;

    var extra_enabled = false;
    var extra_pct: u32 = 0;
    var extra_used: u64 = 0;
    var extra_limit: u64 = 0;
    if (root.get("extra_usage")) |xv| {
        if (xv == .object) {
            extra_enabled = extractBool(xv.object, "is_enabled");
            extra_pct     = extractPct(xv.object,  "utilization");
            extra_used    = extractU64(xv.object,  "used_credits");
            extra_limit   = extractU64(xv.object,  "monthly_limit");
        }
    }

    return UsageData{
        .five_pct      = extractPct(five_v.object,  "utilization"),
        .five_reset    = try alloc.dupe(u8, extractStr(five_v.object,  "resets_at")),
        .week_pct      = extractPct(seven_v.object, "utilization"),
        .week_reset    = try alloc.dupe(u8, extractStr(seven_v.object, "resets_at")),
        .extra_enabled = extra_enabled,
        .extra_pct     = extra_pct,
        .extra_used    = extra_used,
        .extra_limit   = extra_limit,
    };
}

// ============================================================
// Time formatting  (mirrors _format_reset_time in usage_api.sh)
// ============================================================

/// Convert an ISO 8601 timestamp to a compact local-time string via `date`.
///   style "time"     → "3:45pm"
///   style "datetime" → "Mar 5, 3:45pm"
/// Returns heap-allocated string, or null on any failure.
fn formatResetTime(alloc: mem.Allocator, iso_str: []const u8, style: []const u8) !?[]u8 {
    if (iso_str.len == 0 or mem.eql(u8, iso_str, "null")) return null;

    // Strip sub-second precision
    var s = iso_str;
    if (mem.indexOfScalar(u8, s, '.')) |dot| s = s[0..dot];

    // Append Z when no explicit TZ offset present (skip the date part: "YYYY-MM-DDT")
    const tail = if (s.len > 10) s[10..] else "";
    const has_tz = mem.indexOfAny(u8, tail, "+-Z") != null;
    const iso_with_tz = if (has_tz)
        try alloc.dupe(u8, s)
    else
        try fmt.allocPrint(alloc, "{s}Z", .{s});
    defer alloc.free(iso_with_tz);

    // date -d "$iso" +%s
    var ep_child = process.Child.init(&.{ "date", "-d", iso_with_tz, "+%s" }, alloc);
    ep_child.stdout_behavior = .Pipe;
    ep_child.stderr_behavior = .Ignore;
    try ep_child.spawn();
    const ep_out = try ep_child.stdout.?.readToEndAlloc(alloc, 64);
    defer alloc.free(ep_out);
    const ep_term = try ep_child.wait();
    switch (ep_term) {
        .Exited => |c| if (c != 0) return null,
        else    => return null,
    }

    const epoch_str = mem.trim(u8, ep_out, " \t\n\r");
    const at_arg = try fmt.allocPrint(alloc, "@{s}", .{epoch_str});
    defer alloc.free(at_arg);

    // Build env with LC_TIME=C
    var env = try process.getEnvMap(alloc);
    defer env.deinit();
    try env.put("LC_TIME", "C");

    const date_fmt: []const u8 = if (mem.eql(u8, style, "time")) "+%l:%M%P" else "+%b %-d, %l:%M%P";
    var fmt_child = process.Child.init(&.{ "date", "-d", at_arg, date_fmt }, alloc);
    fmt_child.env_map = &env;
    fmt_child.stdout_behavior = .Pipe;
    fmt_child.stderr_behavior = .Ignore;
    try fmt_child.spawn();
    const fmt_out = try fmt_child.stdout.?.readToEndAlloc(alloc, 64);
    defer alloc.free(fmt_out);
    _ = try fmt_child.wait();

    // Trim whitespace, collapse multiple spaces, strip leading space
    const trimmed = mem.trim(u8, fmt_out, " \t\n\r");
    var result: std.ArrayList(u8) = .empty;
    var prev_space = false;
    for (trimmed) |ch| {
        if (ch == ' ') {
            if (!prev_space) try result.append(alloc, ch);
            prev_space = true;
        } else {
            try result.append(alloc, ch);
            prev_space = false;
        }
    }
    var out = try result.toOwnedSlice(alloc);
    if (out.len > 0 and out[0] == ' ') {
        const stripped = try alloc.dupe(u8, out[1..]);
        alloc.free(out);
        out = stripped;
    }
    return out;
}

// ============================================================
// Line 2: Teams usage  (mirrors bottom half of usage_api.sh)
// ============================================================

fn printUsageLine(alloc: mem.Allocator) !void {
    const usage_json = try loadUsageJson(alloc) orelse return;
    defer alloc.free(usage_json);

    const usage = try parseUsageJson(alloc, usage_json) orelse return;
    defer alloc.free(usage.five_reset);
    defer alloc.free(usage.week_reset);

    const stdout = std.fs.File{ .handle = std.posix.STDOUT_FILENO };

    const five_bar = try buildBarAlloc(alloc, usage.five_pct, USAGE_BAR_WIDTH);
    defer alloc.free(five_bar);
    const week_bar = try buildBarAlloc(alloc, usage.week_pct, USAGE_BAR_WIDTH);
    defer alloc.free(week_bar);

    const five_reset_fmt = try formatResetTime(alloc, usage.five_reset, "time");
    defer if (five_reset_fmt) |s| alloc.free(s);
    const week_reset_fmt = try formatResetTime(alloc, usage.week_reset, "datetime");
    defer if (week_reset_fmt) |s| alloc.free(s);

    // Five-hour label: "5h: <bar> 42%[ • <icon> 3:45pm]"
    var five_label: std.ArrayList(u8) = .empty;
    defer five_label.deinit(alloc);
    try five_label.writer(alloc).print("5h: {s} {d}%", .{ five_bar, usage.five_pct });
    if (five_reset_fmt) |rt| {
        try five_label.appendSlice(alloc, " • ");
        try colored(five_label.writer(alloc), C_TIME, ICON_RESET);
        try five_label.writer(alloc).print(" {s}", .{rt});
    }

    // Seven-day label
    var week_label: std.ArrayList(u8) = .empty;
    defer week_label.deinit(alloc);
    try week_label.writer(alloc).print("7d: {s} {d}%", .{ week_bar, usage.week_pct });
    if (week_reset_fmt) |rt| {
        try week_label.appendSlice(alloc, " • ");
        try colored(week_label.writer(alloc), C_TIME, ICON_RESET);
        try week_label.writer(alloc).print(" {s}", .{rt});
    }

    // " <five_label> 󰇙 <calendar> <week_label>"
    try colored(stdout, C_CTX_LOW, ICON_CLOCK_5H);
    try stdout.writeAll(&.{' '});
    try stdout.writeAll(five_label.items);
    try stdout.writeAll(&.{' '});
    try stdout.writeAll(ICON_DIVIDER);
    try stdout.writeAll(&.{' '});
    try colored(stdout, C_CTX_LOW, ICON_CALENDAR);
    try stdout.writeAll(&.{' '});
    try stdout.writeAll(week_label.items);

    if (usage.extra_enabled) {
        const extra_bar = try buildBarAlloc(alloc, usage.extra_pct, USAGE_BAR_WIDTH);
        defer alloc.free(extra_bar);
        const extra_detail = try fmt.allocPrint(alloc, "{d}% ({d}/{d})", .{ usage.extra_pct, usage.extra_used, usage.extra_limit });
        defer alloc.free(extra_detail);
        try stdout.writeAll("  ");
        try colored(stdout, C_GHOST, ICON_CARD);
        try stdout.writeAll(" extra: ");
        try stdout.writeAll(extra_bar);
        try stdout.writeAll(&.{' '});
        try colored(stdout, C_GHOST, extra_detail);
    }

    try stdout.writeAll(&.{'\n'});
}

// ============================================================
// Utilities
// ============================================================

/// Return the basename component of a path (after the last '/').
fn basename(path: []const u8) []const u8 {
    if (mem.lastIndexOfScalar(u8, path, '/')) |idx| return path[idx + 1 ..];
    return path;
}

// ============================================================
// Tests
// ============================================================

const testing = std.testing;

test "basename" {
    try testing.expectEqualStrings("project", basename("/home/user/project"));
    try testing.expectEqualStrings("foo", basename("/foo"));
    try testing.expectEqualStrings("nopath", basename("nopath"));
    try testing.expectEqualStrings("", basename("/"));
    try testing.expectEqualStrings("", basename(""));
}

test "countLines" {
    try testing.expectEqual(@as(u32, 0), countLines(""));
    try testing.expectEqual(@as(u32, 1), countLines("one"));
    try testing.expectEqual(@as(u32, 2), countLines("a\nb"));
    try testing.expectEqual(@as(u32, 2), countLines("a\nb\n"));
    try testing.expectEqual(@as(u32, 3), countLines("a\nb\nc\n"));
    // blank lines in the middle don't count (matches wc -l behavior for non-empty)
    try testing.expectEqual(@as(u32, 2), countLines("a\n\nb\n"));
}

test "fmtK" {
    const alloc = testing.allocator;
    {
        const s = try fmtK(alloc, 500);
        defer alloc.free(s);
        try testing.expectEqualStrings("500", s);
    }
    {
        const s = try fmtK(alloc, 999);
        defer alloc.free(s);
        try testing.expectEqualStrings("999", s);
    }
    {
        const s = try fmtK(alloc, 1000);
        defer alloc.free(s);
        try testing.expectEqualStrings("1k", s);
    }
    {
        const s = try fmtK(alloc, 84000);
        defer alloc.free(s);
        try testing.expectEqualStrings("84k", s);
    }
    {
        const s = try fmtK(alloc, 200000);
        defer alloc.free(s);
        try testing.expectEqualStrings("200k", s);
    }
    {
        const s = try fmtK(alloc, 0);
        defer alloc.free(s);
        try testing.expectEqualStrings("0", s);
    }
}

test "colored output" {
    const alloc = testing.allocator;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);

    try colored(buf.writer(alloc), C_CTX_LOW, "hello");
    try testing.expectEqualStrings(C_CTX_LOW ++ "hello" ++ RESET, buf.items);
}

test "buildBar low percentage" {
    const alloc = testing.allocator;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);

    try buildBar(buf.writer(alloc), 30, 10);
    const s = buf.items;

    // Should start with green (CTX_LOW), have 3 filled, switch to CTX_EMPTY, 7 empty, then RESET
    try testing.expect(mem.startsWith(u8, s, C_CTX_LOW));
    try testing.expect(mem.endsWith(u8, s, RESET));

    // Strip ANSI to count dots
    const stripped = try stripAnsi(alloc, s);
    defer alloc.free(stripped);
    try testing.expectEqualStrings("●●●○○○○○○○", stripped);
}

test "buildBar medium percentage" {
    const alloc = testing.allocator;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);

    try buildBar(buf.writer(alloc), 60, 10);
    const s = buf.items;

    // Should use amber (CTX_MED)
    try testing.expect(mem.startsWith(u8, s, C_CTX_MED));

    const stripped = try stripAnsi(alloc, s);
    defer alloc.free(stripped);
    try testing.expectEqualStrings("●●●●●●○○○○", stripped);
}

test "buildBar high percentage" {
    const alloc = testing.allocator;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);

    try buildBar(buf.writer(alloc), 90, 10);
    const s = buf.items;

    // Should use red (CTX_HIGH)
    try testing.expect(mem.startsWith(u8, s, C_CTX_HIGH));

    const stripped = try stripAnsi(alloc, s);
    defer alloc.free(stripped);
    try testing.expectEqualStrings("●●●●●●●●●○", stripped);
}

test "buildBar edge cases" {
    const alloc = testing.allocator;
    {
        // 0%
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(alloc);
        try buildBar(buf.writer(alloc), 0, 8);
        const stripped = try stripAnsi(alloc, buf.items);
        defer alloc.free(stripped);
        try testing.expectEqualStrings("○○○○○○○○", stripped);
    }
    {
        // 100%
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(alloc);
        try buildBar(buf.writer(alloc), 100, 8);
        const stripped = try stripAnsi(alloc, buf.items);
        defer alloc.free(stripped);
        try testing.expectEqualStrings("●●●●●●●●", stripped);
    }
    {
        // >100 clamped
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(alloc);
        try buildBar(buf.writer(alloc), 150, 8);
        const stripped = try stripAnsi(alloc, buf.items);
        defer alloc.free(stripped);
        try testing.expectEqualStrings("●●●●●●●●", stripped);
    }
}

test "parseInput full payload" {
    const alloc = testing.allocator;
    const input =
        \\{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/home/user/project","project_dir":"/home/user/project"},"context_window":{"context_window_size":200000,"used_percentage":42,"current_usage":{"input_tokens":50000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":24000}}}
    ;

    const result = try parseInput(alloc, input);
    defer result.parsed.deinit();
    const d = result.data;

    try testing.expectEqualStrings("Opus 4.6", d.model_display);
    try testing.expectEqualStrings("/home/user/project", d.current_dir);
    try testing.expectEqualStrings("/home/user/project", d.project_dir);
    try testing.expectEqual(@as(u64, 200000), d.context_size);
    try testing.expectEqual(@as(u32, 42), d.percent_used);
    try testing.expectEqual(@as(u64, 84000), d.current_token_usage);
}

test "parseInput defaults on missing fields" {
    const alloc = testing.allocator;
    const input = "{}";

    const result = try parseInput(alloc, input);
    defer result.parsed.deinit();
    const d = result.data;

    try testing.expectEqualStrings("unknown", d.model_display);
    try testing.expectEqualStrings("", d.current_dir);
    try testing.expectEqual(@as(u64, 200000), d.context_size);
    try testing.expectEqual(@as(u32, 0), d.percent_used);
    try testing.expectEqual(@as(u64, 0), d.current_token_usage);
}

test "parseInput cwd fallback" {
    const alloc = testing.allocator;
    const input =
        \\{"cwd":"/tmp/fallback"}
    ;

    const result = try parseInput(alloc, input);
    defer result.parsed.deinit();

    try testing.expectEqualStrings("/tmp/fallback", result.data.current_dir);
}

test "parseInput float percentage floors" {
    const alloc = testing.allocator;
    const input =
        \\{"context_window":{"used_percentage":42.7}}
    ;

    const result = try parseInput(alloc, input);
    defer result.parsed.deinit();

    try testing.expectEqual(@as(u32, 42), result.data.percent_used);
}

test "parseUsageJson full payload" {
    const alloc = testing.allocator;
    const input =
        \\{"five_hour":{"utilization":35.2,"resets_at":"2026-03-06T13:00:00Z"},"seven_day":{"utilization":22,"resets_at":"2026-03-13T08:00:00Z"},"extra_usage":{"is_enabled":true,"utilization":10,"used_credits":50,"monthly_limit":500}}
    ;

    const usage = (try parseUsageJson(alloc, input)).?;
    defer alloc.free(usage.five_reset);
    defer alloc.free(usage.week_reset);

    try testing.expectEqual(@as(u32, 35), usage.five_pct);
    try testing.expectEqualStrings("2026-03-06T13:00:00Z", usage.five_reset);
    try testing.expectEqual(@as(u32, 22), usage.week_pct);
    try testing.expectEqualStrings("2026-03-13T08:00:00Z", usage.week_reset);
    try testing.expect(usage.extra_enabled);
    try testing.expectEqual(@as(u32, 10), usage.extra_pct);
    try testing.expectEqual(@as(u64, 50), usage.extra_used);
    try testing.expectEqual(@as(u64, 500), usage.extra_limit);
}

test "parseUsageJson returns null without five_hour" {
    const alloc = testing.allocator;
    const input =
        \\{"error":{"type":"auth","message":"bad token"}}
    ;

    const result = try parseUsageJson(alloc, input);
    try testing.expect(result == null);
}

test "parseUsageJson no extra_usage" {
    const alloc = testing.allocator;
    const input =
        \\{"five_hour":{"utilization":5},"seven_day":{"utilization":1}}
    ;

    const usage = (try parseUsageJson(alloc, input)).?;
    defer alloc.free(usage.five_reset);
    defer alloc.free(usage.week_reset);

    try testing.expectEqual(@as(u32, 5), usage.five_pct);
    try testing.expect(!usage.extra_enabled);
}

test "buildContextSegment" {
    const alloc = testing.allocator;

    const ctx = try buildContextSegment(alloc, 42, 84000, 200000);
    defer alloc.free(ctx.bar);
    defer alloc.free(ctx.usage);

    try testing.expectEqualStrings("(84k/200k)", ctx.usage);

    // Bar should end with " 42%"
    const bar_stripped = try stripAnsi(alloc, ctx.bar);
    defer alloc.free(bar_stripped);
    try testing.expect(mem.endsWith(u8, bar_stripped, " 42%"));
    // 4 filled + 6 empty for width 10
    try testing.expect(mem.startsWith(u8, bar_stripped, "●●●●○○○○○○"));
}

test "buildContextSegment zero" {
    const alloc = testing.allocator;

    const ctx = try buildContextSegment(alloc, 0, 0, 200000);
    defer alloc.free(ctx.bar);
    defer alloc.free(ctx.usage);

    try testing.expectEqualStrings("(0/200k)", ctx.usage);
}

/// Test helper: strip ANSI escape sequences from a byte slice.
fn stripAnsi(alloc: mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == 0x1b and i + 1 < input.len and input[i + 1] == '[') {
            // Skip ESC [ ... m
            i += 2;
            while (i < input.len and input[i] != 'm') : (i += 1) {}
            if (i < input.len) i += 1; // skip 'm'
        } else {
            try out.append(alloc, input[i]);
            i += 1;
        }
    }
    return out.toOwnedSlice(alloc);
}

// ============================================================
// Entry point
// ============================================================

pub fn main() !void {
    // Arena over page_allocator: fast, zero per-alloc overhead, no need to free
    // individually — the OS reclaims everything when the process exits.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Parse CLI args
    const args = try std.process.argsAlloc(alloc);
    var show_path = false;
    for (args[1..]) |arg| {
        if (mem.eql(u8, arg, "--show-path")) show_path = true;
    }

    // Read JSON from stdin
    const stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };
    const stdin_raw = try stdin_file.readToEndAlloc(alloc, 4 * 1024 * 1024);

    // Parse
    const parsed_result = try parseInput(alloc, stdin_raw);
    const inp = parsed_result.data;

    // Git segment (best-effort — empty when not in a repo or on error)
    const git_segment = buildGitSegment(alloc) catch try alloc.dupe(u8, "");

    // Context bar + usage label
    const ctx = try buildContextSegment(alloc, inp.percent_used, inp.current_token_usage, inp.context_size);

    // -----------------------------------------------------------------------
    // Line 1 — exact match to bash:
    //   printf ' [%s] •  %s •  %s • 󰈸 %s %s •  %s\n'
    //       model_display  current_dir_basename  git_segment
    //       ctx_bar  ctx_usage  project_dir
    // -----------------------------------------------------------------------
    const stdout = std.fs.File{ .handle = std.posix.STDOUT_FILENO };

    try stdout.writeAll(ICON_LEADING);   //
    try stdout.writeAll(" [");
    try colored(stdout, C_CLAUDE_MODEL, inp.model_display);
    try stdout.writeAll("] \u{2022} "); // • (bullet + space)
    try stdout.writeAll(ICON_FOLDER);   //
    try stdout.writeAll(&.{' '});
    try colored(stdout, C_PROJECT, basename(inp.current_dir));
    try stdout.writeAll(" \u{2022} ");  // •
    try stdout.writeAll(ICON_BRANCH);   //
    try stdout.writeAll(&.{' '});
    try stdout.writeAll(git_segment);
    try stdout.writeAll(" \u{2022} ");  // •
    try stdout.writeAll(ICON_FLAME);    // 󰈸
    try stdout.writeAll(&.{' '});
    try stdout.writeAll(ctx.bar);
    try stdout.writeAll(&.{' '});
    try colored(stdout, C_GHOST, ctx.usage);
    if (show_path) {
        try stdout.writeAll(" \u{2022} ");  // •
        try stdout.writeAll(ICON_PATH);     //
        try stdout.writeAll(&.{' '});
        try colored(stdout, C_PATH, inp.project_dir);
    }
    try stdout.writeAll(&.{'\n'});

    // Line 2 — printed only when usage data is available
    printUsageLine(alloc) catch {};
}
