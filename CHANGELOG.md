# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-03-23

### Added
- Per-model usage split: shows Opus and Sonnet 7-day usage individually (`[Opus:30% Sonnet:55%]`)
- Cost tracking: shows extra usage spend from the API (`Cost: $18.50/$100`)
  - Green when $0, yellow when any spend, red when >= 75% of monthly limit
  - Shows spend/limit when a monthly limit is set, otherwise just spend

## [1.1.0] - 2026-03-23

### Added
- Cross-platform support: Linux and WSL alongside macOS
- Environment variable configuration (no script editing needed):
  - `CLAUDE_STATUSLINE_CACHE_TTL` — cache duration
  - `CLAUDE_STATUSLINE_BAR_WIDTH` — context bar width
  - `CLAUDE_STATUSLINE_WARN_PCT` / `CLAUDE_STATUSLINE_CRIT_PCT` — color thresholds
  - `CLAUDE_STATUSLINE_STALE_TTL` — stale indicator threshold
  - `CLAUDE_STATUSLINE_HIDE_GIT` / `HIDE_USAGE` / `HIDE_CONTEXT` / `HIDE_MODEL` — segment toggles
- Stale cache indicator (`*`) when cached data is older than 10 minutes
- Plan badge next to model name (Pro, Max, Team, Ent)
- `CLAUDE_PLAN` env var to override plan tier detection
- `CLAUDE_CONTEXT_WINDOW_SIZE` env var to override context window size
- Smart token formatting: 1M instead of 1000k for large context windows
- `jq` dependency check with friendly error message
- `curl` and `git` are now optional (graceful degradation)
- WSL credential reading via Windows-side config files
- Linux credential reading via `secret-tool` (libsecret) or config files
- One-liner install script (`install.sh`)
- Interactive `/statusline` setup with Full/Minimal/Custom presets
- Test suite with 42 tests covering all features and edge cases
- CI runs on both macOS and Ubuntu
- GitHub Release automation with `.skill` artifact

### Changed
- `skill/assets/statusline-command.sh` is now a symlink (no more duplicate maintenance)
- Empty context bar uses `-` characters (was `░`)
- Plan tier detection works independently of usage data
- Output assembly avoids dangling `|` separators when segments are hidden

### Fixed
- Empty input no longer produces partial output
- Context bar respects configurable thresholds instead of hardcoded 50/80

## [1.0.0] - 2026-03-20

### Added
- Initial release
- macOS support with keychain-based OAuth token reading
- Context window usage bar with color coding (green/yellow/red)
- Session % (5-hour block utilization)
- Reset countdown (time until quota reset)
- Weekly % (7-day utilization)
- Git branch display with uncommitted file count
- Model name display
- 3-minute API response caching
- Plugin marketplace support
- Claude Skill packaging (`.skill` file)
