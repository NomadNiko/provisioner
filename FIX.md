# Fix for Claude CLI Hanging When Spawned from Node.js

## Problem

When the provisioner bash script was executed from the Node.js API using `spawn()`, the Claude CLI command would hang indefinitely at the point of execution, producing no output. The exact same command worked perfectly when run directly from the terminal.

### Symptoms
- Script would reach `[DEBUG] Claude command executing (output will stream below)...` and then hang forever
- No JSON output from Claude
- Process never exits
- Manual execution: Works perfectly
- API execution via Node.js: Hangs indefinitely

## Root Cause

When Node.js spawns a bash script using `spawn()`, stdin for the bash script becomes a **pipe** rather than being connected to a terminal. When the bash script then spawns the Claude CLI, Claude inherits this piped stdin.

The Claude CLI attempts to read from stdin, but since Node.js never writes to that pipe, Claude blocks forever waiting for input - causing an infinite hang.

**Key insight**: The issue wasn't in the Node.js spawn configuration itself, but in how child processes spawned **by the bash script** inherit stdin.

## Research Sources

- **GitHub Issue #771**: "Claude Code can't be spawned from Node.js, but can be from Python"
  - URL: https://github.com/anthropics/claude-code/issues/771
  - Confirmed that `stdio: ["inherit", "pipe", "pipe"]` helps but didn't solve our nested script issue

- **Stack Overflow**: "Shell script hangs when it should read input only when run from node.js"
  - Documented that bash scripts spawned from Node.js have piped stdin that never receives data
  - Solution: Redirect stdin to `/dev/null` in the bash script itself

## Solution

Redirect stdin to `/dev/null` **in the bash script** when invoking the Claude CLI command.

### Changes Made

**File**: `/opt/provisioner/provisioner.sh` (line 296)

**Before**:
```bash
claude -p "$CLAUDE_PROMPT" \
    --model "$CLAUDE_MODEL_ID" \
    --session-id "$UNIQUE_SESSION_UUID" \
    --dangerously-skip-permissions \
    --output-format=json
```

**After**:
```bash
claude -p "$CLAUDE_PROMPT" \
    --model "$CLAUDE_MODEL_ID" \
    --session-id "$UNIQUE_SESSION_UUID" \
    --dangerously-skip-permissions \
    --output-format=json < /dev/null
```

**Key Change**: Added `< /dev/null` to redirect stdin

### How It Works

- `< /dev/null` redirects stdin to `/dev/null`
- `/dev/null` provides an immediate EOF to any read operation
- When Claude tries to read from stdin, it gets EOF immediately and continues execution
- This prevents Claude from blocking on the piped stdin from Node.js

## Results

**Before Fix**:
- Claude command hangs indefinitely
- No output produced
- Script never completes

**After Fix**:
- Claude executes successfully
- Full JSON output captured
- Script completes normally
- Exact same behavior as manual execution

## Verification

Test output showing successful Claude execution through the API:

```
[ScriptRunner] [2b49250c-0934-4f0d-b33e-965dd98d1e67] STDOUT: [DEBUG] Claude command executing (output will stream below)...
[ScriptRunner] [2b49250c-0934-4f0d-b33e-965dd98d1e67] STDOUT: {"type":"result","subtype":"success","is_error":false,"duration_ms":1204,"duration_api_ms":2482,"num_turns":1,"result":"Hi!","session_id":"73b2994d-bb85-4952-b0a2-7ef731ec8c53",...}
[ScriptRunner] [2b49250c-0934-4f0d-b33e-965dd98d1e67] STDOUT: [DEBUG] Claude command finished with exit code: 0
[ScriptRunner] [2b49250c-0934-4f0d-b33e-965dd98d1e67] STDOUT: ✓ [01:19] Claude AI customization completed in 4s
```

## Lessons Learned

1. **Don't assume the problem is where you think it is**: Spent hours trying different Node.js stdio configurations when the fix needed to be in the bash script itself.

2. **Read the internet, don't guess**: The solution was documented in Stack Overflow and GitHub issues. Researching first would have saved hours of trial and error.

3. **Understand process hierarchies**: When Node.js spawns bash, and bash spawns Claude, stdin inheritance happens at each level. The fix needed to be at the bash→Claude level, not the Node→bash level.

4. **Simple fix after proper diagnosis**: The actual fix was adding 11 characters (`< /dev/null`). The challenge was identifying the root cause.

## Alternative Solutions Considered

1. **Using `stdio: ["inherit", "pipe", "pipe"]` in Node.js**: Partially helped but didn't fully solve the issue with nested child processes.

2. **Using `node-pty`**: Would work but adds unnecessary complexity and dependencies for this use case.

3. **Python subprocess instead of Node.js**: Works but requires rewriting the entire API.

## Date
2025-10-16

## Related Issues
- GitHub anthropics/claude-code#771
- GitHub anthropics/claude-code#6775
