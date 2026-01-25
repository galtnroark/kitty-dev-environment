# /agent-status - Check Status of Running Agents

You are helping the user monitor the status of background agents and subagents to determine if they are working or stalled.

## Step 1: Check for Background Tasks

First, check if there are any background tasks registered:

```bash
# Check for Claude task output files
find /tmp -name "claude-*" -type f -mmin -60 2>/dev/null | head -20

# Check for any .claude task tracking
find ~/.claude -name "*task*" -o -name "*output*" 2>/dev/null | head -10
```

## Step 2: Check Running Claude Processes

Get all currently running Claude processes with their activity:

```bash
ps aux | grep -E "claude" | grep -v grep | awk '{
  pid=$2;
  cpu=$3;
  mem=$4;
  start=$9;
  time=$10;
  # Extract description from command
  cmd="";
  for(i=11;i<=NF;i++) cmd=cmd" "$i;
  printf "%-7s %-6s %-6s %-10s %-12s %s\n", pid, cpu"%", mem"%", start, time, substr(cmd,1,60)
}'
```

## Step 3: Analyze Activity Levels

For each process, determine if it appears active or stalled:

| CPU % | Status | Interpretation |
|-------|--------|----------------|
| > 5%  | ACTIVE | Actively processing |
| 1-5%  | IDLE   | Waiting (may be on I/O or thinking) |
| < 1%  | STALLED? | Possibly stuck - needs investigation |

## Step 4: Check Recent File Activity

See if agents are actively reading/writing files:

```bash
# Check recent file modifications in working directories
find . -type f -mmin -5 -name "*.py" -o -name "*.md" -o -name "*.ts" 2>/dev/null | head -10
```

## Step 5: Present Status Report

Format output as a clear status dashboard:

```
## Agent Status Dashboard
Generated: {timestamp}

### Running Agents ({count} total)

| PID   | CPU  | Started | Runtime  | Status  | Task |
|-------|------|---------|----------|---------|------|
| 50435 | 12%  | 9:41PM  | 0:45:23  | ACTIVE  | Current session (this one) |
| 56171 | 0.1% | 5:10AM  | 3:22:00  | STALLED | implement JACK-IMU-260122 |
| 82229 | 3%   | 5:59AM  | 2:45:00  | IDLE    | prd-design agent |

### Status Legend
- ACTIVE (>5% CPU): Processing, making progress
- IDLE (1-5% CPU): Waiting on I/O, thinking, or between tasks
- STALLED (<1% CPU for >10 min): Likely stuck, may need intervention

### Recommendations
{Based on findings, suggest actions like:}
- "PID 56171 appears stalled (0.1% CPU for 3+ hours). Consider checking with Ctrl-C or killing."
- "All agents appear healthy."
```

## Step 6: Offer Actions

Use AskUserQuestion if issues are found:

```
Question: "Agent PID 56171 appears stalled. What would you like to do?"
Options:
- "Check its output" - Try to read last output from the agent
- "Kill it" - Terminate the stalled process
- "Leave it" - It might be doing slow I/O work
- "Kill all stalled agents" - Clean up all agents with <1% CPU
```

## Step 7: Deep Dive (if requested)

If user wants more detail on a specific agent, try to find its output:

```bash
# Check if agent has log output
lsof -p {PID} 2>/dev/null | grep -E "(txt|REG)" | head -10

# Check Greengrass logs if it's a GG-related agent
ls -la /greengrass/v2/logs/*.log 2>/dev/null | head -5
```

## Quick Commands for User

Provide these for manual checking:

```bash
# Quick status check
ps aux | grep claude | grep -v grep | awk '{print $2, $3"%", $9, $10}'

# Watch CPU in real-time (run in separate terminal)
watch -n 2 'ps aux | grep claude | grep -v grep | awk "{print \$2, \$3\"%\", \$10}"'

# Kill a specific stalled agent
kill {PID}
```

## Notes

- The "current session" is the one with the most recent start time or highest CPU
- MCP servers (notion-mcp, playwright-mcp) are child processes - low CPU is normal for them
- Agents doing file reads or Notion API calls may show low CPU but still be working
- If an agent shows 0% CPU for extended periods AND high runtime, it's likely stuck
