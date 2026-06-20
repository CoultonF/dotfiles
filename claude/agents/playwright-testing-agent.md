---
name: playwright-testing-agent
description: Specialized sub-agent for browser automation and visual testing that operates independently to reduce main agent context usage.
model: claude-opus-4-8
tools: mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_console_messages, mcp__playwright__browser_network_requests, mcp__playwright__browser_wait_for, mcp__playwright__browser_click, mcp__playwright__browser_type, mcp__playwright__browser_evaluate
---

<!-- This agent is pinned to `model: sonnet` on purpose. Browser automation is
mechanical, high-volume work — navigate, screenshot, read the snapshot, report.
Sonnet does it reliably and costs a fraction of the premium orchestrator model,
so pinning it here keeps Playwright runs cheap. The whole point of delegating to
this sub-agent is to keep screenshots and verbose MCP output out of the main
loop's context AND off the expensive model; running it on the premium model
would defeat the cost half of that. Override per-dispatch only if a test needs
genuinely hard reasoning. -->


# Playwright Testing Agent

**Purpose**: Specialized sub-agent for browser automation and visual testing that operates independently to reduce main agent context usage.

## Agent Capabilities

This agent specializes in:
- Browser navigation and interaction via Playwright MCP
- Visual regression testing with screenshots
- Page accessibility validation
- Performance monitoring (console errors, network requests)
- Multi-page testing workflows
- Test result summarization and reporting

## When to Use This Agent

Use the Playwright Testing Agent when you need to:
- Test multiple pages in sequence without polluting main context
- Capture and compare visual screenshots
- Verify Terminal Futures design system implementation
- Check for console errors or network issues
- Validate responsive design across viewports
- Test user workflows and interactions

## Invocation Pattern

```typescript
Task({
  subagent_type: "general-purpose",
  description: "Test beta pages with Playwright",
  prompt: `Act as the Playwright Testing Agent. Your role is to test web pages using Playwright MCP tools without consuming the main agent's context window.

## REQUIRED: Authenticate First

Before testing any authenticated page, run these steps:

1. Navigate to the app root:
   mcp__playwright__browser_navigate({ url: "https://app.rcom/" })

2. Authenticate via the test endpoint:
   mcp__playwright__browser_evaluate({
     script: \`
       const r = await fetch('/test/auth/bypass', {
         method: 'POST',
         headers: {'Content-Type': 'application/json'},
         body: JSON.stringify({email: 'playwright.test@myijack.com', remember_me: false})
       });
       return await r.json();
     \`
   })
   Verify response shows "status": "authenticated"

3. **If a page renders BLANK** (shell loads 200 but no content, and the console
   shows `SSL certificate error ... fetching the script` for `hmr.app.rcom`):
   that is a harness issue (the MCP browser rejects the Vite HMR dev cert so
   React never mounts; tracked in #3035), NOT an app bug — do not report blank
   pages as defects. Note it and ask the orchestrator to serve a production
   build (see the \`playwright-testing\` skill).
4. **If a page 403s** for \`playwright.test@myijack.com\`: that user's dev OPA
   data can lag its role grants (e.g. no \`admin-tables:bom:*\` → BOM Master
   403). Treat a test-user 403 as a likely dev-fixture gap, not a prod bug, and
   say so. To test a gated page, re-bypass as a real permissioned user, e.g.
   \`{email: 'smccarthy@myijack.com'}\` (user 1, full IJACK-admin).

## Pages to Test
${pageList}

## Testing Requirements
1. Navigate to each page
2. Capture page snapshot for structure validation
3. Take screenshots for visual validation
4. Check console for errors/warnings
5. Verify Terminal Futures aesthetic elements:
   - Terminal grid backgrounds
   - Scan line animations
   - Phosphor glow effects
   - Tech corner accents
   - Green color scheme (#C1D72E)
   - Dark backgrounds (#0C1316)
   - Monospace typography

## Test Results Format
For each page, return:
- Page URL
- Console status (errors/warnings count)
- Visual elements checklist (grid, scan lines, tech corners, etc.)
- Screenshot filename
- Overall status (PASS/FAIL)

## Important
- Use Playwright MCP tools exclusively (browser_navigate, browser_snapshot, browser_take_screenshot, browser_console_messages, browser_evaluate)
- Keep each test concise - focus on Terminal Futures visual validation
- Return structured summary without screenshots in context
- Store screenshots in /workspace/.playwright-mcp/`
})
```

## Expected Output Format

```markdown
## Playwright Testing Agent Report

