# GodotWire — AI Agent Reference

Quick reference for AI agents connected via MCP.

## Connection

- **Endpoint:** `POST http://127.0.0.1:6500/mcp`
- **Protocol:** JSON-RPC 2.0 over Streamable HTTP
- **MCP Version:** 2025-03-26

## Available Tools (52)

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

## Tips

- **Node paths** can be relative to scene root, absolute, or just a node name (searched recursively)
- **Properties** accept JSON-native types; arrays like `[1, 2, 3]` auto-convert to Vector3
- **Colors** accept hex strings `"#ff0000"` or arrays `[1.0, 0.0, 0.0]`
- **batch_set_node_properties** is much faster than multiple set_node_property calls
- **execute_gdscript** has full editor access — use `return` to get values back
- After modifying the scene, remind the user to **Ctrl+S** to save
