extends GodotWireTool
## Node property manipulation, method calling, and signal tools.

func get_tools() -> Array:
	return [
		{
			"name": "set_node_property",
			"description": "Set a property on a node in the scene tree",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node"},
					"property": {"type": "string", "description": "Property name (e.g. position, visible, modulate)"},
					"value": {"description": "Value to set (type-appropriate: number, string, bool, array, etc.)"}
				},
				"required": ["path", "property", "value"]
			}
		},
		{
			"name": "get_node_property",
			"description": "Get the current value of a node property",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node"},
					"property": {"type": "string", "description": "Property name to read"}
				},
				"required": ["path", "property"]
			}
		},
		{
			"name": "batch_set_node_properties",
			"description": "Set multiple properties on one or more nodes in a single call",
			"inputSchema": {
				"type": "object",
				"properties": {
					"operations": {
						"type": "array",
						"description": "Array of {path, property, value} objects",
						"items": {
							"type": "object",
							"properties": {
								"path": {"type": "string"},
								"property": {"type": "string"},
								"value": {}
							},
							"required": ["path", "property", "value"]
						}
					}
				},
				"required": ["operations"]
			}
		},
		{
			"name": "call_node_method",
			"description": "Call a method on a node with optional arguments",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node"},
					"method": {"type": "string", "description": "Method name to call"},
					"args": {"type": "array", "description": "Arguments to pass to the method"}
				},
				"required": ["path", "method"]
			}
		},
		{
			"name": "connect_signal",
			"description": "Connect a signal from one node to a method on another node",
			"inputSchema": {
				"type": "object",
				"properties": {
					"source": {"type": "string", "description": "Path to the source node (emits signal)"},
					"signal_name": {"type": "string", "description": "Signal name"},
					"target": {"type": "string", "description": "Path to the target node"},
					"method": {"type": "string", "description": "Method name on the target"}
				},
				"required": ["source", "signal_name", "target", "method"]
			}
		},
		{
			"name": "find_signal_connections",
			"description": "List all signal connections on a node",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node"}
				},
				"required": ["path"]
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"set_node_property":
			return _set_node_property(args)
		"get_node_property":
			return _get_node_property(args)
		"batch_set_node_properties":
			return _batch_set(args)
		"call_node_method":
			return _call_node_method(args)
		"connect_signal":
			return _connect_signal(args)
		"find_signal_connections":
			return _find_signal_connections(args)
		_:
			return _error("Unknown tool: %s" % tool_name)

func _set_node_property(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var prop: String = args.get("property", "")
	var value = args.get("value")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var converted = _convert_value(node, prop, value)
	node.set(prop, converted)
	return _success("Set %s.%s = %s" % [node.name, prop, str(converted)])

func _get_node_property(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var prop: String = args.get("property", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var val = node.get(prop)
	return _success("%s.%s = %s" % [node.name, prop, str(val)])

func _batch_set(args: Dictionary) -> Dictionary:
	var operations: Array = args.get("operations", [])
	var results: Array = []
	var errors: int = 0
	for op in operations:
		var path: String = op.get("path", "")
		var prop: String = op.get("property", "")
		var value = op.get("value")
		var node := _resolve_node(path)
		if node == null:
			results.append("FAIL: Node not found: %s" % path)
			errors += 1
			continue
		var converted = _convert_value(node, prop, value)
		node.set(prop, converted)
		results.append("OK: %s.%s = %s" % [node.name, prop, str(converted)])
	var summary := "%d/%d operations succeeded\n" % [operations.size() - errors, operations.size()]
	summary += "\n".join(results)
	return _success(summary) if errors == 0 else _error(summary)

func _call_node_method(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var method_name: String = args.get("method", "")
	var method_args: Array = args.get("args", [])
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not node.has_method(method_name):
		return _error("Node %s has no method: %s" % [node.name, method_name])
	var result = node.callv(method_name, method_args)
	if result == null:
		return _success("Called %s.%s() — no return value" % [node.name, method_name])
	return _success("Called %s.%s() = %s" % [node.name, method_name, str(result)])

func _connect_signal(args: Dictionary) -> Dictionary:
	var source_path: String = args.get("source", "")
	var signal_name: String = args.get("signal_name", "")
	var target_path: String = args.get("target", "")
	var method_name: String = args.get("method", "")
	var source := _resolve_node(source_path)
	if source == null:
		return _error("Source node not found: %s" % source_path)
	var target := _resolve_node(target_path)
	if target == null:
		return _error("Target node not found: %s" % target_path)
	if source.is_connected(signal_name, Callable(target, method_name)):
		return _error("Signal already connected")
	source.connect(signal_name, Callable(target, method_name))
	return _success("Connected %s.%s -> %s.%s" % [source.name, signal_name, target.name, method_name])

func _find_signal_connections(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var text := "Signal connections for %s:\n" % node.name
	var signal_list := node.get_signal_list()
	var found := false
	for sig in signal_list:
		var connections := node.get_signal_connection_list(sig.name)
		if connections.size() > 0:
			found = true
			for conn in connections:
				text += "  %s -> %s.%s\n" % [sig.name, conn.callable.get_object().name if conn.callable.get_object() else "?", conn.callable.get_method()]
	if not found:
		text += "  (no connections)\n"
	return _success(text)

func _convert_value(node: Node, prop: String, value):
	var current = node.get(prop)
	if current is Vector3 and value is Array and value.size() == 3:
		return Vector3(value[0], value[1], value[2])
	if current is Vector2 and value is Array and value.size() == 2:
		return Vector2(value[0], value[1])
	if current is Color and value is String:
		return Color(value)
	if current is Color and value is Array and value.size() >= 3:
		return Color(value[0], value[1], value[2], value[3] if value.size() > 3 else 1.0)
	return value
