extends GodotWireTool
## Runtime tools that communicate with the running game via TCP bridge.

func get_tools() -> Array:
	return [
		{
			"name": "get_game_screenshot",
			"description": "Capture a screenshot of the running game viewport",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		},
		{
			"name": "get_game_scene_tree",
			"description": "Get the scene tree of the running game",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		},
		{
			"name": "execute_game_script",
			"description": "Execute GDScript code in the running game context",
			"inputSchema": {
				"type": "object",
				"properties": {
					"code": {"type": "string", "description": "GDScript code to execute in the game"}
				},
				"required": ["code"]
			}
		},
		{
			"name": "get_game_node_properties",
			"description": "Read properties from a node in the running game",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Node path in the game scene"},
					"properties": {"type": "array", "items": {"type": "string"}, "description": "Property names to read (empty = all editor properties)"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "set_game_node_properties",
			"description": "Set properties on a node in the running game",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Node path in the game scene"},
					"properties": {"type": "object", "description": "Property name-value pairs to set"}
				},
				"required": ["path", "properties"]
			}
		},
		{
			"name": "monitor_game_properties",
			"description": "Snapshot properties from multiple game nodes at once",
			"inputSchema": {
				"type": "object",
				"properties": {
					"nodes": {
						"type": "array",
						"description": "Array of {path, properties} objects to monitor",
						"items": {
							"type": "object",
							"properties": {
								"path": {"type": "string"},
								"properties": {"type": "array", "items": {"type": "string"}}
							}
						}
					}
				},
				"required": ["nodes"]
			}
		},
		{
			"name": "simulate_key",
			"description": "Simulate a keyboard key press/release in the running game",
			"inputSchema": {
				"type": "object",
				"properties": {
					"key": {"type": "string", "description": "Key name (W, A, S, D, UP, DOWN, LEFT, RIGHT, SPACE, etc.)"},
					"pressed": {"type": "boolean", "description": "True for press, false for release (default: true)"}
				},
				"required": ["key"]
			}
		},
		{
			"name": "simulate_action",
			"description": "Simulate an input action press/release in the running game",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "description": "Action name from InputMap"},
					"pressed": {"type": "boolean", "description": "True for press, false for release (default: true)"},
					"strength": {"type": "number", "description": "Action strength 0.0-1.0 (default: 1.0)"}
				},
				"required": ["action"]
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	if game_bridge == null:
		return _error("Game bridge not available")
	if not game_bridge.is_game_connected():
		return _error("Game is not running or not connected. Start the game first with play_project.")

	match tool_name:
		"get_game_screenshot":
			return _game_screenshot()
		"get_game_scene_tree":
			return _game_scene_tree()
		"execute_game_script":
			return _game_execute(args)
		"get_game_node_properties":
			return _game_get_props(args)
		"set_game_node_properties":
			return _game_set_props(args)
		"monitor_game_properties":
			return _game_monitor(args)
		"simulate_key":
			return _game_key(args)
		"simulate_action":
			return _game_action(args)
		_:
			return _error("Unknown tool: %s" % tool_name)

func _game_screenshot() -> Dictionary:
	var result := game_bridge.send_request("get_screenshot")
	if result.has("error"):
		return _error(result["error"])
	if result.has("image"):
		return {"content": [{"type": "image", "data": result["image"], "mimeType": "image/png"}]}
	return _error("No image in response")

func _game_scene_tree() -> Dictionary:
	var result := game_bridge.send_request("get_scene_tree")
	if result.has("error"):
		return _error(result["error"])
	return _success(result.get("tree", "empty"))

func _game_execute(args: Dictionary) -> Dictionary:
	var result := game_bridge.send_request("execute_script", {"code": args.get("code", "")})
	if result.has("error"):
		return _error(result["error"])
	return _success(result.get("text", "done"))

func _game_get_props(args: Dictionary) -> Dictionary:
	var result := game_bridge.send_request("get_node_properties", {
		"path": args.get("path", ""),
		"properties": args.get("properties", [])
	})
	if result.has("error"):
		return _error(result["error"])
	var props: Dictionary = result.get("properties", {})
	var text := "Properties of %s:\n" % args.get("path", "")
	for key in props:
		text += "  %s = %s\n" % [key, props[key]]
	return _success(text)

func _game_set_props(args: Dictionary) -> Dictionary:
	var result := game_bridge.send_request("set_node_properties", {
		"path": args.get("path", ""),
		"properties": args.get("properties", {})
	})
	if result.has("error"):
		return _error(result["error"])
	return _success(result.get("text", "done"))

func _game_monitor(args: Dictionary) -> Dictionary:
	var result := game_bridge.send_request("monitor_properties", {
		"nodes": args.get("nodes", [])
	})
	if result.has("error"):
		return _error(result["error"])
	var snapshot: Dictionary = result.get("snapshot", {})
	var text := "Property snapshot:\n"
	for path in snapshot:
		text += "\n%s:\n" % path
		var vals = snapshot[path]
		if vals is Dictionary:
			for key in vals:
				text += "  %s = %s\n" % [key, vals[key]]
	return _success(text)

func _game_key(args: Dictionary) -> Dictionary:
	var result := game_bridge.send_request("simulate_key", {
		"key": args.get("key", ""),
		"pressed": args.get("pressed", true)
	})
	if result.has("error"):
		return _error(result["error"])
	return _success(result.get("text", "done"))

func _game_action(args: Dictionary) -> Dictionary:
	var result := game_bridge.send_request("simulate_action", {
		"action": args.get("action", ""),
		"pressed": args.get("pressed", true),
		"strength": args.get("strength", 1.0)
	})
	if result.has("error"):
		return _error(result["error"])
	return _success(result.get("text", "done"))
