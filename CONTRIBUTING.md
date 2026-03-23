# Contributing

Thanks for your interest in improving claude-code-statusline!

## How to contribute

### Reporting bugs

Open an issue using the **Bug Report** template. Include:
- OS and version (`uname -a`)
- Claude Code plan (Pro / Max / Team)
- The output of the verify command from the README
- What you expected vs what you saw

### Suggesting features

Open an issue using the **Feature Request** template or start a Discussion.

### Submitting a pull request

1. Fork the repo and create a branch from `main`
2. Make your changes to `statusline-command.sh` (the root copy is the source of truth)
3. `skill/assets/statusline-command.sh` is a **symlink** — do not replace it with a regular file
4. Run shellcheck: `shellcheck -s sh statusline-command.sh`
5. Run the test suite: `make test` (or `sh tests/run_tests.sh`)
6. Add tests for new features in `tests/run_tests.sh`
7. Update `CHANGELOG.md` under an `[Unreleased]` section
8. Open a PR — describe what you changed and why

## Project structure

```
statusline-command.sh           # Main script (source of truth)
skill/assets/statusline-command.sh  # Symlink → ../../statusline-command.sh
skill/SKILL.md                  # Skill metadata and /statusline setup guide
tests/run_tests.sh              # Test suite (runs on macOS + Linux)
install.sh                      # One-liner installer
Makefile                        # Build .skill file, run tests
```

## Code style

- **POSIX `sh` only** — no bash-specific syntax (`[[ ]]`, arrays, `$()` in arithmetic, etc.)
- All color variables use `printf '\033[...m'` (single-quoted, not double-quoted `"\033"`)
- Use `printf '%s'` for output to avoid format string injection
- New configurable values should use env vars with `CLAUDE_STATUSLINE_` prefix
- Hardcoded defaults belong at the top of the script with their env var override
- All new features need tests in `tests/run_tests.sh`

## Testing

Tests must pass on **both macOS and Ubuntu** (CI runs on both):

```bash
make test
```

When writing tests:
- Use `strip_ansi` to remove color codes before asserting text content
- Use `grep -qF --` for literal string matching (handles dashes and special chars)
- Use ASCII characters for length assertions (`awk '{print length}'` counts bytes, not Unicode chars)
- Git branch tests must handle CI's detached HEAD state (use `|| true`)
- Set `CLAUDE_STATUSLINE_HIDE_USAGE=1` to avoid API calls in tests

## Platform notes

| Platform | Token source | Key commands |
|---|---|---|
| macOS | `security find-generic-password` | `stat -f`, `date -j` |
| Linux | `secret-tool` or config files | `stat -c`, `date -d` |
| WSL | Windows config files via `wslpath` | Same as Linux + `cmd.exe` |

When adding OS-specific code, always branch on `$os` (from `uname -s`) and ensure graceful fallback.
