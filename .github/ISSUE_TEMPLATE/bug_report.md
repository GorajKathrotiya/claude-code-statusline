---
name: Bug Report
about: Something isn't working
labels: bug
---

**Describe the bug**
A clear description of what's wrong.

**To reproduce**
Steps to reproduce the behaviour.

**Expected behaviour**
What you expected to see.

**Verify command output**
```sh
echo '{"model":{"display_name":"claude-sonnet-4-6"},"cwd":"'$(pwd)'","context_window":{"used_percentage":35,"current_usage":{"input_tokens":7000},"context_window_size":200000}}' \
  | bash ~/.claude/statusline-command.sh
```
Paste the output here.

**Environment**
- OS: <!-- e.g. macOS 15.1, Ubuntu 24.04, WSL2 (Windows 11) -->
- OS version (`uname -a`):
- Claude Code plan: <!-- Pro / Max / Team / API key -->
- `jq --version`:
- Installation method: <!-- one-liner / plugin / skill / manual -->
- Custom env vars (if any): <!-- e.g. CLAUDE_STATUSLINE_HIDE_GIT=1 -->
