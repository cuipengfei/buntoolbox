# Suggested Commands

## Development Commands
```bash
# Testing (DO NOT build locally - too slow, use GitHub Actions)
./scripts/test-image.sh                   # Pull from Docker Hub and test
./scripts/test-image.sh <image>           # Test specific image

# Version Management
./scripts/check-versions.sh               # Check for tool updates
./scripts/check-versions.sh -v            # Verbose mode with download variants

# Local build (AVOID - slow, uses VPN bandwidth)
docker build -t buntoolbox .
```

## Issue Tracking (bd/beads)
```bash
bd ready                    # Show unblocked issues
bd create "title" -t task   # Create issue
bd update <id> --status in_progress
bd close <id>
bd sync                     # Sync with git
```

## Git
```bash
git status
git add <files>
git commit -m "message"
git push
```

## System Utils (Linux)
- `ls`, `cd`, `pwd` - Navigation
- `grep`, `find`, `fd` - Search
- `cat`, `less`, `head`, `tail` - File viewing
