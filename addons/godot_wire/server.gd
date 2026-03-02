class_name GodotWireServer extends RefCounted
## Streamable HTTP server implementing MCP 2025-03-26 transport.
## Single endpoint: POST/GET on /mcp

signal message_received(client_id: int, body: String)
signal client_connected(client_id: int)
signal client_disconnected(client_id: int)

const BIND_HOST := "127.0.0.1"

var _tcp_server: TCPServer
var _port: int = 6500
var _running: bool = false
var _next_client_id: int = 1
var _clients: Dictionary = {}  # client_id -> ClientState
var _pending_responses: Dictionary = {}  # client_id -> response string
var _session_id: String = ""

class ClientState:
	var id: int
	var peer: StreamPeerTCP
	var buffer: String = ""
	var headers_parsed: bool = false
	var method: String = ""
	var path: String = ""
	var content_length: int = 0
	var headers: Dictionary = {}
	var is_sse: bool = false
	var created_at: int = 0

	func _init(p_id: int, p_peer: StreamPeerTCP) -> void:
		id = p_id
		peer = p_peer
		created_at = Time.get_ticks_msec()

func start(port: int = 6500) -> Error:
	_port = port
	_session_id = _generate_session_id()
	_tcp_server = TCPServer.new()
	var err := _tcp_server.listen(_port, BIND_HOST)
	if err != OK:
		push_error("GodotWire: Failed to listen on port %d: %s" % [_port, error_string(err)])
		return err
	_running = true
	print("GodotWire: Streamable HTTP server listening on %s:%d" % [BIND_HOST, _port])
	return OK

func stop() -> void:
	_running = false
	for client_id in _clients:
		var client: ClientState = _clients[client_id]
		client.peer.disconnect_from_host()
	_clients.clear()
	if _tcp_server:
		_tcp_server.stop()
	print("GodotWire: Server stopped")

func poll() -> void:
	if not _running:
		return
	_accept_connections()
	_poll_clients()

func send_response(client_id: int, data: String) -> void:
	_pending_responses[client_id] = data

func is_running() -> bool:
	return _running

func get_port() -> int:
	return _port

func _accept_connections() -> void:
	while _tcp_server.is_connection_available():
		var peer := _tcp_server.take_connection()
		var cid := _next_client_id
		_next_client_id += 1
		_clients[cid] = ClientState.new(cid, peer)
		client_connected.emit(cid)

func _poll_clients() -> void:
	var to_remove: Array[int] = []
	for client_id in _clients:
		var client: ClientState = _clients[client_id]
		var peer := client.peer
		peer.poll()

		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			to_remove.append(client_id)
			continue
		if status != StreamPeerTCP.STATUS_CONNECTED:
			continue

		var available := peer.get_available_bytes()
		if available > 0:
			var data := peer.get_data(available)
			if data[0] == OK:
				client.buffer += data[1].get_string_from_utf8()
				_try_parse(client)

		# Send pending response
		if _pending_responses.has(client_id):
			_send_http_response(client, _pending_responses[client_id])
			_pending_responses.erase(client_id)
			to_remove.append(client_id)

	for cid in to_remove:
		if _clients.has(cid):
			_clients[cid].peer.disconnect_from_host()
			_clients.erase(cid)
			client_disconnected.emit(cid)

func _try_parse(client: ClientState) -> void:
	if not client.headers_parsed:
		var header_end := client.buffer.find("\r\n\r\n")
		if header_end == -1:
			return
		var header_block := client.buffer.substr(0, header_end)
		var body_start := header_end + 4
		_parse_headers(client, header_block)
		client.buffer = client.buffer.substr(body_start)
		client.headers_parsed = true

	if client.method == "POST":
		if client.buffer.length() >= client.content_length:
			var body := client.buffer.substr(0, client.content_length)
			client.buffer = client.buffer.substr(client.content_length)
			_handle_post(client, body)
	elif client.method == "GET":
		_handle_get(client)
	elif client.method == "OPTIONS":
		_handle_options(client)
	elif client.method == "DELETE":
		_handle_delete(client)

func _parse_headers(client: ClientState, header_block: String) -> void:
	var lines := header_block.split("\r\n")
	if lines.size() == 0:
		return
	var request_line := lines[0].split(" ")
	if request_line.size() >= 2:
		client.method = request_line[0]
		client.path = request_line[1]
	for i in range(1, lines.size()):
		var colon := lines[i].find(":")
		if colon > 0:
			var key := lines[i].substr(0, colon).strip_edges().to_lower()
			var val := lines[i].substr(colon + 1).strip_edges()
			client.headers[key] = val
			if key == "content-length":
				client.content_length = val.to_int()

func _handle_post(client: ClientState, body: String) -> void:
	if client.path != "/mcp":
		_send_raw(client, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
		return
	message_received.emit(client.id, body)

func _handle_get(client: ClientState) -> void:
	if client.path != "/mcp":
		_send_raw(client, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
		return
	# SSE upgrade — for now return 405 (Phase 2: implement SSE streaming)
	_send_raw(client, "HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\n\r\n")

func _handle_options(client: ClientState) -> void:
	var resp := "HTTP/1.1 204 No Content\r\n"
	resp += "Access-Control-Allow-Origin: *\r\n"
	resp += "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS\r\n"
	resp += "Access-Control-Allow-Headers: Content-Type, Mcp-Session-Id\r\n"
	resp += "Access-Control-Expose-Headers: Mcp-Session-Id\r\n"
	resp += "\r\n"
	_send_raw(client, resp)

func _handle_delete(client: ClientState) -> void:
	# Session termination
	_send_raw(client, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")

func _send_http_response(client: ClientState, json_body: String) -> void:
	var body_bytes := json_body.to_utf8_buffer()
	var resp := "HTTP/1.1 200 OK\r\n"
	resp += "Content-Type: application/json\r\n"
	resp += "Content-Length: %d\r\n" % body_bytes.size()
	resp += "Access-Control-Allow-Origin: *\r\n"
	resp += "Access-Control-Expose-Headers: Mcp-Session-Id\r\n"
	resp += "Mcp-Session-Id: %s\r\n" % _session_id
	resp += "\r\n"
	var header_bytes := resp.to_utf8_buffer()
	var combined := PackedByteArray()
	combined.append_array(header_bytes)
	combined.append_array(body_bytes)
	client.peer.put_data(combined)

func _send_raw(client: ClientState, text: String) -> void:
	client.peer.put_data(text.to_utf8_buffer())

func _generate_session_id() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var result := ""
	for i in 16:
		result += chars[randi() % chars.length()]
	return result
