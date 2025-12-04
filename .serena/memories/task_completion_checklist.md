# Task Completion Checklist

## Before Completing Any Task

1. **DO NOT commit automatically** - Wait for user's explicit instruction
2. **DO NOT build Docker image locally** - Push changes, let GitHub Actions build

## When Adding New Tools to Dockerfile

1. Add version ARG at top of Dockerfile
2. Add installation in appropriate layer (TUI tools go last)
3. Update `scripts/check-versions.sh` with version check
4. Update `scripts/test-image.sh` with test case
5. Cleanup must be in same RUN instruction (Docker layers are incremental)

## Test Script Format
```bash
check "<name>" "<version_cmd>" "<usage_cmd>" "<expected>" "<test_desc>"
```
- Version check: 5s timeout
- Usage test: 10s timeout

## Special Tool Testing
- `bd --help` (not `--version` - fails without database)
- `mihomo -v` and `-h` (not `--version` / `--help`)
