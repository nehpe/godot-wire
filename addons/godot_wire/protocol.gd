class_name GodotWireProtocol extends RefCounted
## JSON-RPC 2.0 protocol handler implementing MCP 2025-03-26 spec.

signal send_response(client_id: int, data: String)

const MCP_VERSION := "2025-03-26"
const SERVER_NAME := "GodotWire"
const SERVER_VERSION := "0.8.0"

var _registry: ToolRegistry
var _initialized: bool = false

func _init(registry: ToolRegistry) -> void:
	_registry = registry

func handle_message(client_id: int, body: String) -> void:
	var json := JSON.new()
	var err := json.parse(body)
	if err != OK:
		_send(client_id, _json_rpc_error(null, -32700, "Parse error"))
		return

	var msg = json.data
	if msg is Array:
		# Batch request
		var responses: Array = []
		for req in msg:
			var resp := _handle_single(req)
			if resp != null:
				responses.append(resp)
		if responses.size() > 0:
			send_response.emit(client_id, JSON.stringify(responses))
		return

	var resp := _handle_single(msg)
	if resp != null:
		_send(client_id, resp)

func _handle_single(msg) -> Variant:
	if not msg is Dictionary:
		return _json_rpc_error(null, -32600, "Invalid request")

	var id = msg.get("id")
	var method: String = msg.get("method", "")

	# Notifications (no id) — don't respond
	if id == null and method.begins_with("notifications/"):
		_handle_notification(method, msg.get("params", {}))
		return null

	match method:
		"initialize":
			return _handle_initialize(id, msg.get("params", {}))
		"ping":
			return _json_rpc_result(id, {})
		"tools/list":
			return _handle_tools_list(id)
		"tools/call":
			return _handle_tools_call(id, msg.get("params", {}))
		"resources/list":
			return _json_rpc_result(id, {"resources": []})
		"resources/read":
			return _json_rpc_result(id, {"contents": []})
		"prompts/list":
			return _json_rpc_result(id, {"prompts": []})
		"logging/setLevel":
			return _json_rpc_result(id, {})
		_:
			return _json_rpc_error(id, -32601, "Method not found: %s" % method)

func _handle_notification(method: String, _params: Dictionary) -> void:
	if method == "notifications/initialized":
		_initialized = true

func _handle_initialize(id, params: Dictionary) -> Dictionary:
	return _json_rpc_result(id, {
		"protocolVersion": MCP_VERSION,
		"capabilities": {
			"tools": {"listChanged": false},
			"resources": {"subscribe": false, "listChanged": false},
		},
		"serverInfo": {
			"name": SERVER_NAME,
			"version": SERVER_VERSION,
		}
	})

func _handle_tools_list(id) -> Dictionary:
	return _json_rpc_result(id, {"tools": _registry.list_tools()})

func _handle_tools_call(id, params: Dictionary) -> Dictionary:
	var tool_name: String = params.get("name", "")
	var args: Dictionary = params.get("arguments", {})
	var result := _registry.call_tool(tool_name, args)
	return _json_rpc_result(id, result)

func _json_rpc_result(id, result) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "result": result}

func _json_rpc_error(id, code: int, message: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}

func _send(client_id: int, data) -> void:
	send_response.emit(client_id, JSON.stringify(data))
