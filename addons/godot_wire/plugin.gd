@tool
extends EditorPlugin

const SETTING_PORT := "godot_wire/server_port"
const SETTING_AUTO_START := "godot_wire/auto_start"
const DEFAULT_PORT := 6500

var _server: GodotWireServer
var _protocol: GodotWireProtocol
var _registry: ToolRegistry
var _bridge: GameBridge
var _last_error_hash: int = 0  # Track script error changes
var _error_check_timer: float = 0.0

func _enter_tree() -> void:
	_init_settings()
	_bridge = GameBridge.new()
	_bridge.name = "GameBridge"
	add_child(_bridge)
	_bridge.start()

	_registry = ToolRegistry.new()
	_load_tool_modules()
	_server = GodotWireServer.new()
	_protocol = GodotWireProtocol.new(_registry)
	_server.message_received.connect(_on_message_received)
	_server.sse_message_received.connect(_on_message_received)
	_protocol.send_response.connect(_server.send_response)

	if _get_setting(SETTING_AUTO_START, true):
		var port: int = _get_setting(SETTING_PORT, DEFAULT_PORT)
		_server.start(port)

	_connect_editor_signals()
	print("GodotWire: Plugin loaded — %d tools registered" % _registry.get_tool_count())

func _exit_tree() -> void:
	if _server and _server.is_running():
		_server.stop()
	if _bridge:
		_bridge.stop()
		_bridge.queue_free()
	print("GodotWire: Plugin unloaded")

func _process(delta: float) -> void:
	if _server:
		_server.poll()
	if _bridge:
		_bridge.poll()
	# Periodic script error check (every 2 seconds)
	if _server and _server.get_sse_client_count() > 0:
		_error_check_timer += delta
		if _error_check_timer >= 2.0:
			_error_check_timer = 0.0
			_check_script_errors()

func _on_message_received(client_id: int, body: String) -> void:
	_protocol.handle_message(client_id, body)

# --- SSE Notification Events ---

func _connect_editor_signals() -> void:
	# Game bridge events
	_bridge.game_connected.connect(_on_game_connected)
	_bridge.game_disconnected.connect(_on_game_disconnected)
	_bridge.console_output.connect(_on_console_output)

	# Editor scene events (EditorPlugin built-in)
	scene_changed.connect(_on_scene_changed)
	scene_closed.connect(_on_scene_closed)

	# Editor selection events
	var selection := EditorInterface.get_selection()
	if selection:
		selection.selection_changed.connect(_on_selection_changed)

	# File system changes (triggers error re-check)
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.filesystem_changed.connect(_on_filesystem_changed)

func _broadcast_notification(method: String, params: Dictionary = {}) -> void:
	if not _server or _server.get_sse_client_count() == 0:
		return
	var notification := JSON.stringify({
		"jsonrpc": "2.0",
		"method": method,
		"params": params
	})
	_server.broadcast_sse_event(notification)

func _on_game_connected() -> void:
	_broadcast_notification("notifications/game/started", {
		"message": "Game connected to editor bridge"
	})

func _on_game_disconnected() -> void:
	_broadcast_notification("notifications/game/stopped", {
		"message": "Game disconnected from editor bridge"
	})

func _on_scene_changed(scene_root: Node) -> void:
	if scene_root == null:
		return
	var scene_path := scene_root.scene_file_path if scene_root.scene_file_path else "unsaved"
	_broadcast_notification("notifications/editor/scene_changed", {
		"scene": scene_path,
		"root_name": scene_root.name,
		"root_type": scene_root.get_class()
	})

func _on_scene_closed(path: String) -> void:
	_broadcast_notification("notifications/editor/scene_closed", {
		"scene": path
	})

func _on_console_output(entries: Array) -> void:
	_broadcast_notification("notifications/game/console", {
		"entries": entries,
		"count": entries.size()
	})

func _on_selection_changed() -> void:
	var selection := EditorInterface.get_selection()
	if not selection:
		return
	var selected := selection.get_selected_nodes()
	var nodes: Array = []
	for node in selected:
		nodes.append({
			"name": node.name,
			"type": node.get_class(),
			"path": str(node.get_path())
		})
	_broadcast_notification("notifications/editor/selection_changed", {
		"selected": nodes,
		"count": nodes.size()
	})

func _on_filesystem_changed() -> void:
	# Trigger an error re-check when files change
	_check_script_errors()

func _check_script_errors() -> void:
	var errors: Array = []
	var scripts := _scan_scripts("res://")
	for path in scripts:
		if path.begins_with("res://addons/"):
			continue
		var script := ResourceLoader.load(path) as GDScript
		if script == null:
			continue
		var err := script.reload()
		if err != OK:
			errors.append({"path": path, "error": error_string(err)})
	# Only broadcast if errors changed
	var new_hash := errors.hash()
	if new_hash != _last_error_hash:
		_last_error_hash = new_hash
		if errors.size() > 0:
			_broadcast_notification("notifications/scripts/errors", {
				"errors": errors,
				"count": errors.size()
			})
		else:
			_broadcast_notification("notifications/scripts/clear", {
				"message": "All scripts compile successfully"
			})

func _scan_scripts(dir_path: String) -> Array:
	var results: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return results
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if d.current_is_dir():
			if fname != "." and fname != ".." and fname != ".godot":
				results.append_array(_scan_scripts(dir_path.path_join(fname)))
		elif fname.ends_with(".gd"):
			results.append(dir_path.path_join(fname))
		fname = d.get_next()
	d.list_dir_end()
	return results

# --- Module Loading ---

func _load_tool_modules() -> void:
	var tools_dir := "res://addons/godot_wire/tools/"
	var dir := DirAccess.open(tools_dir)
	if dir == null:
		push_warning("GodotWire: Could not open tools directory: %s" % tools_dir)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gd") and file_name != "base_tool.gd":
			var script_path := tools_dir + file_name
			var script := load(script_path)
			if script:
				var instance = script.new(self, _bridge)
				if instance is GodotWireTool:
					_registry.register_module(instance)
				else:
					push_warning("GodotWire: %s does not extend GodotWireTool" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _init_settings() -> void:
	if not ProjectSettings.has_setting(SETTING_PORT):
		ProjectSettings.set_setting(SETTING_PORT, DEFAULT_PORT)
	if not ProjectSettings.has_setting(SETTING_AUTO_START):
		ProjectSettings.set_setting(SETTING_AUTO_START, true)

func _get_setting(key: String, default_value) -> Variant:
	if ProjectSettings.has_setting(key):
		return ProjectSettings.get_setting(key)
	return default_value
