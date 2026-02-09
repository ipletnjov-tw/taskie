# Claude CLI Real-Time Logging

## Overview

The stop hook now captures Claude CLI output in **real-time** to separate log files, allowing you to monitor what Claude is doing during automated reviews.

## Log File Locations

### Hook Logs
**Path**: `.taskie/logs/hook-{timestamp}.log`
- Contains hook execution flow (validation, state updates, decisions)
- One file per hook invocation
- Created on every hook run

### CLI Logs (NEW)
**Path**: `.taskie/logs/cli-{timestamp}-{review-type}-{iteration}.log`
- Contains Claude CLI stdout and stderr in **real-time**
- One file per CLI invocation (review operation)
- **Preserved permanently** (not deleted on success)

**Example**:
```
.taskie/logs/cli-2026-02-09T07-15-30-plan-review-1.log
.taskie/logs/cli-2026-02-09T07-18-45-code-review-2.log
.taskie/logs/cli-2026-02-09T07-25-10-all-code-review-1.log
```

## How It Works

### Implementation
The hook uses `tee` to stream output to both a log file and capture it in a variable:

```bash
CLI_OUTPUT=$(TASKIE_HOOK_SKIP=true timeout 120 claude --print \
    --model "$REVIEW_MODEL" \
    --output-format json \
    --json-schema "$JSON_SCHEMA" \
    --dangerously-skip-permissions \
    "$PROMPT" 2>&1 | tee -a "$CLI_LOG_FILE")
```

**Key components**:
- `2>&1` - Redirects stderr to stdout (captures both streams)
- `tee -a "$CLI_LOG_FILE"` - Appends output to log file **while streaming**
- `$()` - Captures the same output to `CLI_OUTPUT` variable for parsing

### Real-Time Behavior
- ✅ Output appears in log file **as it happens** (not buffered)
- ✅ Hook can parse the captured output for verdict extraction
- ✅ Log files preserved for debugging and auditing
- ✅ No performance impact (streaming is handled by `tee`)

## Monitoring Claude CLI in Real-Time

### While Hook is Running
```bash
# Follow the most recent CLI log
tail -f .taskie/logs/cli-*.log

# Follow a specific review iteration
tail -f .taskie/logs/cli-*-plan-review-1.log
```

### After Hook Completes
```bash
# View all CLI invocations for a plan
ls -lh .taskie/logs/cli-*.log

# Read a specific CLI log
cat .taskie/logs/cli-2026-02-09T07-15-30-plan-review-1.log

# Search for patterns
grep -i "error" .taskie/logs/cli-*.log
```

## Log Contents

### Hook Log
```
[2026-02-09 07:15:30] === Hook invocation ===
[2026-02-09 07:15:30] EVENT JSON: {"cwd": "/path/to/project", ...}
[2026-02-09 07:15:30] Checking jq dependency
[2026-02-09 07:15:30] jq found
...
[2026-02-09 07:15:31] Invoking: TASKIE_HOOK_SKIP=true timeout 120 claude ...
[2026-02-09 07:15:31] CLI output streaming in real-time to: .taskie/logs/cli-...
```

### CLI Log
```
{
  "result": {
    "verdict": "FAIL"
  },
  "session_id": "abc123",
  "cost": {
    "input_tokens": 15420,
    "output_tokens": 2847
  },
  "usage": {
    "requests": 12
  }
}
```

## Benefits

1. **Debugging**: See exactly what Claude is thinking during reviews
2. **Transparency**: Track token usage, session IDs, and costs per review
3. **Auditing**: Permanent record of all automated review operations
4. **Monitoring**: Watch progress of long-running reviews in real-time
5. **Troubleshooting**: Diagnose issues when reviews fail or time out

## Log Retention

- **Hook logs**: Accumulate over time (one per stop attempt)
- **CLI logs**: Accumulate over time (one per review operation)
- **Cleanup**: No automatic deletion (manage manually if disk space is a concern)

Recommended cleanup strategy:
```bash
# Delete logs older than 30 days
find .taskie/logs -name "*.log" -mtime +30 -delete

# Or keep only the last 100 logs
ls -t .taskie/logs/*.log | tail -n +101 | xargs rm -f
```

## Technical Details

### Why `tee` Instead of Redirection?
- **Redirection** (`>`) would buffer output until process completes
- **`tee`** writes to file **immediately** as data arrives
- **Command substitution** still captures full output for parsing

### Exit Code Preservation
The `tee` command passes through the exit code from `claude`:
- Exit 0: Claude completed successfully
- Exit 124: Timeout (120 seconds)
- Exit 2: Claude error

### Performance Impact
- **Negligible**: `tee` adds <1ms overhead
- **No blocking**: Output streaming doesn't slow down Claude
- **Disk I/O**: Sequential writes are very fast on modern systems

## Troubleshooting

### Log File Not Created
**Symptom**: CLI log file doesn't exist after hook runs
**Cause**: `.taskie/logs/` directory doesn't exist
**Fix**: Hook creates it automatically, but verify permissions

### Incomplete Log Contents
**Symptom**: CLI log is truncated or missing final output
**Cause**: Hook killed before `tee` could flush
**Solution**: Check hook log for timeout or errors

### Large Log Files
**Symptom**: CLI logs consuming too much disk space
**Cause**: Large all-code-review operations with many files
**Solution**: Implement log rotation or cleanup strategy (see above)

## Examples

### Successful Review
```bash
$ cat .taskie/logs/cli-2026-02-09T07-15-30-plan-review-1.log
{
  "result": {
    "verdict": "PASS"
  },
  "session_id": "sess_abc123",
  "cost": {
    "input_tokens": 8420,
    "output_tokens": 1247
  }
}
```

### Failed Review
```bash
$ cat .taskie/logs/cli-2026-02-09T07-18-45-code-review-2.log
{
  "result": {
    "verdict": "FAIL"
  },
  "session_id": "sess_def456",
  "cost": {
    "input_tokens": 15420,
    "output_tokens": 3847
  }
}
```

### Timeout
```bash
$ cat .taskie/logs/cli-2026-02-09T07-25-10-all-code-review-1.log
[partial output before timeout]
{
  "result": {
    "verdict": "FAIL"
  },
  "session_id": "sess_ghi789",
  ...
[timeout signal kills process]
```

## See Also

- **Hook Logging**: See `HARDENING_REVIEW.md` for hook-level logging details
- **Stop Hook**: See `taskie/hooks/stop-hook.sh` for implementation
- **Test Suite**: See `tests/hooks/test-stop-hook-logging.sh` for logging tests
