# PDLC Autopilot — C4 Architecture Model

Interactive C4 architecture model using [LikeC4](https://likec4.dev).

## Quick Start

```bash
# View interactive architecture diagrams
npx likec4 serve architecture/

# Export to static HTML
npx likec4 export architecture/ -o architecture/dist/
```

## Files

| File | Level | What it defines |
|------|-------|----------------|
| `model.likec4` | Context + Container | Systems, containers, and their relationships |
| `components.likec4` | Component | Internal modules within Library Modules and Hook Scripts |
| `views.likec4` | Views | Diagram definitions (context, container, component, dynamic) |

## C4 Levels

1. **Context** — PDLC in the ecosystem (Developer, Claude Code, Git/GitHub)
2. **Container** — Outer Loop, Hook Scripts, Library Modules, Tests, Formal Verification, HANDOFF.md
3. **Component** — Director, lifecycle, placeholder, xref, quality, freshness, lint, semantic
4. **Dynamic** — Director decision loop (infer → decide → dispatch → evaluate)

## MCP Server (for Claude Code)

LikeC4 provides a native MCP server that allows Claude Code to query the architecture model:

```bash
# Start MCP server (add to Claude Code settings)
npx likec4 mcp architecture/
```

Add to `.claude/settings.json`:

```json
{
  "mcpServers": {
    "likec4": {
      "command": "npx",
      "args": ["likec4", "mcp", "architecture/"]
    }
  }
}
```

## Updating the Model

When you add new components or change relationships:
1. Edit the relevant `.likec4` file
2. Run `npx likec4 serve architecture/` to preview
3. Commit the changes alongside your code
