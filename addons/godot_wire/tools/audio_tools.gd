@tool
extends GodotWireTool

## Audio tools — create audio players, load sounds, manage buses, play SFX/music


func get_tools() -> Array:
	return [
		{
			"name": "create_audio_player",
			"description": "Create an AudioStreamPlayer (global), AudioStreamPlayer2D, or AudioStreamPlayer3D node with an optional audio file.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {"type": "string", "description": "Path to parent node"},
					"name": {"type": "string", "description": "Node name (e.g. 'ShootSFX', 'BGM')"},
					"type": {"type": "string", "description": "'global' (AudioStreamPlayer), '2d' (AudioStreamPlayer2D), '3d' (AudioStreamPlayer3D). Default: 'global'"},
					"stream": {"type": "string", "description": "Path to audio file (res://assets/audio/shoot.wav)"},
					"bus": {"type": "string", "description": "Audio bus name (default: 'Master')"},
					"volume_db": {"type": "number", "description": "Volume in dB (default: 0.0)"},
					"pitch_scale": {"type": "number", "description": "Pitch scale (default: 1.0)"},
					"autoplay": {"type": "boolean", "description": "Auto-play when scene starts (default: false)"},
					"max_distance": {"type": "number", "description": "Max audible distance for 2D/3D (default: 2000)"}
				},
				"required": ["parent_path", "name"]
			}
		},
		{
			"name": "play_audio",
			"description": "Play, stop, or configure an AudioStreamPlayer node. Can also load a new stream.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to the AudioStreamPlayer node"},
					"action": {"type": "string", "description": "'play', 'stop', 'pause' (default: 'play')"},
					"stream": {"type": "string", "description": "Load a new audio file before playing"},
					"from_position": {"type": "number", "description": "Start playback from this position in seconds"},
					"volume_db": {"type": "number", "description": "Set volume before playing"},
					"pitch_scale": {"type": "number", "description": "Set pitch before playing"}
				},
				"required": ["node_path"]
			}
		},
		{
			"name": "create_audio_bus",
			"description": "Create or configure an audio bus. Add effects like reverb, delay, distortion, etc.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"bus_name": {"type": "string", "description": "Name of the bus to create or modify"},
					"volume_db": {"type": "number", "description": "Bus volume in dB"},
					"solo": {"type": "boolean", "description": "Solo this bus"},
					"mute": {"type": "boolean", "description": "Mute this bus"},
					"send_to": {"type": "string", "description": "Parent bus name (default: 'Master')"},
					"add_effect": {"type": "string", "description": "'reverb', 'delay', 'distortion', 'chorus', 'eq', 'limiter', 'compressor', 'lowpass', 'highpass', 'bandpass'"}
				},
				"required": ["bus_name"]
			}
		},
		{
			"name": "get_audio_info",
			"description": "Get info about audio buses, or about a specific AudioStreamPlayer node.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AudioStreamPlayer node (if omitted, returns bus layout info)"}
				},
				"required": []
			}
		},
		{
			"name": "create_sfx_pool",
			"description": "Create a pool of AudioStreamPlayer nodes under a parent for polyphonic SFX (e.g. multiple overlapping gunshots).",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {"type": "string", "description": "Path to parent node"},
					"name": {"type": "string", "description": "Pool container name (e.g. 'ShootPool')"},
					"stream": {"type": "string", "description": "Audio file path for all players"},
					"pool_size": {"type": "integer", "description": "Number of audio players in the pool (default: 4)"},
					"type": {"type": "string", "description": "'global' or '2d' (default: '2d')"},
					"bus": {"type": "string", "description": "Audio bus (default: 'SFX' if it exists, else 'Master')"},
					"volume_db": {"type": "number", "description": "Volume in dB (default: 0.0)"},
					"pitch_variation": {"type": "number", "description": "Random pitch variation range (e.g. 0.1 = ±10%). Default: 0.0"}
				},
				"required": ["parent_path", "name"]
			}
		}
	]


func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"create_audio_player":
			return _create_audio_player(args)
		"play_audio":
			return _play_audio(args)
		"create_audio_bus":
			return _create_audio_bus(args)
		"get_audio_info":
			return _get_audio_info(args)
		"create_sfx_pool":
			return _create_sfx_pool(args)
	return _error("Unknown tool: %s" % tool_name)