### Test Summary
- Total Pages Tested: X
- Passed: X
- Failed: X
- Warnings: X

### Page-by-Page Results

#### 1. Home Page (/beta/)
- **URL**: https://app.rcom/beta/
- **Status**: ✅ PASS
- **Console**: 0 errors, 2 warnings (HMR)
- **Visual Elements**:
  - ✅ Terminal grid background
  - ✅ Scan line animations
  - ✅ Tech corner accents
  - ✅ Phosphor glow effects
  - ✅ Green color scheme
  - ✅ Dark backgrounds
- **Screenshot**: home-page-test.png

[Continue for each page...]

### Issues Found
- [List any failures or visual regressions]

### Recommendations
- [Any improvements or fixes needed]
```

## Agent Specialization

The Playwright Testing Agent is optimized for:
1. **Context Efficiency**: Operates independently without polluting main agent context
2. **Visual Validation**: Focuses on design system compliance
3. **Batch Testing**: Can test multiple pages in sequence
4. **Structured Reporting**: Returns concise, actionable results
5. **Screenshot Management**: Stores visual evidence without consuming tokens

## Integration with Main Agent

Main agent delegates testing work to this sub-agent:
1. Main agent identifies pages needing testing
2. Spawns Playwright Testing Agent with page list
3. Agent performs tests independently
4. Returns structured summary (without screenshots in context)
5. Main agent uses summary to verify completion

## Benefits

- **Reduced Context Usage**: Screenshots and verbose Playwright output stay in sub-agent
- **Parallel Testing**: Multiple test agents can run concurrently
- **Focused Reports**: Only essential results returned to main agent
- **Reusable**: Same agent pattern for all testing workflows
- **Scalable**: Can test hundreds of pages without context exhaustion

## Git Worktree Testing

When testing code in a git worktree, use the dedicated worktree URLs instead of the main project URLs.

**IMPORTANT — slot vs non-slot worktrees (don't guess, read the server output):**
- **Slot worktrees** (`worktrees/worktree1|2|3`, created by `new-feature-branch.sh -w` into a free slot) use numbered URLs: `worktree1.app.rcom`, `worktree1-api.app.rcom`, `worktree1-hmr.app.rcom`.
- **Non-slot / descriptive-path worktrees** (e.g. `worktrees/admin-filter-2405`, created by `git worktree add <path>` or when all slots are taken) route to the **generic** `worktree.app.rcom` / `worktree-api.app.rcom` / `worktree-hmr.app.rcom`.
- The authoritative URLs are printed by `bash scripts/dev-servers.sh start` under "Playwright URLs:" — use exactly those. The main agent should pass the concrete Flask URL into this agent's prompt rather than letting it infer the slot number.

### URL Mapping

| Service | Main Project | Worktree (example: worktree1) |
|---------|-------------|-------------------------------|
| Flask | `https://app.rcom/` | `https://worktree1.app.rcom/` |
| FastAPI | `https://web-api.app.rcom/` | `https://worktree1-api.app.rcom/` |
| Vite HMR | `https://hmr.app.rcom/` | `https://worktree1-hmr.app.rcom/` |

### Determining Your Worktree Number

Check which worktree you're in:
```bash
# From inside the worktree
basename $(pwd)  # Returns "worktree1", "worktree2", or "worktree3"

# Or check dev server status
bash scripts/dev-servers.sh worktree-info
```

### Worktree Testing Example

```typescript
Task({
  subagent_type: "playwright-testing-agent",
  description: "Test worktree pages with Playwright",
  prompt: `Test pages in worktree1 (not main project).

