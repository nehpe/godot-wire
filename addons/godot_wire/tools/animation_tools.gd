@tool
extends GodotWireTool
## Animation tools: create AnimationPlayer, manage animations, tracks, and keyframes.

func get_tools() -> Array:
	return [
		{
			"name": "create_animation_player",
			"description": "Add an AnimationPlayer node to a parent, optionally with a starter animation",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent": {"type": "string", "description": "Parent node path"},
					"name": {"type": "string", "description": "AnimationPlayer node name. Default: 'AnimationPlayer'"},
					"animation_name": {"type": "string", "description": "Optional: create an initial empty animation with this name"},
					"length": {"type": "number", "description": "Animation length in seconds. Default: 1.0"},
					"loop": {"type": "boolean", "description": "Whether the animation loops. Default: false"}
				},
				"required": ["parent"]
			}
		},
		{
			"name": "create_animation",
			"description": "Create a new animation on an existing AnimationPlayer",
			"inputSchema": {
				"type": "object",
				"properties": {
					"player_path": {"type": "string", "description": "Path to the AnimationPlayer node"},
					"animation_name": {"type": "string", "description": "Name for the new animation"},
					"length": {"type": "number", "description": "Animation length in seconds. Default: 1.0"},
					"loop": {"type": "boolean", "description": "Loop mode: false=none, true=linear. Default: false"},
					"step": {"type": "number", "description": "Time step for snapping. Default: 0.1"}
				},
				"required": ["player_path", "animation_name"]
			}
		},
		{
			"name": "add_animation_track",
			"description": "Add a track to an animation (property, method, bezier, audio, or animation)",
			"inputSchema": {
				"type": "object",
				"properties": {
					"player_path": {"type": "string", "description": "Path to the AnimationPlayer node"},
					"animation_name": {"type": "string", "description": "Animation to add the track to"},
					"track_type": {
						"type": "string",
						"description": "Track type: property, method, bezier, audio, animation",
						"enum": ["property", "method", "bezier", "audio", "animation"]
					},
					"node_path": {"type": "string", "description": "Path to the target node (relative to AnimationPlayer root)"},
					"property": {"type": "string", "description": "Property name for property/bezier tracks (e.g., 'position', 'modulate')"},
					"keyframes": {
						"type": "array",
						"description": "Array of keyframes: [{time, value}] for property tracks, [{time, method, args}] for method tracks",
						"items": {"type": "object"}
					}
				},
				"required": ["player_path", "animation_name", "track_type", "node_path"]
			}
		},
		{
			"name": "add_keyframe",
			"description": "Add or update a keyframe on an existing track",
			"inputSchema": {
				"type": "object",
				"properties": {
					"player_path": {"type": "string", "description": "Path to the AnimationPlayer node"},
					"animation_name": {"type": "string", "description": "Animation name"},
					"track_index": {"type": "integer", "description": "Track index (0-based)"},
					"time": {"type": "number", "description": "Keyframe time in seconds"},
					"value": {"description": "Keyframe value (type depends on track property)"},
					"transition": {"type": "number", "description": "Transition curve. 1.0=linear, <1=ease-in, >1=ease-out. Default: 1.0"}
				},
				"required": ["player_path", "animation_name", "track_index", "time", "value"]
			}
		},
		{
			"name": "get_animation_info",
			"description": "Get detailed info about an AnimationPlayer: list of animations, tracks, keyframes",
			"inputSchema": {
				"type": "object",
				"properties": {
					"player_path": {"type": "string", "description": "Path to the AnimationPlayer node"},
					"animation_name": {"type": "string", "description": "Optional: get details for a specific animation"}
				},
				"required": ["player_path"]
			}
		},
		{
			"name": "play_animation",
			"description": "Play, stop, or seek an animation in the editor (preview mode)",
			"inputSchema": {
				"type": "object",
				"properties": {
					"player_path": {"type": "string", "description": "Path to the AnimationPlayer node"},
					"animation_name": {"type": "string", "description": "Animation to play"},
					"action": {
						"type": "string",
						"description": "Action: play, stop, seek",
						"enum": ["play", "stop", "seek"]
					},
					"position": {"type": "number", "description": "Seek position in seconds (for seek action)"}
				},
				"required": ["player_path", "action"]
			}
		},
		{
			"name": "create_path2d",
			"description": "Create a Path2D with a Curve2D and optional PathFollow2D child",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent": {"type": "string", "description": "Parent node path"},
					"name": {"type": "string", "description": "Path2D node name. Default: 'Path2D'"},
					"points": {
						"type": "array",
						"description": "Array of [x, y] points for the curve",
						"items": {"type": "array", "items": {"type": "number"}}
					},
					"add_follower": {"type": "boolean", "description": "Add a PathFollow2D child. Default: true"},
					"follower_name": {"type": "string", "description": "PathFollow2D name. Default: 'PathFollow2D'"},
					"closed": {"type": "boolean", "description": "Whether the curve is closed (loops). Default: false"}
				},
				"required": ["parent", "points"]
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"create_animation_player":
			return _create_animation_player(args)
		"create_animation":
			return _create_animation(args)
		"add_animation_track":
			return _add_animation_track(args)
		"add_keyframe":
			return _add_keyframe(args)
		"get_animation_info":
			return _get_animation_info(args)
		"play_animation":
			return _play_animation(args)
		"create_path2d":
			return _create_path2d(args)
	return _error("Unknown tool: %s" % tool_name)

