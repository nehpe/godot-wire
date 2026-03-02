@tool
class_name GameBridge extends Node
## TCP backchannel between editor plugin and running game.
## Editor listens on port 6501, game connects as client.

signal game_connected
signal game_disconnected

const BRIDGE_PORT := 6501
const BIND_HOST := "127.0.0.1"

var _tcp_server: TCPServer
var _client: StreamPeerTCP
var _running: bool = false
var _buffer: String = ""
var _pending_requests: Dictionary = {}  # request_id -> {callback, timestamp}
var _next_request_id: int = 1

func start() -> Error:
	_tcp_server = TCPServer.new()
	var err := _tcp_server.listen(BRIDGE_PORT, BIND_HOST)
	if err != OK:
		push_error("GameBridge: Failed to listen on port %d: %s" % [BRIDGE_PORT, error_string(err)])
		return err
	_running = true
	print("GameBridge: Listening on %s:%d" % [BIND_HOST, BRIDGE_PORT])
	return OK

func stop() -> void:
	_running = false
	if _client:
		_client.disconnect_from_host()
		_client = null
	if _tcp_server:
		_tcp_server.stop()
	_pending_requests.clear()
	print("GameBridge: Stopped")

func poll() -> void:
	if not _running:
		return
	_accept_connection()
	_poll_client()
	_check_timeouts()

func is_game_connected() -> bool:
	return _client != null and _client.get_status() == StreamPeerTCP.STATUS_CONNECTED

func send_request(method: String, params: Dictionary = {}) -> Dictionary:
	if not is_game_connected():
		return {"error": "Game is not connected"}
	var req_id := _next_request_id
	_next_request_id += 1
	var request := JSON.stringify({"id": req_id, "method": method, "params": params}) + "\n"
	_client.put_data(request.to_utf8_buffer())

	# Poll for response (up to 5 seconds)
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		_poll_client()
		if _pending_requests.has(req_id) and _pending_requests[req_id].has("result"):
			var result = _pending_requests[req_id]["result"]
			_pending_requests.erase(req_id)
			return result
		# Mark as pending if not yet
		if not _pending_requests.has(req_id):
			_pending_requests[req_id] = {"timestamp": Time.get_ticks_msec()}
		OS.delay_msec(10)

	_pending_requests.erase(req_id)
	return {"error": "Request timed out (5s)"}

func _accept_connection() -> void:
	if _tcp_server.is_connection_available():
		var new_client := _tcp_server.take_connection()
		if _client != null:
			_client.disconnect_from_host()
		_client = new_client
		_buffer = ""
		print("GameBridge: Game connected")
		game_connected.emit()

func _poll_client() -> void:
	if _client == null:
		return
	_client.poll()
	var status := _client.get_status()
	if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		print("GameBridge: Game disconnected")
		_client = null
		_buffer = ""
		game_disconnected.emit()
		return
	if status != StreamPeerTCP.STATUS_CONNECTED:
		return
	var available := _client.get_available_bytes()
	if available <= 0:
		return
	var data := _client.get_data(available)
	if data[0] != OK:
		return
	_buffer += data[1].get_string_from_utf8()
	# Process complete JSON lines
	while _buffer.find("\n") != -1:
		var nl := _buffer.find("\n")
		var line := _buffer.substr(0, nl).strip_edges()
		_buffer = _buffer.substr(nl + 1)
		if line.is_empty():
			continue
		var json := JSON.new()
		if json.parse(line) != OK:
			continue
		var msg: Dictionary = json.data
		var req_id = msg.get("id")
		if req_id != null and _pending_requests.has(int(req_id)):
			_pending_requests[int(req_id)]["result"] = msg.get("result", {})
		elif not _pending_requests.has(int(req_id)):
			_pending_requests[int(req_id)] = {"result": msg.get("result", {}), "timestamp": Time.get_ticks_msec()}

func _check_timeouts() -> void:
	var now := Time.get_ticks_msec()
	var expired: Array = []
	for req_id in _pending_requests:
		var req: Dictionary = _pending_requests[req_id]
		if req.has("result"):
			continue
		if now - req.get("timestamp", now) > 10000:
			expired.append(req_id)
	for req_id in expired:
		_pending_requests.erase(req_id)