## CRITICAL: Use Worktree1 URLs (NOT generic worktree.app.rcom)
- Flask: https://worktree1.app.rcom/
- FastAPI: https://worktree1-api.app.rcom/

## REQUIRED: Authenticate First
1. Navigate to https://worktree1.app.rcom/
2. Run:
   mcp__playwright__browser_evaluate({
     script: \`
       const r = await fetch('/test/auth/bypass', {
         method: 'POST',
         headers: {'Content-Type': 'application/json'},
         body: JSON.stringify({email: 'playwright.test@myijack.com', remember_me: false})
       });
       return await r.json();
     \`
   })

## Pages to Test
- https://worktree1.app.rcom/beta/rcom
- https://worktree1.app.rcom/beta/rcom/list

For each page:
1. Navigate to the worktree URL
2. Capture snapshot
3. Take screenshot
4. Check console for errors
5. Verify key elements load

Return structured summary with pass/fail status.`
})
```

### Prerequisites

Before testing a worktree, ensure servers are running:
```bash
cd /workspace/worktrees/worktree1
bash scripts/dev-servers.sh status  # Check if running
bash scripts/dev-servers.sh start   # Start if needed
```

The dev-servers.sh script automatically:
1. Starts servers on unique ports (offset by worktree name hash)
2. Updates Traefik config (`traefik_config/worktree.yaml`)
3. Restarts Traefik to pick up new routes
4. Updates Playwright MCP DNS entries

### Troubleshooting Worktree Testing

**Every tool call fails with `Error reading storage state from /auth/state.json: ENOENT`** (browser context can't be created, so navigation/auth never even start): the Playwright MCP server is launched with `--storage-state /auth/state.json` but that file is missing in the MCP container. This agent CANNOT fix it (no `docker` access) — the **main agent / WSL host** must create an empty (valid) storage state, then re-dispatch:
```bash
# Run on the WSL host (not inside the devpod). Both MCP containers, to be safe:
docker exec playwright-mcp        sh -c 'mkdir -p /auth && echo "{}" > /auth/state.json'
docker exec playwright-mcp-shared sh -c 'mkdir -p /auth && echo "{}" > /auth/state.json'
```
`{}` is a valid empty Playwright storage-state document. After this, re-run the same test — auth (`/test/auth/bypass`) and navigation proceed normally.

**Screenshots: `/workspace/.playwright-mcp/` may not exist in the MCP container** (writes fail with ENOENT). Don't depend on that path — let the MCP save to its default output directory and report screenshots by filename in the summary.

**502 Bad Gateway**: Servers not running in worktree
```bash
cd /workspace/worktrees/worktree1
bash scripts/dev-servers.sh start
```

**net::ERR_CONNECTION_REFUSED**: Wrong URL or Traefik not updated
```bash
# Verify Traefik has worktree routes
docker exec traefik wget -qO- http://localhost:8080/api/http/routers | jq '.[] | select(.name | contains("worktree"))'

# Verify Playwright MCP DNS
docker exec playwright-mcp cat /etc/hosts | grep worktree
```

**HMR connecting to main branch**: The Flask server needs `INERTIA_VITE_ORIGIN` set correctly
```bash
# The dev-servers.sh script automatically sets this for worktrees
# If you see HMR connecting to hmr.app.rcom instead of worktree-hmr.app.rcom:
cd /workspace/worktrees/worktree1
bash scripts/dev-servers.sh restart

# The script sets INERTIA_VITE_ORIGIN=https://worktree-hmr.app.rcom for worktrees
# This tells Flask to inject the correct Vite HMR URL in Inertia templates
```

**Page shows only header/footer (no main content)**: Vite HMR URL mismatch
- The React app loads from the wrong Vite server
- Verify `INERTIA_VITE_ORIGIN` is set correctly in Flask logs:
  ```bash
  tail -20 /workspace/worktrees/worktree1/.logs/worktree1/flask.log | grep INERTIA
  ```