# --- create_animation_player ---

func _create_animation_player(args: Dictionary) -> Dictionary:
	var parent_path: String = args.get("parent", "")
	var node_name: String = args.get("name", "AnimationPlayer")
	var anim_name: String = args.get("animation_name", "")
	var length: float = args.get("length", 1.0)
	var loop: bool = args.get("loop", false)

	var parent := _resolve_node(parent_path)
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var root := _get_edited_scene_root()
	var player := AnimationPlayer.new()
	player.name = node_name

	var undo := plugin.get_undo_redo()
	undo.create_action("Create AnimationPlayer")
	undo.add_do_method(parent, "add_child", player)
	undo.add_do_method(self, "_set_owner_recursive", player, root)
	undo.add_do_reference(player)
	undo.add_undo_method(parent, "remove_child", player)
	undo.commit_action()

	# Add initial animation if requested
	if not anim_name.is_empty():
		var lib := player.get_animation_library("")
		if lib == null:
			lib = AnimationLibrary.new()
			player.add_animation_library("", lib)
		var anim := Animation.new()
		anim.length = length
		if loop:
			anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(anim_name, anim)

	var result := "Created AnimationPlayer '%s' under %s" % [node_name, parent.name]
	if not anim_name.is_empty():
		result += " with animation '%s' (%.1fs)" % [anim_name, length]
	return _success(result)

# --- create_animation ---

func _create_animation(args: Dictionary) -> Dictionary:
	var player_path: String = args.get("player_path", "")
	var anim_name: String = args.get("animation_name", "")
	var length: float = args.get("length", 1.0)
	var loop: bool = args.get("loop", false)
	var step: float = args.get("step", 0.1)

	var player := _resolve_node(player_path)
	if player == null or not player is AnimationPlayer:
		return _error("AnimationPlayer not found: %s" % player_path)

	var ap := player as AnimationPlayer
	var lib := ap.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)

	var anim := Animation.new()
	anim.length = length
	anim.step = step
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR

	lib.add_animation(anim_name, anim)
	return _success("Created animation '%s' (%.1fs, loop=%s)" % [anim_name, length, str(loop)])

# --- add_animation_track ---

