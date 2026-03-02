extends Node
## Game-side autoload that connects to GodotWire editor bridge via TCP.
## Add this as an autoload in Project Settings.

const BRIDGE_HOST := "127.0.0.1"
const BRIDGE_PORT := 6501
const RECONNECT_INTERVAL := 2.0

var _client: StreamPeerTCP
var _buffer: String = ""
var _connected: bool = false
var _reconnect_timer: float = 0.0

func _ready() -> void:
	_client = StreamPeerTCP.new()
	_try_connect()

func _process(delta: float) -> void:
	if _client == null:
		return
	_client.poll()
	var status := _client.get_status()

	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not _connected:
			_connected = true
			print("GodotWire: Connected to editor bridge")
		_read_requests()
	elif status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		if _connected:
			_connected = false
			print("GodotWire: Disconnected from editor bridge")
		_reconnect_timer += delta
		if _reconnect_timer >= RECONNECT_INTERVAL:
			_reconnect_timer = 0.0
			_try_connect()

func _try_connect() -> void:
	_client.disconnect_from_host()
	_client.connect_to_host(BRIDGE_HOST, BRIDGE_PORT)

func _read_requests() -> void:
	var available := _client.get_available_bytes()
	if available <= 0:
		return
	var data := _client.get_data(available)
	if data[0] != OK:
		return
	_buffer += data[1].get_string_from_utf8()
	while _buffer.find("\n") != -1:
		var nl := _buffer.find("\n")
		var line := _buffer.substr(0, nl).strip_edges()
		_buffer = _buffer.substr(nl + 1)
		if line.is_empty():
			continue
		var json := JSON.new()
		if json.parse(line) != OK:
			continue
		var request: Dictionary = json.data
		_handle_request(request)

func _handle_request(request: Dictionary) -> void:
	var req_id = request.get("id", 0)
	var method: String = request.get("method", "")
	var params: Dictionary = request.get("params", {})
	var result: Dictionary = {}

	match method:
		"get_screenshot":
			result = _get_screenshot()
		"get_scene_tree":
			result = _get_scene_tree()
		"execute_script":
			result = _execute_script(params)
		"get_node_properties":
			result = _get_node_properties(params)
		"set_node_properties":
			result = _set_node_properties(params)
		"monitor_properties":
			result = _monitor_properties(params)
		"simulate_key":
			result = _simulate_key(params)
		"simulate_action":
			result = _simulate_action(params)
		_:
			result = {"error": "Unknown method: %s" % method}

	_send_response(req_id, result)

func _send_response(req_id, result: Dictionary) -> void:
	var response := JSON.stringify({"id": req_id, "result": result}) + "\n"
	_client.put_data(response.to_utf8_buffer())

# --- Request Handlers ---

func _get_screenshot() -> Dictionary:
	var viewport := get_viewport()
	if viewport == null:
		return {"error": "No viewport"}
	var img := viewport.get_texture().get_image()
	if img == null:
		return {"error": "Could not capture"}
	var png := img.save_png_to_buffer()
	return {"image": Marshalls.raw_to_base64(png)}

func _get_scene_tree() -> Dictionary:
	var root := get_tree().current_scene
	if root == null:
		return {"error": "No current scene"}
	return {"tree": _build_tree(root, 0)}

func _build_tree(node: Node, depth: int) -> String:
	var indent := "  ".repeat(depth)
	var line := "%s%s [%s]" % [indent, node.name, node.get_class()]
	var lines: Array = [line]
	for child in node.get_children():
		lines.append(_build_tree(child, depth + 1))
	return "\n".join(lines)

func _execute_script(params: Dictionary) -> Dictionary:
	var code: String = params.get("code", "")
	if code.is_empty():
		return {"error": "No code provided"}
	var script := GDScript.new()
	var wrapped := "extends Node\nfunc _run():\n"
	for line in code.split("\n"):
		wrapped += "\t" + line + "\n"
	script.source_code = wrapped
	var err := script.reload()
	if err != OK:
		return {"error": "Compile error: %s" % error_string(err)}
	var temp := Node.new()
	temp.set_script(script)
	get_tree().current_scene.add_child(temp)
	var result = temp.call("_run")
	temp.queue_free()
	if result == null:
		return {"text": "Executed (no return value)"}
	return {"text": str(result)}

