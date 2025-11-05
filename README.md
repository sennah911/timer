# Timer - Command-Line Timer Tool

A Swift-based command-line tool for managing file-based timers stored as Markdown files.

## Features

- **Start/Stop timers**: Track time for different activities
- **Tag support**: Organize timers with multiple tags
- **Markdown storage**: All timers stored as readable `.md` files
- **Manual time adjustment**: Set custom start/stop times
- **Duration tracking**: Automatically calculates elapsed time
- **List view**: See all timers at a glance
- **Split timers**: Stop a running timer and start the next one instantly

## Installation

### Option 1: Build from Package (Recommended)

This creates a compiled binary for better performance:

```bash
swift build -c release
sudo cp .build/release/timer /usr/local/bin/
```

### Option 2: Run as Script

Make the script executable and use it directly:

```bash
chmod +x timer.swift
# Then either move it or create a symlink
sudo mv timer.swift /usr/local/bin/timer
# OR
ln -s $(pwd)/timer.swift /usr/local/bin/timer
```

Note: The script version requires Swift to be installed and available in your PATH.

## Storage Location

Timers are stored as Markdown files in `~/.timer/`

Each timer is saved as `<name>.md` with a readable format.

## Commands

### Start a Timer
```bash
timer start <name>
```
Example:
```bash
timer start work
timer start meeting
```

### Stop a Timer
```bash
timer stop <name>
```
Example:
```bash
timer stop work
```

### Split a Timer
```bash
timer split <name> [new_name]
```
Examples:
```bash
timer split work        # stops 'work', starts 'work-1'
timer split work-1      # stops 'work-1', starts 'work-2'
timer split work work-b # stops 'work', starts 'work-b'
```
If you omit `new_name`, the tool picks the next `<base>-N` name using the numeric suffix from `<name>` (avoids `work-1-1`).

### Add Tags
```bash
timer tag <name> <tag>
```
Example:
```bash
timer tag work client-project
timer tag work billable
```

### Remove Tags
```bash
timer remove-tag <name> <tag>
```
Example:
```bash
timer remove-tag work billable
```

### Set Custom Start Time
```bash
timer set-start <name> <ISO8601-datetime>
```
Example:
```bash
timer set-start work 2025-11-04T09:00:00Z
```

### Set Custom Stop Time
```bash
timer set-stop <name> <ISO8601-datetime>
```
Example:
```bash
timer set-stop work 2025-11-04T17:30:00Z
```

### Show Timer Details
```bash
timer show <name>
```
Example:
```bash
timer show work
```

### List All Timers
```bash
timer list
```

### Help
```bash
timer help
```

## Example Workflow

```bash
# Start a work timer
$ timer start work
✅ Started timer 'work' at 2025-11-04T10:00:00.000Z

# Add some tags
$ timer tag work client-a
✅ Added tag 'client-a' to timer 'work'

$ timer tag work development
✅ Added tag 'development' to timer 'work'

# Check timer status
$ timer show work

📊 Timer: work
━━━━━━━━━━━━━━━━━━━━━━━━━━━
Start:    2025-11-04T10:00:00.000Z
Stop:     Running ⏱️
Tags:     client-a, development
Duration: 1h 23m 45s
━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Stop the timer
$ timer stop work
✅ Stopped timer 'work' - Duration: 2h 15m 30s

# List all timers
$ timer list

📋 Available Timers:
━━━━━━━━━━━━━━━━━━━━━━━━━━━
meeting              ⏹️  Stopped  (45m 12s)
work                 ⏹️  Stopped  (2h 15m 30s)
━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Markdown File Format

Each timer is stored as a readable Markdown file:

```markdown
# Timer: work

**Start:** 2025-11-04T10:00:00.000Z
**Stop:** 2025-11-04T12:15:30.000Z
**Tags:** client-a, development

**Duration:** 2h 15m 30s

---

Use `timer` command to manage this timer.
```

## Requirements

- Swift 5.0 or later
- macOS or Linux with Swift installed

## Date Format

For `set-start` and `set-stop` commands, use ISO 8601 format:
- `2025-11-04T09:00:00Z` (UTC)
- `2025-11-04T09:00:00-05:00` (with timezone offset)

## Tips

- Timer names can be anything without spaces (use hyphens or underscores)
- You can manually edit the `.md` files in `~/.timer/` if needed
- Running timers show their current duration when you view them
- Use tags to categorize and filter timers for reporting

## License

MIT
