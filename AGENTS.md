# GodotWire — AI Agent Reference

Practical guide for AI agents building Godot games via GodotWire MCP.

## Connection

- **Endpoint:** `POST http://127.0.0.1:6500/mcp`
- **Protocol:** JSON-RPC 2.0 over Streamable HTTP
- **MCP Version:** 2025-03-26

## Workflow: How to Build a Godot Game

### 1. Verify connection
Call `tools/list` to confirm the server is running and see available tools.

### 2. Understand the project
- `get_scene_tree` — see the current scene structure
- `read_file` with `path: "res://project.godot"` — check project settings, autoloads
- `list_directory` with `path: "res://"` — see project file layout
- `get_editor_errors` — check for existing script errors

### 3. Create game content (prefer structured tools over execute_gdscript)

**For scripts:** Use `create_script` and `edit_script`
```
create_script: {path: "res://scripts/player.gd", content: "extends CharacterBody2D\n..."}
edit_script:   {path: "res://scripts/player.gd", search: "old code", replace: "new code"}
```

**For scene nodes:** Use `create_node`, `set_node_property`, `attach_script`
```
create_node:        {name: "Player", type: "CharacterBody2D", parent: "/root/Main"}
set_node_property:  {node_path: "Player", property: "position", value: [640, 360]}
attach_script:      {node_path: "Player", script_path: "res://scripts/player.gd"}
```

**For batch operations:** Use `batch_set_node_properties`
```
batch_set_node_properties: {
  operations: [
    {node_path: "Player", property: "collision_layer", value: 1},
    {node_path: "Player", property: "collision_mask", value: 6}
  ]
}
```

**For complex setup that can't be done with structured tools:** Use `execute_gdscript`
```
execute_gdscript: {code: "var root = EditorInterface.get_edited_scene_root()\n..."}
```

### 4. Save your work
- `save_scene` — save the current scene to disk
- `save_project_settings` — save project.godot after changing settings

### 5. Test the game
- `play_project` — start the game
- `get_game_screenshot` — see what the game looks like
- `execute_game_script` — inspect runtime state
- `simulate_action` / `simulate_key` — automate gameplay testing
- `monitor_game_properties` — snapshot multiple node properties at once
- `stop_project` — stop the game

### 6. Debug issues
- `get_editor_errors` — scan all scripts for parse errors
- `check_script_errors` — check a specific script
- `get_editor_screenshot` — see the editor state
- `execute_game_script` — inspect live game state, print debug info

## Tool Reference (52 tools)

### Scene Tools (12)
| Tool | Description |
|------|-------------|
| `get_scene_tree` | Get the complete scene tree hierarchy |
| `find_nodes` | Find nodes by name pattern, type, or group |
| `create_node` | Create a new node (name, type, parent) |
| `delete_node` | Delete a node by path |
| `duplicate_node` | Duplicate a node with optional new name |
| `reparent_node` | Move a node to a new parent |
| `instantiate_scene` | Instantiate a .tscn/.glb as a child |
| `get_node_info` | Get detailed node info (properties, children, signals) |
| `get_node_children` | List direct children of a node |
| `get_node_methods` | List methods on a node (with optional filter) |
| `get_node_signals` | List signals on a node |
| `attach_script` | Attach a .gd script to a node |

### Script Tools (4)
| Tool | Description |
|------|-------------|
| `execute_gdscript` | Execute arbitrary GDScript in editor context |
| `create_script` | Create a new .gd file |
| `edit_script` | Search-and-replace edit in a script |
| `check_script_errors` | Check a script for parse errors |

### Node Tools (6)
| Tool | Description |
|------|-------------|
| `set_node_property` | Set a property (handles Vector3, Color, etc.) |
| `get_node_property` | Read a property value |
| `batch_set_node_properties` | Set multiple properties in one call |
| `call_node_method` | Call a method with arguments |
| `connect_signal` | Connect a signal between nodes |
| `find_signal_connections` | List all signal connections on a node |

### Editor Tools (10)
| Tool | Description |
|------|-------------|
| `get_editor_screenshot` | Capture editor viewport as PNG (base64) |
| `play_project` | Start playing the project |
| `stop_project` | Stop the running project |
| `get_editor_selection` | Get currently selected nodes |
| `get_editor_errors` | Scan all scripts for errors |
| `open_scene` | Open a scene file in the editor |
| `save_scene` | Save the current scene to disk |
| `get_project_setting` | Read a project setting |
| `set_project_setting` | Set a project setting |
| `save_project_settings` | Save project.godot |

### File Tools (9)
| Tool | Description |
|------|-------------|
| `read_file` | Read file contents |
| `write_file` | Write/overwrite a file |
| `create_file` | Create a new file (fails if exists) |
| `delete_file` | Delete a file |
| `rename_file` | Rename or move a file |
| `list_directory` | List directory contents |
| `search_files` | Full-text search across project files |
| `replace_string_in_file` | Search and replace in a file |
| `create_resource` | Create a .tres resource of any type |

### Runtime Tools (8) — requires game running
| Tool | Description |
|------|-------------|
| `get_game_screenshot` | Capture running game viewport |
| `get_game_scene_tree` | Get the game's scene tree |
| `execute_game_script` | Execute GDScript in game context |
| `get_game_node_properties` | Read properties from game nodes |
| `set_game_node_properties` | Set properties on game nodes |
| `monitor_game_properties` | Snapshot properties from multiple nodes |
| `simulate_key` | Simulate keyboard input |
| `simulate_action` | Simulate InputMap action |

### Navigation Tools (3)
| Tool | Description |
|------|-------------|
| `create_navigation_region` | Create NavigationRegion3D with navmesh |
| `bake_navigation_mesh` | Bake navmesh from child geometry |
| `setup_navigation_agent` | Add/configure NavigationAgent3D |