func _add_animation_track(args: Dictionary) -> Dictionary:
	var player_path: String = args.get("player_path", "")
	var anim_name: String = args.get("animation_name", "")
	var track_type_str: String = args.get("track_type", "property")
	var node_path: String = args.get("node_path", "")
	var property: String = args.get("property", "")
	var keyframes: Array = args.get("keyframes", [])

	var player := _resolve_node(player_path)
	if player == null or not player is AnimationPlayer:
		return _error("AnimationPlayer not found: %s" % player_path)

	var ap := player as AnimationPlayer
	if not ap.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim := ap.get_animation(anim_name)

	# Determine track type
	var track_type: int
	match track_type_str:
		"property":
			track_type = Animation.TYPE_VALUE
		"method":
			track_type = Animation.TYPE_METHOD
		"bezier":
			track_type = Animation.TYPE_BEZIER
		"audio":
			track_type = Animation.TYPE_AUDIO
		"animation":
			track_type = Animation.TYPE_ANIMATION
		_:
			return _error("Unknown track type: %s" % track_type_str)

	# Build track path
	var track_path: String
	if property.is_empty():
		track_path = node_path
	else:
		track_path = node_path + ":" + property

	var idx := anim.add_track(track_type)
	anim.track_set_path(idx, NodePath(track_path))

	# Insert keyframes if provided
	var kf_count := 0
	for kf in keyframes:
		var time: float = kf.get("time", 0.0)
		if track_type == Animation.TYPE_VALUE:
			var value = _convert_anim_value(kf.get("value"))
			anim.track_insert_key(idx, time, value)
			var transition: float = kf.get("transition", 1.0)
			if transition != 1.0:
				anim.track_set_key_transition(idx, kf_count, transition)
		elif track_type == Animation.TYPE_METHOD:
			var method: String = kf.get("method", "")
			var method_args: Array = kf.get("args", [])
			anim.track_insert_key(idx, time, {"method": method, "args": method_args})
		elif track_type == Animation.TYPE_BEZIER:
			var value: float = kf.get("value", 0.0)
			anim.bezier_track_insert_key(idx, time, value)
		kf_count += 1

	return _success("Added %s track [%d] for '%s' with %d keyframes" % [track_type_str, idx, track_path, kf_count])

# --- add_keyframe ---

func _add_keyframe(args: Dictionary) -> Dictionary:
	var player_path: String = args.get("player_path", "")
	var anim_name: String = args.get("animation_name", "")
	var track_idx: int = args.get("track_index", 0)
	var time: float = args.get("time", 0.0)
	var value = args.get("value")
	var transition: float = args.get("transition", 1.0)

	var player := _resolve_node(player_path)
	if player == null or not player is AnimationPlayer:
		return _error("AnimationPlayer not found: %s" % player_path)

	var ap := player as AnimationPlayer
	if not ap.has_animation(anim_name):
		return _error("Animation not found: %s" % anim_name)
	var anim := ap.get_animation(anim_name)

	if track_idx < 0 or track_idx >= anim.get_track_count():
		return _error("Track index %d out of range (0-%d)" % [track_idx, anim.get_track_count() - 1])

	var converted = _convert_anim_value(value)
	var key_idx := anim.track_insert_key(track_idx, time, converted)
	if transition != 1.0:
		anim.track_set_key_transition(track_idx, key_idx, transition)

	return _success("Added keyframe at %.2fs on track %d" % [time, track_idx])

# --- get_animation_info ---

func _get_animation_info(args: Dictionary) -> Dictionary:
	var player_path: String = args.get("player_path", "")
	var anim_name: String = args.get("animation_name", "")

	var player := _resolve_node(player_path)
	if player == null or not player is AnimationPlayer:
		return _error("AnimationPlayer not found: %s" % player_path)

	var ap := player as AnimationPlayer
	var info := {}

	if anim_name.is_empty():
		# List all animations
		var anims: Array = []
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for name in lib.get_animation_list():
				var anim := lib.get_animation(name)
				var full_name: String = (lib_name + "/" + name) if not lib_name.is_empty() else name
				anims.append({
					"name": full_name,
					"length": anim.length,
					"loop": anim.loop_mode != Animation.LOOP_NONE,
					"tracks": anim.get_track_count()
				})
		info["animations"] = anims
		info["count"] = anims.size()
	else:
		# Detail for specific animation
		if not ap.has_animation(anim_name):
			return _error("Animation not found: %s" % anim_name)
		var anim := ap.get_animation(anim_name)
		info["name"] = anim_name
		info["length"] = anim.length
		info["loop"] = anim.loop_mode != Animation.LOOP_NONE
		info["step"] = anim.step

		var tracks: Array = []
		for i in range(anim.get_track_count()):
			var track_info := {
				"index": i,
				"path": str(anim.track_get_path(i)),
				"type": _track_type_name(anim.track_get_type(i)),
				"key_count": anim.track_get_key_count(i),
			}
			# Include keyframe times
			var keys: Array = []
			for k in range(anim.track_get_key_count(i)):
				var key_data := {"time": anim.track_get_key_time(i, k)}
				if anim.track_get_type(i) == Animation.TYPE_VALUE:
					key_data["value"] = str(anim.track_get_key_value(i, k))
				keys.append(key_data)
			track_info["keys"] = keys
			tracks.append(track_info)
		info["tracks"] = tracks

	return _success(JSON.stringify(info, "\t"))

