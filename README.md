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
- **Interactive TUI Dashboard**: Visual interface for managing timers
- **Custom buttons**: Add configurable buttons in the TUI to run shell commands on timer files
- **Configurable templates**: Pre-fill metadata fields and notes from `~/.timer/config.json`

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

## Configuration

You can optionally create `~/.timer/config.json` to customize defaults:

- `timersDirectory`: Override where timer files are stored.
- `custom_properties`: Array (or newline-delimited string) of front-matter lines added after `tags` for new timers. These lines are preserved on updates.
- `placeholder_notes`: Text appended after the metadata when a timer file is first created. Existing notes are never overwritten.

Example:

```json
{
  "timersDirectory": "/Volumes/work/timers",
  "custom_properties": ["project: Client A", "billable: true"],
  "placeholder_notes": "## Notes\\n- Add details here"
}
```

### Custom Buttons (TUI Dashboard)

You can add custom buttons to the TUI dashboard that execute shell commands. Buttons can appear in different locations based on their placement.

Add a `custom_buttons` array to your config:

```json
{
  "timersDirectory": "~/Documents/timers",
  "custom_buttons": [
    {
      "title": "List All Timers",
      "command": "timer list",
      "placement": "global"
    },
    {
      "title": "Open in VS Code",
      "command": "code \"{{path}}\"",
      "placement": "running"
    },
    {
      "title": "Archive Timer",
      "command": "timer archive \"{{path}}\"",
      "placement": "stopped"
    },
    {
      "title": "Search Timer",
      "command": "grep -i \"{{query}}\" \"{{path}}\"",
      "placement": "running",
      "arguments": [
        {
          "name": "query",
          "label": "Search for:"
        }
      ]
    }
  ]
}
```

**Button Configuration:**
- `title`: The button label shown in the TUI
- `command`: The shell command to execute
  - Use `{{path}}` to reference the timer file path (not available for global buttons)
  - Use `{{argumentName}}` for custom arguments
- `placement`: Where the button appears (optional, defaults to `running`)
  - `global`: Above all timers (no timer context, `{{path}}` not available)
  - `running`: On running timer rows only
  - `stopped`: On stopped timer rows only
- `arguments`: Optional array of input fields to prompt for when the button is clicked
  - `name`: The placeholder name used in the command
  - `label`: The text shown in the input field

**How it works:**
1. Buttons with no arguments execute immediately when clicked
2. Buttons with arguments show inline text fields for input
3. Command output is displayed in an expandable section (paginated for long output)
4. Buttons are filtered by placement: global buttons appear above all timers, running/stopped buttons appear only on matching timer rows

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
# or
timer stop --running
```
Example:
```bash
timer stop work
timer stop --running
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
timer split --running work-next # splits the first running timer into 'work-next'
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
timer tag --running review # adds tag 'review' to the first running timer
```

### Remove Tags
```bash
timer remove-tag <name> <tag>
```
Example:
```bash
timer remove-tag work billable
```

### Archive a Timer
```bash
timer archive <name>
```
Archives a timer by moving it to the `archived/` subdirectory with a UUID suffix. Archived timers are not shown in the list or dashboard.

Example:
```bash
timer archive old-project
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
- Configure default metadata and notes via `~/.timer/config.json` for consistent new files
- Add free-form notes after the final `---` in each file; the CLI preserves anything you write there
- Use `-r/--running` with stop, split, or tag to target the first running timer automatically
- Use `-p/--timer-path` to specify timers by file path instead of name (e.g., `timer stop -p ~/Documents/timers/work.md`)

## License

MIT
