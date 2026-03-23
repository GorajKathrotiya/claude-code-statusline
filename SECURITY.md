# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 1.1.x | Yes |
| < 1.1 | No |

## Reporting a vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public issue
2. Email **goraj.kathrotiya@gmail.com** with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
3. You will receive a response within 48 hours

## Scope

This project handles:
- **OAuth tokens** read from the system keychain or credential files (never stored by this script)
- **API calls** to `api.anthropic.com` (read-only usage metadata)
- **Cached API responses** written to `~/.claude/.usage_cache.json`

The script never writes tokens to disk, never sends data to third parties, and never modifies credentials.
