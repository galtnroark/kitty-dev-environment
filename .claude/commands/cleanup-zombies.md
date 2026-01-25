# /cleanup-zombies - Identify and Kill Zombie Claude Processes

You are helping the user clean up zombie Claude Code processes and orphaned MCP servers that accumulate over time, especially from subagent spawning.

## Step 1: Identify All Claude Processes

Run this command to get a full picture:

```bash
ps aux | grep -E "(claude|notion-mcp|playwright-mcp)" | grep -v grep | awk '{printf "%-8s %-10s %-12s %s\n", $2, $9, $10, substr($0, index($0,$11), 80)}'
```

## Step 2: Categorize Processes

Parse the output and categorize into:

### Today's Processes (KEEP by default)
- Processes showing only a time (e.g., "9:41PM", "5:10AM") started today
- These are likely active sessions

### Old Processes (ZOMBIE candidates)
- Processes showing day names (Sun, Mon, Tue, Wed, Thu, Fri, Sat)
- Processes showing dates (e.g., "15Jan26", "16Jan26")
- These are likely zombies from previous sessions

### MCP Servers
- `notion-mcp-server` or `playwright-mcp-server` processes
- Old ones should be killed with their parent Claude process

## Step 3: Present Findings to User

Format the output clearly:

```
## Zombie Process Report

### Processes from Today (will KEEP):
| PID    | Started  | CPU Time  | Description |
|--------|----------|-----------|-------------|
| 50435  | 9:41PM   | 197:50    | claude --dangerously-skip-permissions |

### Zombie Candidates (recommend KILL):
| PID    | Started  | CPU Time  | Description |
|--------|----------|-----------|-------------|
| 17194  | Fri06PM  | 89:08     | claude ... CLOUD-MQTTCONFIG-260123-001 |
| 66716  | Thu09AM  | 88:31     | claude ... JACK-IMU-260122-001 |

### Orphaned MCP Servers:
| PID    | Started  | Type      |
|--------|----------|-----------|
| 79866  | 15Jan26  | notion-mcp-server |

**Total: X zombies found consuming ~Y MB memory**
```

## Step 4: Ask for Confirmation

Use AskUserQuestion to confirm:

```
Question: "Which processes should I kill?"
Options:
- "Kill all zombies (recommended)" - Kill all processes not from today
- "Kill only oldest (>3 days)" - Conservative cleanup
- "Show me the kill commands" - Let user run manually
- "Cancel" - Don't kill anything
```

## Step 5: Execute Cleanup (if confirmed)

If user confirms, run:

```bash
# Kill old Claude processes
ps aux | grep -E "claude" | grep -v grep | grep -E "(DATE_PATTERN)" | awk '{print $2}' | xargs kill 2>/dev/null

# Kill orphaned MCP servers
ps aux | grep -E "(notion-mcp|playwright-mcp)" | grep -v grep | grep -E "(DATE_PATTERN)" | awk '{print $2}' | xargs kill 2>/dev/null
```

Replace DATE_PATTERN based on user's choice:
- All zombies: `(Jan|Sun|Mon|Tue|Wed|Thu|Fri|Sat)` (adjust for current day)
- Oldest only: `(\\d{2}Jan|\\d{2}Dec)` (date patterns only)

## Step 6: Verify and Report

After killing, run verification:

```bash
ps aux | grep -E "(claude|notion-mcp)" | grep -v grep | wc -l
```

Report:
```
Cleanup complete!
- Killed: X Claude processes
- Killed: Y MCP servers
- Remaining: Z active processes (all from today)
- Estimated memory freed: ~N MB
```

## Important Notes

- NEVER kill the current session (the one running this command)
- The current session's PID can be inferred as the most recent one
- MCP servers are child processes - killing the parent may leave orphans
- If in doubt, show commands and let user run manually

## Quick Reference: Date Patterns in `ps` Output

| Pattern | Meaning |
|---------|---------|
| `9:41PM` | Started today (time only) |
| `Fri06PM` | Started Friday (day + time) |
| `15Jan26` | Started Jan 15, 2026 (full date) |

Processes older than 24 hours show day names. Older than ~7 days show full dates.