## Critical Godot Editor Quirks

These behaviors will trip you up if you don't know about them:

### Autoloads require an editor restart
When you add a new autoload via `set_project_setting` (e.g., a GameManager singleton), scripts that reference it will fail with "Identifier not found" until the user **closes and reopens Godot**. Always warn the user after adding autoloads.

### Scene caching vs disk
The Godot editor keeps scenes cached in memory. If you write a `.tscn` file to disk via `write_file`, the editor may still have the old version cached and will overwrite your changes on next save.

**Solution:** Modify the live editor scene instead:
```gdscript
// execute_gdscript
var root = EditorInterface.get_edited_scene_root()
// ... modify nodes ...
EditorInterface.save_scene()
```

Or use the structured tools (`create_node`, `set_node_property`) which operate on the live editor scene directly.

### Node ownership matters for scene saving
When creating nodes via `execute_gdscript`, a node must have its `.owner` set to the scene root to be included when the scene is saved. **Add the child to the tree first, then set owner:**
```gdscript
parent.add_child(new_node)       // FIRST: add to tree
new_node.owner = scene_root       // THEN: set owner
```
If you set owner before adding to the tree, it silently fails and the node won't be saved.

### Groups don't persist in saved scenes
Groups added via `node.add_to_group("name")` in `execute_gdscript` or at runtime are transient. They're lost when the scene is saved and reloaded. **Put group assignments in the script's `_ready()` function instead.**

### Collision layers are bitmasks
`collision_layer = 4` means bit 2 is set (value 4 = layer 3 in the UI). Common setup:
- Player: layer 1, mask 6 (detects enemies + walls)
- Enemies: layer 2, mask 5 (detects player + walls)
- Walls: layer 4, mask 1 (detects player)
- Bullets: layer 0, mask 7 (detects everything on layers 1-3)

### Area2D body_entered can miss fast objects
Fast-moving Area2D objects (bullets) can tunnel through thin StaticBody2D walls because they teleport via `position +=` each frame. **Use raycasting** in `_physics_process` to detect collisions along the movement path:
```gdscript
var space = get_world_2d().direct_space_state
var query = PhysicsRayQueryParameters2D.create(global_position, global_position + motion, wall_mask)
var result = space.intersect_ray(query)
```

### Inner classes with _init() cause parse errors
GDScript inner classes (class defined inside another script) that have `_init()` methods can cause parse error 43. **Use Dictionaries or standalone scripts instead.**

## Best Practices

### Prefer structured tools over execute_gdscript
`execute_gdscript` is powerful but error-prone. Use the purpose-built tools when possible:
- ❌ `execute_gdscript` to create a node, set properties, attach script (3 things that can fail)
- ✅ `create_node` → `set_node_property` → `attach_script` (each verifiable)

### Use screenshots to verify visually
After making visual changes, use `get_editor_screenshot` or `get_game_screenshot` to verify. Don't assume things look right — check.

### Use simulate_action for automated testing
Instead of asking the user to test gameplay:
```
play_project → simulate_action("move_right", true) → wait → get_game_screenshot
```

### Batch your property changes
When setting multiple properties, use `batch_set_node_properties` instead of multiple `set_node_property` calls. It's faster and atomic.

### Check for errors after script changes
After creating or editing scripts, call `check_script_errors` or `get_editor_errors` to verify compilation before moving on.

### Save early, save often
Call `save_scene` after modifying the scene tree. Call `save_project_settings` after changing project settings. Don't wait until the end.

## execute_gdscript Patterns

When you need `execute_gdscript`, these patterns are reliable:

**Get editor scene root and modify:**
```gdscript
var root = EditorInterface.get_edited_scene_root()
var player = root.get_node("Player")
player.position = Vector2(100, 200)
EditorInterface.save_scene()
return "Done"
```

**Create a complete node hierarchy:**
```gdscript
var root = EditorInterface.get_edited_scene_root()
var enemy = CharacterBody2D.new()
enemy.name = "Enemy"
var col = CollisionShape2D.new()
var shape = CircleShape2D.new()
shape.radius = 16.0
col.shape = shape
enemy.add_child(col)
root.add_child(enemy)
enemy.owner = root
col.owner = root    // children need owner set too!
EditorInterface.save_scene()
return "Enemy created"
```

**Build and save a PackedScene:**
```gdscript
var root = CharacterBody2D.new()
root.name = "Bullet"
var col = CollisionShape2D.new()
// ... setup ...
root.add_child(col)
col.owner = root
var scene = PackedScene.new()
scene.pack(root)
ResourceSaver.save(scene, "res://scenes/bullet.tscn")
root.queue_free()
return "Scene saved"
```

**Query runtime game state:**
```gdscript
// Use with execute_game_script (not execute_gdscript)
var enemies = get_tree().get_nodes_in_group("enemies")
var result = "Enemies: " + str(enemies.size()) + "\n"
for e in enemies:
    result += e.name + " pos:" + str(e.global_position) + " hp:" + str(e.health) + "\n"
return result
```

## Common Mistakes to Avoid

1. **Don't forget `return`** in `execute_gdscript` — without it, you get no output
2. **Don't use `await`** in `execute_gdscript` — it returns immediately, the awaited code runs later
3. **Don't modify `.tscn` files with `write_file`** — the editor will overwrite them. Use scene tree tools or `execute_gdscript` with `EditorInterface`
4. **Don't assume runtime tools work without `play_project`** — they require the game to be running
5. **Don't set `owner` before `add_child`** — it silently fails
6. **Don't use inner classes with `_init()`** — causes parse error 43, use Dictionaries instead
