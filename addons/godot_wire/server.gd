class_name GodotWireServer extends RefCounted
## Streamable HTTP server implementing MCP 2025-03-26 transport.
## Single endpoint: POST/GET/DELETE on /mcp
## Supports JSON responses and Server-Sent Events (SSE) streaming.

signal message_received(client_id: int, body: String)
signal sse_message_received(client_id: int, body: String)
signal client_connected(client_id: int)
signal client_disconnected(client_id: int)

const BIND_HOST := "127.0.0.1"
const SSE_KEEPALIVE_INTERVAL := 15000  # ms between keepalive comments

var _tcp_server: TCPServer
var _port: int = 6500
var _running: bool = false
var _next_client_id: int = 1
var _clients: Dictionary = {}  # client_id -> ClientState
var _pending_responses: Dictionary = {}  # client_id -> response string
var _pending_sse_events: Dictionary = {}  # client_id -> Array of SSE event strings
var _session_id: String = ""
var _sse_clients: Dictionary = {}  # client_id -> ClientState (long-lived GET streams)

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
	var is_sse_post: bool = false  # POST with Accept: text/event-stream
	var last_keepalive: int = 0
	var created_at: int = 0

	func _init(p_id: int, p_peer: StreamPeerTCP) -> void:
		id = p_id
		peer = p_peer
		created_at = Time.get_ticks_msec()
		last_keepalive = created_at

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
	for client_id in _sse_clients:
		var client: ClientState = _sse_clients[client_id]
		client.peer.disconnect_from_host()
	_sse_clients.clear()
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
	_poll_sse_clients()

func send_response(client_id: int, data: String) -> void:
	# Check if this is an SSE POST client — send as SSE event instead
	if _clients.has(client_id) and _clients[client_id].is_sse_post:
		if not _pending_sse_events.has(client_id):
			_pending_sse_events[client_id] = []
		_pending_sse_events[client_id].append(data)
		return
	_pending_responses[client_id] = data

## Send an SSE event to a specific GET stream client.
func send_sse_event(client_id: int, data: String) -> void:
	if _sse_clients.has(client_id):
		_write_sse_event(_sse_clients[client_id], data)

## Broadcast an SSE event to all connected GET stream clients.
func broadcast_sse_event(data: String) -> void:
	for client_id in _sse_clients:
		_write_sse_event(_sse_clients[client_id], data)

## Get the number of active SSE stream clients.
func get_sse_client_count() -> int:
	return _sse_clients.size()

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

		# Send pending SSE events for SSE POST clients
		if client.is_sse_post and _pending_sse_events.has(client_id):
			var events: Array = _pending_sse_events[client_id]
			for event_data in events:
				_write_sse_event(client, event_data)
			_pending_sse_events.erase(client_id)
			# Close the SSE POST stream after sending the response
			to_remove.append(client_id)

		# Send pending JSON response for regular POST clients
		if not client.is_sse_post and _pending_responses.has(client_id):
			_send_http_response(client, _pending_responses[client_id])
			_pending_responses.erase(client_id)
			to_remove.append(client_id)

	for cid in to_remove:
		if _clients.has(cid):
			_clients[cid].peer.disconnect_from_host()
			_clients.erase(cid)
			_pending_sse_events.erase(cid)
			client_disconnected.emit(cid)

## Poll long-lived SSE GET stream clients — send keepalives and detect disconnects.
func _poll_sse_clients() -> void:
	var to_remove: Array[int] = []
	var now := Time.get_ticks_msec()
	for client_id in _sse_clients:
		var client: ClientState = _sse_clients[client_id]
		var peer := client.peer
		peer.poll()

		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			to_remove.append(client_id)
			continue
		if status != StreamPeerTCP.STATUS_CONNECTED:
			continue

		# Send keepalive comment to prevent connection timeout
		if now - client.last_keepalive > SSE_KEEPALIVE_INTERVAL:
			var err := peer.put_data(":keepalive\n\n".to_utf8_buffer())
			if err != OK:
				to_remove.append(client_id)
			else:
				client.last_keepalive = now

	for cid in to_remove:
		if _sse_clients.has(cid):
			_sse_clients[cid].peer.disconnect_from_host()
			_sse_clients.erase(cid)
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
	var accept := client.headers.get("accept", "")
	if accept.find("text/event-stream") != -1:
		# Client wants SSE streaming response
		client.is_sse_post = true
		_send_sse_headers(client)
		sse_message_received.emit(client.id, body)
	else:
		# Standard JSON response
		message_received.emit(client.id, body)

func _handle_get(client: ClientState) -> void:
	# Health check endpoint
	if client.path == "/health":
		var body := JSON.stringify({
			"status": "ok",
			"server": "GodotWire",
			"version": "0.6.0",
			"session_id": _session_id,
			"sse_clients": _sse_clients.size(),
			"uptime_ms": Time.get_ticks_msec()
		})
		_send_http_response(client, body)
		return
	if client.path != "/mcp":
		_send_raw(client, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
		return
	# Validate session ID if one exists and client provided one
	var client_session := client.headers.get("mcp-session-id", "")
	if client_session != "" and client_session != _session_id:
		_send_raw(client, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")
		return
	# Open SSE stream — move client to long-lived SSE pool
	client.is_sse = true
	_send_sse_headers(client)
	# Move from _clients to _sse_clients (poll loop will skip removal)
	_clients.erase(client.id)
	_sse_clients[client.id] = client
	client.last_keepalive = Time.get_ticks_msec()

func _handle_options(client: ClientState) -> void:
	var resp := "HTTP/1.1 204 No Content\r\n"
	resp += "Access-Control-Allow-Origin: *\r\n"
	resp += "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS\r\n"
	resp += "Access-Control-Allow-Headers: Content-Type, Mcp-Session-Id\r\n"
	resp += "Access-Control-Expose-Headers: Mcp-Session-Id\r\n"
	resp += "\r\n"
	_send_raw(client, resp)

func _handle_delete(client: ClientState) -> void:
	# Session termination — close all SSE streams
	for cid in _sse_clients:
		_sse_clients[cid].peer.disconnect_from_host()
	_sse_clients.clear()
	_send_raw(client, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")

## Send SSE response headers to initiate a text/event-stream connection.
func _send_sse_headers(client: ClientState) -> void:
	var resp := "HTTP/1.1 200 OK\r\n"
	resp += "Content-Type: text/event-stream\r\n"
	resp += "Cache-Control: no-cache\r\n"
	resp += "Connection: keep-alive\r\n"
	resp += "Access-Control-Allow-Origin: *\r\n"
	resp += "Access-Control-Expose-Headers: Mcp-Session-Id\r\n"
	resp += "Mcp-Session-Id: %s\r\n" % _session_id
	resp += "\r\n"
	client.peer.put_data(resp.to_utf8_buffer())

## Write a single SSE event to a client. Format: "event: message\ndata: {json}\n\n"
func _write_sse_event(client: ClientState, json_data: String) -> void:
	var event := "event: message\ndata: %s\n\n" % json_data
	client.peer.put_data(event.to_utf8_buffer())

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
