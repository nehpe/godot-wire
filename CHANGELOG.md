# Changelog

All notable changes to GodotWire will be documented in this file.

## [0.5.0] - 2026-03-02

### Added
- **Streamable HTTP server** (MCP 2025-03-26 spec) on port 6500
- **Modular tool architecture** with auto-discovery from `tools/` directory
- **TCP game bridge** — editor listens on port 6501, game connects as client (~1ms latency)
- **Game autoload** (`game_autoload.gd`) with auto-reconnect for running games
- **52 tools** across 7 modules:

#### Scene Tools (12)
- `get_scene_tree`, `find_nodes`, `create_node`, `delete_node`
- `duplicate_node`, `reparent_node`, `instantiate_scene`, `get_node_info`
- `get_node_children`, `get_node_methods`, `get_node_signals`, `attach_script`

#### Script Tools (4)
- `execute_gdscript`, `create_script`, `edit_script`, `check_script_errors`

#### Node Tools (6)
- `set_node_property`, `get_node_property`, `batch_set_node_properties`
- `call_node_method`, `connect_signal`, `find_signal_connections`

#### Editor Tools (10)
- `get_editor_screenshot`, `play_project`, `stop_project`
- `get_editor_selection`, `get_editor_errors`
- `open_scene`, `save_scene`
- `get_project_setting`, `set_project_setting`, `save_project_settings`

#### File Tools (9)
- `read_file`, `write_file`, `create_file`, `delete_file`, `rename_file`
- `list_directory`, `search_files`, `replace_string_in_file`, `create_resource`

#### Runtime Tools (8)
- `get_game_screenshot`, `get_game_scene_tree`, `execute_game_script`
- `get_game_node_properties`, `set_game_node_properties`, `monitor_game_properties`
- `simulate_key`, `simulate_action`

#### Navigation Tools (3)
- `create_navigation_region`, `bake_navigation_mesh`, `setup_navigation_agent`
