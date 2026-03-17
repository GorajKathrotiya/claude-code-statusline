# Contributing

Thanks for your interest in improving claude-code-statusline!

## How to contribute

### Reporting bugs
Open an issue using the **Bug Report** template. Include:
- macOS version (`sw_vers`)
- Claude Code plan (Pro / Max / Team)
- The output of the verify command from the README
- What you expected vs what you saw

### Suggesting features
Open an issue using the **Feature Request** template.

### Submitting a pull request
1. Fork the repo and create a branch from `main`
2. Make your changes to `statusline-command.sh`
3. Sync the change to `skill/assets/statusline-command.sh` (they must stay identical)
4. Run shellcheck locally: `shellcheck statusline-command.sh`
5. Test with the verify command from the README
6. Open a PR — describe what you changed and why

## Important: keeping scripts in sync

`statusline-command.sh` (root) and `skill/assets/statusline-command.sh` must always be identical.
The CI will fail if they differ.

## Code style
- POSIX `sh` only — no bash-specific syntax
- All color variables must use `printf '\033[...m'` (not double-quoted `"\033"`)
- Use `printf '%s'` for final output to avoid format string issues
- Thresholds: `<50` green, `<80` yellow, `≥80` red — consistent across all segments
