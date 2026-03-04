<p align="center">
  <img src="godot-wire.png" alt="GodotWire">
</p>

<h1 align="center">GodotWire</h1>

<p align="center">MCP server for Godot Engine — wires AI to your editor and running game.</p>

## What is this?

GodotWire is a Godot 4.x editor plugin that implements the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) 2025 spec, allowing AI assistants (Claude, GPT, Copilot, etc.) to directly inspect and manipulate your Godot project.

**Key features:**
- **Streamable HTTP transport** (MCP 2025-03-26 standard) — single `/mcp` endpoint
- **Modular tool architecture** — drop a `.gd` file in `tools/` to add capabilities
- **52 tools** across 7 categories (scene, script, node, editor, file, runtime, navigation)
- **Game bridge** — execute scripts, simulate input, and capture screenshots from running games
- **AI assistant ready** — see [AGENTS.md](AGENTS.md) for AI-specific usage guide

## Installation

### Option A: Copy (simple)

```bash
# From your Godot project root:
git clone https://github.com/nehpe/godot-wire.git /tmp/godot-wire
cp -r /tmp/godot-wire/addons/godot_wire addons/godot_wire
```

### Option B: Symlink (for development)

```bash
# Clone the repo somewhere persistent:
git clone https://github.com/nehpe/godot-wire.git ~/dev/godot-wire

# From your Godot project root:
mkdir -p addons
ln -s ~/dev/godot-wire/addons/godot_wire addons/godot_wire
```

### Enable the Plugin

1. Open your project in **Godot 4.4+**
2. Go to **Project → Project Settings → Plugins**
3. Find **GodotWire** and click **Enable**
4. The MCP server starts automatically on `127.0.0.1:6500`

### Verify It's Running

You should see in the Godot output panel:
```
GodotWire: Streamable HTTP server listening on 127.0.0.1:6500
GodotWire: Plugin loaded — 52 tools registered
```

Quick test from a terminal:
```bash
curl -s -X POST http://127.0.0.1:6500/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  | python3 -m json.tool | head -20
```

## MCP Client Configuration

GodotWire uses **Streamable HTTP** — send JSON-RPC 2.0 POST requests to `http://127.0.0.1:6500/mcp`.

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%/Claude/claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "godot-wire": {
      "url": "http://127.0.0.1:6500/mcp"
    }
  }
}
```

### VS Code / GitHub Copilot

Add to `.vscode/mcp.json` in your project or `~/.vscode/mcp.json` globally:

```json
{
  "servers": {
    "godot-wire": {
      "type": "http",
      "url": "http://127.0.0.1:6500/mcp"
    }
  }
}
```

### Cursor

Add to `.cursor/mcp.json` in your project root:

```json
{
  "mcpServers": {
    "godot-wire": {
      "url": "http://127.0.0.1:6500/mcp"
    }
  }
}
```

### Any MCP Client

Point your client to: `http://127.0.0.1:6500/mcp`

The server accepts standard JSON-RPC 2.0 over HTTP POST. No authentication required (localhost only).

## Tools

| Module | Tools | Description |
|--------|-------|-------------|
| `scene_tools` | 12 | Scene tree, nodes, instantiation, node details, attach script |
| `script_tools` | 4 | Execute GDScript, create, edit, check errors |
| `node_tools` | 6 | Properties, methods, signals, batch operations |
| `editor_tools` | 10 | Screenshots, play/stop, selection, scene/project management |
| `file_tools` | 9 | Read, write, create, delete, rename, search, resources |
| `runtime_tools` | 8 | Game screenshots, scene tree, execute, input sim, properties |
| `navigation_tools` | 3 | Nav regions, navmesh baking, nav agents |

**Total: 52 tools** — see [AGENTS.md](AGENTS.md) for the full tool reference with parameters.

## Quick Examples

**Create a node and set properties:**
```json
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{
  "name": "create_node",
  "arguments": {"name": "Enemy", "type": "CharacterBody2D", "parent": "/root/Main"}
}}
```

**Execute GDScript in the editor:**
```json
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{
  "name": "execute_gdscript",
  "arguments": {"code": "var root = EditorInterface.get_edited_scene_root()\nreturn root.name"}
}}
```

**Play the game and simulate input:**
```json
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{
  "name": "play_project", "arguments": {}
}}

{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{
  "name": "simulate_action",
  "arguments": {"action": "move_right", "pressed": true}
}}
```

**Capture a game screenshot:**
```json
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{
  "name": "get_game_screenshot", "arguments": {}
}}
```

## Adding Custom Tools

Create a new `.gd` file in `addons/godot_wire/tools/`:

```gdscript
extends GodotWireTool

func get_tools() -> Array:
    return [
        {
            "name": "my_custom_tool",
            "description": "Does something cool",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "arg1": {"type": "string", "description": "An argument"}
                },
                "required": ["arg1"]
            }
        }
    ]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
    match tool_name:
        "my_custom_tool":
            return _success("It worked!")
    return _error("Unknown tool")
```

The tool is auto-discovered on plugin load. No registration needed.

## Architecture

```
MCP Client (Claude, Copilot, etc.)
    ↓ POST /mcp (JSON-RPC 2.0)
server.gd (Streamable HTTP on port 6500)
    ↓
protocol.gd (MCP 2025-03-26 spec)
    ↓
tool_registry.gd (auto-discovers modules)
    ↓
tools/*.gd (modular tool implementations)
    ↓
game_bridge.gd ←→ game_autoload.gd (TCP bridge to running game)
```

## Troubleshooting

### Server won't start
- **Port in use:** Another instance of Godot with GodotWire may be running. Change the port in Project Settings → `godot_wire/server_port`.
- **Plugin not enabled:** Check Project → Project Settings → Plugins → GodotWire is toggled on.

### Tools return errors about autoloads
- **Autoloads need an editor restart** to be recognized by the script compiler. If you add a new autoload (e.g. via `set_project_setting`), close and reopen the Godot editor.

### Runtime tools fail
- Runtime tools (`execute_game_script`, `get_game_screenshot`, `simulate_action`, etc.) only work while the game is running. Call `play_project` first.
- The **GodotWireGameBridge** autoload must be registered. GodotWire adds it automatically, but if it's missing, add it manually in Project Settings → Autoload.

### Scene changes don't persist
- After modifying the scene tree via tools, call `save_scene` to write to disk.
- If the editor has a cached version open, it may overwrite your changes on save. Use `execute_gdscript` with `EditorInterface.get_edited_scene_root()` to modify the live editor scene, then `EditorInterface.save_scene()`.

### Groups don't persist in saved scenes
- Groups added via `node.add_to_group()` in `execute_gdscript` are runtime-only. To persist groups in a scene, add them in the node's script `_ready()` function instead.

## Requirements

- Godot 4.4+
- Localhost only (127.0.0.1) — not exposed to network

## License

MIT
