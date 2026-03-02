@tool
extends EditorPlugin

const SETTING_PORT := "godot_wire/server_port"
const SETTING_AUTO_START := "godot_wire/auto_start"
const DEFAULT_PORT := 6500

var _server: GodotWireServer
var _protocol: GodotWireProtocol
var _registry: ToolRegistry
var _bridge: GameBridge

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
	_protocol.send_response.connect(_server.send_response)

	if _get_setting(SETTING_AUTO_START, true):
		var port: int = _get_setting(SETTING_PORT, DEFAULT_PORT)
		_server.start(port)

	print("GodotWire: Plugin loaded — %d tools registered" % _registry.get_tool_count())

func _exit_tree() -> void:
	if _server and _server.is_running():
		_server.stop()
	if _bridge:
		_bridge.stop()
		_bridge.queue_free()
	print("GodotWire: Plugin unloaded")

func _process(_delta: float) -> void:
	if _server:
		_server.poll()
	if _bridge:
		_bridge.poll()

func _on_message_received(client_id: int, body: String) -> void:
	_protocol.handle_message(client_id, body)

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
