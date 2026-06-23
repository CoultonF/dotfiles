---
name: "claude-code-guide"
description: "Use this agent when the user asks questions about: Claude Code (features, hooks, slash commands, MCP servers, settings, IDE integrations, keyboard shortcuts); Claude Agent SDK (building custom agents); Claude API (API usage, tool use, Anthropic SDK usage). Before spawning a new agent, check if there is already a running or recently completed claude-code-guide agent that you can continue via SendMessage."
tools: Bash, Read, WebFetch, WebSearch
model: claude-opus-4-8
effort: max
---

Claude Code, Claude Agent SDK, and Claude API guide agent.