# --- play_animation ---

func _play_animation(args: Dictionary) -> Dictionary:
	var player_path: String = args.get("player_path", "")
	var anim_name: String = args.get("animation_name", "")
	var action: String = args.get("action", "play")
	var seek_pos: float = args.get("position", 0.0)

	var player := _resolve_node(player_path)
	if player == null or not player is AnimationPlayer:
		return _error("AnimationPlayer not found: %s" % player_path)

	var ap := player as AnimationPlayer

	match action:
		"play":
			if anim_name.is_empty():
				return _error("animation_name required for play")
			ap.play(anim_name)
			return _success("Playing '%s'" % anim_name)
		"stop":
			ap.stop()
			return _success("Stopped animation")
		"seek":
			ap.seek(seek_pos)
			return _success("Seeked to %.2fs" % seek_pos)
		_:
			return _error("Unknown action: %s" % action)

# --- create_path2d ---

func _create_path2d(args: Dictionary) -> Dictionary:
	var parent_path: String = args.get("parent", "")
	var node_name: String = args.get("name", "Path2D")
	var points: Array = args.get("points", [])
	var add_follower: bool = args.get("add_follower", true)
	var follower_name: String = args.get("follower_name", "PathFollow2D")
	var closed: bool = args.get("closed", false)

	var parent := _resolve_node(parent_path)
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var root := _get_edited_scene_root()

	var path := Path2D.new()
	path.name = node_name
	var curve := Curve2D.new()
	for pt in points:
		if pt is Array and pt.size() >= 2:
			curve.add_point(Vector2(pt[0], pt[1]))
	if closed and curve.point_count >= 3:
		curve.add_point(curve.get_point_position(0))
	path.curve = curve

	var undo := plugin.get_undo_redo()
	undo.create_action("Create Path2D '%s'" % node_name)
	undo.add_do_method(parent, "add_child", path)
	undo.add_do_method(self, "_set_owner_recursive", path, root)
	undo.add_do_reference(path)
	undo.add_undo_method(parent, "remove_child", path)
	undo.commit_action()

	if add_follower:
		var follow := PathFollow2D.new()
		follow.name = follower_name
		follow.rotates = false
		path.add_child(follow)
		follow.owner = root

	return _success("Created Path2D '%s' with %d points%s%s" % [
		node_name, curve.point_count,
		" (closed)" if closed else "",
		" + %s" % follower_name if add_follower else ""
	])

# --- Helpers ---

func _track_type_name(t: int) -> String:
	match t:
		Animation.TYPE_VALUE: return "property"
		Animation.TYPE_METHOD: return "method"
		Animation.TYPE_BEZIER: return "bezier"
		Animation.TYPE_AUDIO: return "audio"
		Animation.TYPE_ANIMATION: return "animation"
	return "unknown(%d)" % t

func _convert_anim_value(value):
	if value is Array:
		match value.size():
			2: return Vector2(value[0], value[1])
			3: return Vector3(value[0], value[1], value[2])
			4:
				# Could be Color or Vector4 — assume Color if values 0-1
				if value[0] is float and value[0] <= 1.0 and value[1] <= 1.0:
					return Color(value[0], value[1], value[2], value[3])
				return Vector4(value[0], value[1], value[2], value[3])
	if value is String and value.begins_with("#"):
		return Color.html(value)
	return value
