# claude-code-statusline

Zero-dependency Claude Code statusline. Pure POSIX sh, cross-platform (macOS/Linux/WSL).

## Architecture

- `statusline-command.sh` — Single script, source of truth. Reads JSON from stdin, outputs colored text.
- `skill/assets/statusline-command.sh` — **Symlink** to root script. Never replace with a regular file.
- `skill/SKILL.md` — Skill metadata. Drives the `/statusline` interactive setup.
- `install.sh` — One-liner installer. Downloads script + updates settings.json.
- `tests/run_tests.sh` — Test suite. Must pass on both macOS and Ubuntu.

## Key rules

- **POSIX sh only** — No bash-isms (`[[ ]]`, arrays, `${var,,}`, etc.). CI runs `shellcheck -s sh`.
- **No external dependencies beyond jq** — `curl` and `git` are optional with graceful fallback.
- **All configurable values** use `CLAUDE_STATUSLINE_*` env vars with defaults at the top of the script.
- **Graceful degradation** — The script must never crash. Missing data = skip that segment.
- **Tests are mandatory** — Every new feature needs test coverage in `tests/run_tests.sh`.
- **Cross-platform** — Branch on `$os` (from `uname -s`). Test on macOS + Linux.

## Common tasks

```bash
shellcheck -s sh statusline-command.sh   # Lint
make test                                 # Run tests
make build                                # Build .skill file
```

## Testing gotchas

- Use `CLAUDE_STATUSLINE_HIDE_USAGE=1` in tests to avoid real API calls
- Git branch tests must handle detached HEAD in CI (`|| true`)
- Use ASCII characters for length assertions (Unicode byte counting varies by platform)
- Use `grep -qF --` for literal string matching (handles dashes)