# ---------------------------------------------------------------------------
# create_audio_player
# ---------------------------------------------------------------------------
func _create_audio_player(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var parent_path: String = args.get("parent_path", ".")
	var parent := root.get_node_or_null(parent_path) if parent_path != "." else root
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var node_name: String = args.get("name", "AudioPlayer")
	var player_type: String = args.get("type", "global")

	var node: Node
	match player_type:
		"2d":
			var p := AudioStreamPlayer2D.new()
			p.max_distance = args.get("max_distance", 2000.0)
			node = p
		"3d":
			var p := AudioStreamPlayer3D.new()
			p.max_distance = args.get("max_distance", 10.0)
			node = p
		_:
			node = AudioStreamPlayer.new()

	node.name = node_name

	# Load stream
	var stream_path: String = args.get("stream", "")
	if stream_path != "":
		var stream := load(stream_path)
		if stream and stream is AudioStream:
			_set_stream(node, stream)
		else:
			return _error("Could not load audio stream: %s" % stream_path)

	# Set properties
	_set_bus(node, args.get("bus", "Master"))
	_set_volume(node, args.get("volume_db", 0.0))
	_set_pitch(node, args.get("pitch_scale", 1.0))
	_set_autoplay(node, args.get("autoplay", false))

	var undo := plugin.get_undo_redo()
	undo.create_action("Create audio player: %s" % node_name)
	undo.add_do_method(parent, "add_child", node)
	undo.add_do_method(node, "set_owner", root)
	undo.add_do_reference(node)
	undo.add_undo_method(parent, "remove_child", node)
	undo.commit_action()

	return _success("Created %s '%s' at %s" % [node.get_class(), node_name, parent.get_path()])


# ---------------------------------------------------------------------------
# play_audio
# ---------------------------------------------------------------------------
func _play_audio(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var node_path: String = args.get("node_path", "")
	var node := root.get_node_or_null(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)

	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return _error("Not an AudioStreamPlayer: %s" % node_path)

	# Load new stream if specified
	var stream_path: String = args.get("stream", "")
	if stream_path != "":
		var stream := load(stream_path)
		if stream and stream is AudioStream:
			_set_stream(node, stream)

	# Apply settings
	if args.has("volume_db"):
		_set_volume(node, args["volume_db"])
	if args.has("pitch_scale"):
		_set_pitch(node, args["pitch_scale"])

	# Action
	var action: String = args.get("action", "play")
	match action:
		"play":
			var from_pos: float = args.get("from_position", 0.0)
			if node is AudioStreamPlayer:
				(node as AudioStreamPlayer).play(from_pos)
			elif node is AudioStreamPlayer2D:
				(node as AudioStreamPlayer2D).play(from_pos)
			elif node is AudioStreamPlayer3D:
				(node as AudioStreamPlayer3D).play(from_pos)
			return _success("Playing: %s" % node_path)
		"stop":
			if node is AudioStreamPlayer:
				(node as AudioStreamPlayer).stop()
			elif node is AudioStreamPlayer2D:
				(node as AudioStreamPlayer2D).stop()
			elif node is AudioStreamPlayer3D:
				(node as AudioStreamPlayer3D).stop()
			return _success("Stopped: %s" % node_path)
		"pause":
			node.set("stream_paused", true)
			return _success("Paused: %s" % node_path)

	return _error("Unknown action: %s" % action)


# ---------------------------------------------------------------------------
# create_audio_bus
# ---------------------------------------------------------------------------
func _create_audio_bus(args: Dictionary) -> Dictionary:
	var bus_name: String = args.get("bus_name", "")
	if bus_name == "":
		return _error("bus_name is required")

	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		# Create new bus
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, bus_name)

	# Configure
	if args.has("volume_db"):
		AudioServer.set_bus_volume_db(bus_idx, args["volume_db"])
	if args.has("solo"):
		AudioServer.set_bus_solo(bus_idx, args["solo"])
	if args.has("mute"):
		AudioServer.set_bus_mute(bus_idx, args["mute"])
	if args.has("send_to"):
		var send_idx := AudioServer.get_bus_index(args["send_to"])
		if send_idx != -1:
			AudioServer.set_bus_send(bus_idx, args["send_to"])

	# Add effect
	if args.has("add_effect"):
		var effect: AudioEffect
		match args["add_effect"]:
			"reverb":
				effect = AudioEffectReverb.new()
			"delay":
				effect = AudioEffectDelay.new()
			"distortion":
				effect = AudioEffectDistortion.new()
			"chorus":
				effect = AudioEffectChorus.new()
			"eq":
				effect = AudioEffectEQ10.new()
			"limiter":
				effect = AudioEffectLimiter.new()
			"compressor":
				effect = AudioEffectCompressor.new()
			"lowpass":
				effect = AudioEffectLowPassFilter.new()
			"highpass":
				effect = AudioEffectHighPassFilter.new()
			"bandpass":
				effect = AudioEffectBandPassFilter.new()
		if effect:
			AudioServer.add_bus_effect(bus_idx, effect)

	return _success("Bus '%s' configured (index %d)" % [bus_name, bus_idx])


# ---------------------------------------------------------------------------
# get_audio_info
# ---------------------------------------------------------------------------
func _get_audio_info(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")

	if node_path != "":
		var root := _get_edited_root()
		if root == null:
			return _error("No scene open")
		var node := root.get_node_or_null(node_path)
		if node == null:
			return _error("Node not found: %s" % node_path)

		var info := {
			"class": node.get_class(),
			"playing": false,
			"bus": "",
			"volume_db": 0.0,
			"pitch_scale": 1.0,
			"stream": "none",
		}

		if node is AudioStreamPlayer:
			var p := node as AudioStreamPlayer
			info["playing"] = p.playing
			info["bus"] = p.bus
			info["volume_db"] = p.volume_db
			info["pitch_scale"] = p.pitch_scale
			info["stream"] = p.stream.resource_path if p.stream else "none"
			info["autoplay"] = p.autoplay
		elif node is AudioStreamPlayer2D:
			var p := node as AudioStreamPlayer2D
			info["playing"] = p.playing
			info["bus"] = p.bus
			info["volume_db"] = p.volume_db
			info["pitch_scale"] = p.pitch_scale
			info["stream"] = p.stream.resource_path if p.stream else "none"
			info["autoplay"] = p.autoplay
			info["max_distance"] = p.max_distance
		elif node is AudioStreamPlayer3D:
			var p := node as AudioStreamPlayer3D
			info["playing"] = p.playing
			info["bus"] = p.bus
			info["volume_db"] = p.volume_db
			info["pitch_scale"] = p.pitch_scale
			info["stream"] = p.stream.resource_path if p.stream else "none"
			info["autoplay"] = p.autoplay
			info["max_distance"] = p.max_distance

		return _success(JSON.stringify(info, "\t"))

	# No node specified — return bus layout
	var buses := []
	for i in range(AudioServer.bus_count):
		var bus := {
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"mute": AudioServer.is_bus_mute(i),
			"solo": AudioServer.is_bus_solo(i),
			"send": AudioServer.get_bus_send(i),
			"effect_count": AudioServer.get_bus_effect_count(i),
		}
		var effects: Array = []
		for j in range(AudioServer.get_bus_effect_count(i)):
			effects.append(AudioServer.get_bus_effect(i, j).get_class())
		bus["effects"] = effects
		buses.append(bus)

	return _success(JSON.stringify({"bus_count": AudioServer.bus_count, "buses": buses}, "\t"))


# ---------------------------------------------------------------------------
# create_sfx_pool
# ---------------------------------------------------------------------------
func _create_sfx_pool(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var parent_path: String = args.get("parent_path", ".")
	var parent := root.get_node_or_null(parent_path) if parent_path != "." else root
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var pool_name: String = args.get("name", "SFXPool")
	var pool_size: int = args.get("pool_size", 4)
	var player_type: String = args.get("type", "2d")
	var stream_path: String = args.get("stream", "")
	var bus_name: String = args.get("bus", "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")
	var volume: float = args.get("volume_db", 0.0)

	# Create container
	var container := Node2D.new()
	container.name = pool_name

	var undo := plugin.get_undo_redo()
	undo.create_action("Create SFX pool: %s" % pool_name)
	undo.add_do_method(parent, "add_child", container)
	undo.add_do_method(container, "set_owner", root)
	undo.add_do_reference(container)
	undo.add_undo_method(parent, "remove_child", container)

	# Load stream
	var stream: AudioStream
	if stream_path != "":
		var loaded := load(stream_path)
		if loaded and loaded is AudioStream:
			stream = loaded

	# Create pool players
	for i in range(pool_size):
		var player: Node
		if player_type == "2d":
			player = AudioStreamPlayer2D.new()
		else:
			player = AudioStreamPlayer.new()

		player.name = "Player%d" % (i + 1)
		if stream:
			_set_stream(player, stream)
		_set_bus(player, bus_name)
		_set_volume(player, volume)

		undo.add_do_method(container, "add_child", player)
		undo.add_do_method(player, "set_owner", root)
		undo.add_do_reference(player)

	undo.commit_action()

	return _success("Created SFX pool '%s' with %d %s players (bus: %s)" % [pool_name, pool_size, player_type, bus_name])


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _get_edited_root() -> Node:
	var ei := EditorInterface
	if ei:
		return ei.get_edited_scene_root()
	return null


func _set_stream(node: Node, stream: AudioStream) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).stream = stream
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).stream = stream
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).stream = stream


func _set_bus(node: Node, bus_name: String) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).bus = bus_name
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).bus = bus_name
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).bus = bus_name


func _set_volume(node: Node, db: float) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).volume_db = db
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).volume_db = db
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).volume_db = db


func _set_pitch(node: Node, scale: float) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).pitch_scale = scale
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).pitch_scale = scale
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).pitch_scale = scale


func _set_autoplay(node: Node, autoplay: bool) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).autoplay = autoplay
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).autoplay = autoplay
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).autoplay = autoplay
