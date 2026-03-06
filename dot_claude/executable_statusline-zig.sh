#!/bin/bash
# statusline-zig.sh — wrapper that invokes the compiled Zig statusline binary.
#
# The binary lives at ~/.claude/statusline-zig/zig-out/bin/statusline
# Build it once with:
#   cd ~/.claude/statusline-zig && zig build -Doptimize=ReleaseSmall
#
# To activate in Claude Code, set in ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "~/.claude/statusline-zig.sh", "padding": 0 }

_BINARY="$HOME/.claude/statusline-zig/zig-out/bin/statusline"

if [ ! -x "$_BINARY" ]; then
	# fallback
    exec "$HOME/.claude/statusline.sh"
fi

exec "$_BINARY"