func _get_node_properties(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var properties: Array = params.get("properties", [])
	var node := _find_node(path)
	if node == null:
		return {"error": "Node not found: %s" % path}
	var result: Dictionary = {}
	if properties.is_empty():
		for prop in node.get_property_list():
			if prop.usage & PROPERTY_USAGE_EDITOR:
				result[prop.name] = _safe_str(node.get(prop.name))
	else:
		for prop_name in properties:
			result[prop_name] = _safe_str(node.get(prop_name))
	return {"properties": result}

func _set_node_properties(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var properties: Dictionary = params.get("properties", {})
	var node := _find_node(path)
	if node == null:
		return {"error": "Node not found: %s" % path}
	var set_count := 0
	for key in properties:
		var val = properties[key]
		var current = node.get(key)
		if current is Vector3 and val is Array and val.size() == 3:
			node.set(key, Vector3(val[0], val[1], val[2]))
		elif current is Vector2 and val is Array and val.size() == 2:
			node.set(key, Vector2(val[0], val[1]))
		else:
			node.set(key, val)
		set_count += 1
	return {"text": "Set %d properties on %s" % [set_count, node.name]}

func _monitor_properties(params: Dictionary) -> Dictionary:
	var nodes: Array = params.get("nodes", [])
	var result: Dictionary = {}
	for entry in nodes:
		var path: String = entry.get("path", "")
		var props: Array = entry.get("properties", [])
		var node := _find_node(path)
		if node == null:
			result[path] = {"error": "not found"}
			continue
		var vals: Dictionary = {}
		for p in props:
			vals[p] = _safe_str(node.get(p))
		result[path] = vals
	return {"snapshot": result}

func _simulate_key(params: Dictionary) -> Dictionary:
	var key_name: String = params.get("key", "")
	var pressed: bool = params.get("pressed", true)
	var keycode := _key_name_to_code(key_name)
	if keycode == KEY_NONE:
		return {"error": "Unknown key: %s" % key_name}
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.physical_keycode = keycode
	Input.parse_input_event(event)
	return {"text": "Simulated key %s %s" % [key_name, "pressed" if pressed else "released"]}

func _simulate_action(params: Dictionary) -> Dictionary:
	var action: String = params.get("action", "")
	var pressed: bool = params.get("pressed", true)
	var strength: float = params.get("strength", 1.0)
	if not InputMap.has_action(action):
		return {"error": "Unknown action: %s" % action}
	if pressed:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
	return {"text": "Action %s %s" % [action, "pressed" if pressed else "released"]}

# --- Helpers ---

func _find_node(path: String) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	if path.is_empty() or path == ".":
		return scene
	var node := scene.get_node_or_null(NodePath(path))
	if node:
		return node
	return _find_by_name(scene, path)

func _find_by_name(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var found := _find_by_name(child, target)
		if found:
			return found
	return null

func _safe_str(val) -> String:
	if val == null:
		return "null"
	return str(val)

func _key_name_to_code(key_name: String) -> Key:
	match key_name.to_upper():
		"W": return KEY_W
		"A": return KEY_A
		"S": return KEY_S
		"D": return KEY_D
		"UP": return KEY_UP
		"DOWN": return KEY_DOWN
		"LEFT": return KEY_LEFT
		"RIGHT": return KEY_RIGHT
		"SPACE": return KEY_SPACE
		"ENTER", "RETURN": return KEY_ENTER
		"ESCAPE", "ESC": return KEY_ESCAPE
		"SHIFT": return KEY_SHIFT
		"CTRL", "CONTROL": return KEY_CTRL
		"TAB": return KEY_TAB
		"BACKSPACE": return KEY_BACKSPACE
		"DELETE": return KEY_DELETE
		"F1": return KEY_F1
		"F2": return KEY_F2
		"F3": return KEY_F3
		"F4": return KEY_F4
		"F5": return KEY_F5
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"4": return KEY_4
		"5": return KEY_5
		"E": return KEY_E
		"Q": return KEY_Q
		"R": return KEY_R
		"F": return KEY_F
	return KEY_NONE
