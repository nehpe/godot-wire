@tool
extends GodotWireTool
## Project-level tools: info, composite operations, templates.

func get_tools() -> Array:
	return [
		{
			"name": "get_project_info",
			"description": "Get comprehensive project state in one call: scene, autoloads, input actions, game status, editor info",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		},
		{
			"name": "create_scene_from_template",
			"description": "Create a complete scene from a template (character, projectile, area_trigger, ui_panel) with collision, sprite, and script attached",
			"inputSchema": {
				"type": "object",
				"properties": {
					"template": {
						"type": "string",
						"description": "Template name: character_2d, projectile_2d, area_trigger_2d, static_body_2d, ui_panel",
						"enum": ["character_2d", "projectile_2d", "area_trigger_2d", "static_body_2d", "ui_panel"]
					},
					"name": {
						"type": "string",
						"description": "Root node name (e.g., 'Player', 'Bullet', 'Enemy')"
					},
					"save_path": {
						"type": "string",
						"description": "Path to save the scene (e.g., 'res://scenes/player.tscn')"
					},
					"script_path": {
						"type": "string",
						"description": "Optional: path to an existing script to attach"
					},
					"collision_shape": {
						"type": "string",
						"description": "Collision shape type: circle, capsule, rectangle. Default: capsule",
						"enum": ["circle", "capsule", "rectangle"]
					},
					"collision_radius": {
						"type": "number",
						"description": "Collision shape radius. Default: 16"
					},
					"collision_size": {
						"type": "array",
						"description": "Collision shape size [width, height] for rectangle. Default: [32, 32]",
						"items": {"type": "number"}
					},
					"collision_layer": {
						"type": "integer",
						"description": "Physics collision layer bitmask"
					},
					"collision_mask": {
						"type": "integer",
						"description": "Physics collision mask bitmask"
					}
				},
				"required": ["template", "name", "save_path"]
			}
		},
		{
			"name": "batch_create_nodes",
			"description": "Create multiple nodes in the scene tree in a single call",
			"inputSchema": {
				"type": "object",
				"properties": {
					"nodes": {
						"type": "array",
						"description": "Array of node definitions",
						"items": {
							"type": "object",
							"properties": {
								"name": {"type": "string", "description": "Node name"},
								"type": {"type": "string", "description": "Node class (e.g., 'CharacterBody2D')"},
								"parent": {"type": "string", "description": "Parent node path (default: scene root)"},
								"properties": {"type": "object", "description": "Properties to set on the node"}
							},
							"required": ["name", "type"]
						}
					}
				},
				"required": ["nodes"]
			}
		},
		{
			"name": "get_input_actions",
			"description": "List all input actions defined in the project with their bindings",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"get_project_info":
			return _get_project_info()
		"create_scene_from_template":
			return _create_scene_from_template(args)
		"batch_create_nodes":
			return _batch_create_nodes(args)
		"get_input_actions":
			return _get_input_actions()
	return _error("Unknown tool: %s" % tool_name)

# --- get_project_info ---

func _get_project_info() -> Dictionary:
	var info := {}

	# Project basics
	info["project_name"] = ProjectSettings.get_setting("application/config/name", "Untitled")
	info["godot_version"] = Engine.get_version_info().string
	info["renderer"] = ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")

	# Current scene
	var root := EditorInterface.get_edited_scene_root()
	if root:
		info["current_scene"] = {
			"path": root.scene_file_path if root.scene_file_path else "unsaved",
			"root_name": root.name,
			"root_type": root.get_class(),
			"node_count": _count_nodes(root)
		}
	else:
		info["current_scene"] = null

	# Autoloads
	var autoloads := {}
	for key in ProjectSettings.get_property_list():
		var name: String = key.name
		if name.begins_with("autoload/"):
			autoloads[name.replace("autoload/", "")] = ProjectSettings.get_setting(name)
	info["autoloads"] = autoloads

	# Game running state
	info["game_running"] = game_bridge.is_game_connected() if game_bridge else false

	# Viewport
	info["viewport_size"] = {
		"width": ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		"height": ProjectSettings.get_setting("display/window/size/viewport_height", 648)
	}

	# Main scene
	info["main_scene"] = ProjectSettings.get_setting("application/run/main_scene", "")

	return _success(JSON.stringify(info, "\t"))

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

# --- create_scene_from_template ---

func _create_scene_from_template(args: Dictionary) -> Dictionary:
	var template: String = args.get("template", "")
	var node_name: String = args.get("name", "Node")
	var save_path: String = args.get("save_path", "")
	var script_path: String = args.get("script_path", "")
	var col_shape: String = args.get("collision_shape", "capsule")
	var col_radius: float = args.get("collision_radius", 16.0)
	var col_size: Array = args.get("collision_size", [32.0, 32.0])
	var col_layer: int = args.get("collision_layer", -1)
	var col_mask: int = args.get("collision_mask", -1)

	if save_path.is_empty():
		return _error("save_path is required")

	var root: Node
	match template:
		"character_2d":
			root = _template_character_2d(node_name, col_shape, col_radius, col_size)
		"projectile_2d":
			root = _template_projectile_2d(node_name, col_shape, col_radius)
		"area_trigger_2d":
			root = _template_area_trigger_2d(node_name, col_shape, col_radius, col_size)
		"static_body_2d":
			root = _template_static_body_2d(node_name, col_shape, col_radius, col_size)
		"ui_panel":
			root = _template_ui_panel(node_name)
		_:
			return _error("Unknown template: %s" % template)

	# Set collision layers if specified
	if col_layer >= 0 and root.has_method("set"):
		root.set("collision_layer", col_layer)
	if col_mask >= 0 and root.has_method("set"):
		root.set("collision_mask", col_mask)

	# Attach script
	if not script_path.is_empty():
		var script := ResourceLoader.load(script_path)
		if script:
			root.set_script(script)

	# Save as PackedScene
	var scene := PackedScene.new()
	scene.pack(root)
	var err := ResourceSaver.save(scene, save_path)
	root.queue_free()
	if err != OK:
		return _error("Failed to save scene: %s" % error_string(err))

	return _success("Created %s scene '%s' at %s" % [template, node_name, save_path])

func _make_collision_shape(col_shape: String, radius: float, size: Array) -> CollisionShape2D:
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	match col_shape:
		"circle":
			var shape := CircleShape2D.new()
			shape.radius = radius
			col.shape = shape
		"capsule":
			var shape := CapsuleShape2D.new()
			shape.radius = radius
			shape.height = radius * 2.5
			col.shape = shape
		"rectangle":
			var shape := RectangleShape2D.new()
			shape.size = Vector2(size[0] if size.size() > 0 else 32.0, size[1] if size.size() > 1 else 32.0)
			col.shape = shape
	return col

func _template_character_2d(node_name: String, col_shape: String, radius: float, size: Array) -> CharacterBody2D:
	var root := CharacterBody2D.new()
	root.name = node_name
	var col := _make_collision_shape(col_shape, radius, size)
	root.add_child(col)
	col.owner = root
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	root.add_child(sprite)
	sprite.owner = root
	# Hitbox Area2D for overlap detection
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	var hcol := _make_collision_shape(col_shape, radius * 1.1, size)
	hitbox.add_child(hcol)
	hcol.owner = root
	root.add_child(hitbox)
	hitbox.owner = root
	return root

func _template_projectile_2d(node_name: String, col_shape: String, radius: float) -> Area2D:
	var root := Area2D.new()
	root.name = node_name
	var col := _make_collision_shape(col_shape, radius, [])
	root.add_child(col)
	col.owner = root
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	root.add_child(sprite)
	sprite.owner = root
	return root

func _template_area_trigger_2d(node_name: String, col_shape: String, radius: float, size: Array) -> Area2D:
	var root := Area2D.new()
	root.name = node_name
	root.monitoring = true
	var col := _make_collision_shape(col_shape, radius, size)
	root.add_child(col)
	col.owner = root
	return root

func _template_static_body_2d(node_name: String, col_shape: String, radius: float, size: Array) -> StaticBody2D:
	var root := StaticBody2D.new()
	root.name = node_name
	var col := _make_collision_shape(col_shape, radius, size)
	root.add_child(col)
	col.owner = root
	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.size = Vector2(size[0] if size.size() > 0 else 32.0, size[1] if size.size() > 1 else 32.0)
	visual.position = -visual.size / 2
	root.add_child(visual)
	visual.owner = root
	return root

func _template_ui_panel(node_name: String) -> PanelContainer:
	var root := PanelContainer.new()
	root.name = node_name
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	root.add_child(vbox)
	vbox.owner = root
	var title := Label.new()
	title.name = "Title"
	title.text = node_name
	vbox.add_child(title)
	title.owner = root
	return root

# --- batch_create_nodes ---

func _batch_create_nodes(args: Dictionary) -> Dictionary:
	var nodes: Array = args.get("nodes", [])
	if nodes.is_empty():
		return _error("No nodes specified")

	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error("No scene open in editor")

	var undo := plugin.get_undo_redo()
	undo.create_action("Batch create %d nodes" % nodes.size())

	var created := 0
	var errors: Array = []
	for entry in nodes:
		var node_name: String = entry.get("name", "")
		var type: String = entry.get("type", "")
		var parent_path: String = entry.get("parent", "")
		var properties: Dictionary = entry.get("properties", {})

		if node_name.is_empty() or type.is_empty():
			errors.append("Missing name or type in entry")
			continue

		var parent: Node = root
		if not parent_path.is_empty():
			parent = root.get_node_or_null(NodePath(parent_path))
			if parent == null:
				errors.append("Parent not found: %s" % parent_path)
				continue

		var node := ClassDB.instantiate(type)
		if node == null:
			errors.append("Unknown type: %s" % type)
			continue

		node.name = node_name
		for key in properties:
			node.set(key, properties[key])

		undo.add_do_method(parent, "add_child", node)
		undo.add_do_method(node, "set_owner", root)
		undo.add_do_reference(node)
		undo.add_undo_method(parent, "remove_child", node)
		created += 1

	undo.commit_action()

	var result := "Created %d nodes" % created
	if errors.size() > 0:
		result += " (%d errors: %s)" % [errors.size(), ", ".join(errors)]
	return _success(result)

# --- get_input_actions ---

func _get_input_actions() -> Dictionary:
	var actions := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop.name
		if not name.begins_with("input/"):
			continue
		var action_name := name.replace("input/", "")
		var setting = ProjectSettings.get_setting(name)
		if setting is Dictionary:
			var events: Array = []
			for event in setting.get("events", []):
				if event is InputEventKey:
					events.append("Key: %s" % OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode))
				elif event is InputEventMouseButton:
					events.append("Mouse: button %d" % event.button_index)
				elif event is InputEventJoypadButton:
					events.append("Joypad: button %d" % event.button_index)
				elif event is InputEventJoypadMotion:
					events.append("Joypad: axis %d" % event.axis)
				else:
					events.append(event.get_class())
			actions[action_name] = events
	return _success(JSON.stringify(actions, "\t"))
