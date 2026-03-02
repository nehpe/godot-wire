extends GodotWireTool
## Scene tree inspection and node management tools.

func get_tools() -> Array:
	return [
		{
			"name": "get_scene_tree",
			"description": "Get the complete scene tree hierarchy of the currently edited scene",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		},
		{
			"name": "find_nodes",
			"description": "Find nodes by name pattern, type, or group in the scene tree",
			"inputSchema": {
				"type": "object",
				"properties": {
					"name_pattern": {"type": "string", "description": "Name pattern to match (supports * wildcards)"},
					"type": {"type": "string", "description": "Node type to filter by (e.g. MeshInstance3D, CharacterBody3D)"},
					"group": {"type": "string", "description": "Group name to filter by"}
				},
				"required": []
			}
		},
		{
			"name": "create_node",
			"description": "Create a new node in the scene tree",
			"inputSchema": {
				"type": "object",
				"properties": {
					"name": {"type": "string", "description": "Name for the new node"},
					"type": {"type": "string", "description": "Node type (e.g. Node3D, MeshInstance3D, CharacterBody3D)"},
					"parent": {"type": "string", "description": "Path to parent node (default: scene root)"}
				},
				"required": ["name", "type"]
			}
		},
		{
			"name": "delete_node",
			"description": "Delete a node from the scene tree",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node to delete"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "duplicate_node",
			"description": "Duplicate a node in the scene tree",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node to duplicate"},
					"new_name": {"type": "string", "description": "Name for the duplicated node"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "reparent_node",
			"description": "Move a node to a new parent in the scene tree",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node to move"},
					"new_parent": {"type": "string", "description": "Path to the new parent node"}
				},
				"required": ["path", "new_parent"]
			}
		},
		{
			"name": "instantiate_scene",
			"description": "Instantiate a .tscn or .glb scene file as a child node",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene_path": {"type": "string", "description": "Resource path (e.g. res://scenes/player.tscn)"},
					"parent": {"type": "string", "description": "Path to parent node (default: scene root)"},
					"name": {"type": "string", "description": "Name for the instantiated node"}
				},
				"required": ["scene_path"]
			}
		},
		{
			"name": "get_node_info",
			"description": "Get detailed info about a specific node (type, properties, children, signals)",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "get_node_children",
			"description": "Get the direct children of a node",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "get_node_methods",
			"description": "List all methods available on a node",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node"},
					"filter": {"type": "string", "description": "Filter methods by name substring"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "get_node_signals",
			"description": "List all signals available on a node",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the node"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "attach_script",
			"description": "Attach an existing script to a node",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to the node"},
					"script_path": {"type": "string", "description": "Resource path to the .gd script"}
				},
				"required": ["node_path", "script_path"]
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"get_scene_tree":
			return _get_scene_tree()
		"find_nodes":
			return _find_nodes(args)
		"create_node":
			return _create_node(args)
		"delete_node":
			return _delete_node(args)
		"duplicate_node":
			return _duplicate_node(args)
		"reparent_node":
			return _reparent_node(args)
		"instantiate_scene":
			return _instantiate_scene(args)
		"get_node_info":
			return _get_node_info(args)
		"get_node_children":
			return _get_node_children(args)
		"get_node_methods":
			return _get_node_methods(args)
		"get_node_signals":
			return _get_node_signals(args)
		"attach_script":
			return _attach_script(args)
		_:
			return _error("Unknown tool: %s" % tool_name)

# --- Implementations ---

func _get_scene_tree() -> Dictionary:
	var root := _get_edited_scene_root()
	if root == null:
		return _error("No scene is currently open")
	var tree := _build_tree(root, 0)
	return _success(tree)

func _build_tree(node: Node, depth: int) -> String:
	var indent := "  ".repeat(depth)
	var line := "%s%s [%s]" % [indent, node.name, node.get_class()]
	var lines: Array = [line]
	for child in node.get_children():
		lines.append(_build_tree(child, depth + 1))
	return "\n".join(lines)

func _find_nodes(args: Dictionary) -> Dictionary:
	var root := _get_edited_scene_root()
	if root == null:
		return _error("No scene is currently open")
	var name_pattern: String = args.get("name_pattern", "")
	var type_filter: String = args.get("type", "")
	var group_filter: String = args.get("group", "")
	var matches: Array = []
	_search_nodes(root, name_pattern, type_filter, group_filter, matches)
	if matches.is_empty():
		return _success("No nodes found matching the criteria")
	var text := "Found %d node(s):\n" % matches.size()
	for m in matches:
		text += "  %s [%s] @ %s\n" % [m.name, m.type, m.path]
	return _success(text)

func _search_nodes(node: Node, name_pattern: String, type_filter: String, group_filter: String, results: Array) -> void:
	var match_name := name_pattern.is_empty() or node.name.matchn(name_pattern)
	var match_type := type_filter.is_empty() or node.is_class(type_filter)
	var match_group := group_filter.is_empty() or node.is_in_group(group_filter)
	if match_name and match_type and match_group:
		var root := _get_edited_scene_root()
		results.append({
			"name": str(node.name),
			"type": node.get_class(),
			"path": str(root.get_path_to(node))
		})
	for child in node.get_children():
		_search_nodes(child, name_pattern, type_filter, group_filter, results)

func _create_node(args: Dictionary) -> Dictionary:
	var root := _get_edited_scene_root()
	if root == null:
		return _error("No scene is currently open")
	var node_name: String = args.get("name", "NewNode")
	var node_type: String = args.get("type", "Node")
	var parent_path: String = args.get("parent", "")
	var parent := root if parent_path.is_empty() else _resolve_node(parent_path)
	if parent == null:
		return _error("Parent node not found: %s" % parent_path)
	var node: Node = ClassDB.instantiate(node_type)
	if node == null:
		return _error("Invalid node type: %s" % node_type)
	node.name = node_name
	parent.add_child(node)
	_set_owner_recursive(node, root)
	return _success("Created %s [%s] under %s" % [node_name, node_type, parent.name])

func _delete_node(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var root := _get_edited_scene_root()
	if node == root:
		return _error("Cannot delete the scene root")
	var node_name := str(node.name)
	node.get_parent().remove_child(node)
	node.queue_free()
	return _success("Deleted node: %s" % node_name)

func _duplicate_node(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var dup := node.duplicate()
	var new_name: String = args.get("new_name", str(node.name) + "_copy")
	dup.name = new_name
	node.get_parent().add_child(dup)
	var root := _get_edited_scene_root()
	_set_owner_recursive(dup, root)
	return _success("Duplicated %s as %s" % [node.name, new_name])

func _reparent_node(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var new_parent_path: String = args.get("new_parent", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var new_parent := _resolve_node(new_parent_path)
	if new_parent == null:
		return _error("New parent not found: %s" % new_parent_path)
	var old_parent := node.get_parent()
	old_parent.remove_child(node)
	new_parent.add_child(node)
	var root := _get_edited_scene_root()
	_set_owner_recursive(node, root)
	return _success("Moved %s from %s to %s" % [node.name, old_parent.name, new_parent.name])

func _instantiate_scene(args: Dictionary) -> Dictionary:
	var scene_path: String = args.get("scene_path", "")
	var parent_path: String = args.get("parent", "")
	var node_name: String = args.get("name", "")
	var root := _get_edited_scene_root()
	if root == null:
		return _error("No scene is currently open")
	var parent := root if parent_path.is_empty() else _resolve_node(parent_path)
	if parent == null:
		return _error("Parent node not found: %s" % parent_path)
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return _error("Could not load scene: %s" % scene_path)
	var instance: Node = scene.instantiate()
	if not node_name.is_empty():
		instance.name = node_name
	parent.add_child(instance)
	_set_owner_recursive(instance, root)
	return _success("Instantiated %s as %s under %s" % [scene_path, instance.name, parent.name])

func _get_node_info(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var info := "Node: %s\nType: %s\nClass: %s\n" % [node.name, node.get_class(), node.get_class()]
	var root := _get_edited_scene_root()
	info += "Path: %s\n" % str(root.get_path_to(node))
	info += "Children: %d\n" % node.get_child_count()
	if node.get_child_count() > 0:
		info += "  " + ", ".join(node.get_children().map(func(c): return str(c.name)))
		info += "\n"
	var groups := node.get_groups()
	if groups.size() > 0:
		info += "Groups: %s\n" % ", ".join(groups)
	# Key properties
	info += "\nProperties:\n"
	var props := node.get_property_list()
	for prop in props:
		if prop.usage & PROPERTY_USAGE_EDITOR:
			var val = node.get(prop.name)
			if val != null:
				info += "  %s = %s\n" % [prop.name, str(val)]
	return _success(info)

func _get_node_children(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if node.get_child_count() == 0:
		return _success("%s has no children" % node.name)
	var lines: Array = ["%s has %d child(ren):" % [node.name, node.get_child_count()]]
	for child in node.get_children():
		lines.append("  %s [%s]" % [child.name, child.get_class()])
	return _success("\n".join(lines))

func _get_node_methods(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var filter_str: String = args.get("filter", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var methods := node.get_method_list()
	var lines: Array = []
	for m in methods:
		var name: String = m.name
		if not filter_str.is_empty() and name.findn(filter_str) == -1:
			continue
		var arg_names: Array = []
		for arg in m.args:
			arg_names.append(arg.name)
		lines.append("  %s(%s)" % [name, ", ".join(arg_names)])
	lines.sort()
	return _success("Methods on %s (%d):\n%s" % [node.name, lines.size(), "\n".join(lines)])

func _get_node_signals(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var signals := node.get_signal_list()
	var lines: Array = []
	for sig in signals:
		var arg_names: Array = []
		for arg in sig.args:
			arg_names.append(arg.name)
		lines.append("  %s(%s)" % [sig.name, ", ".join(arg_names)])
	lines.sort()
	return _success("Signals on %s (%d):\n%s" % [node.name, lines.size(), "\n".join(lines)])

func _attach_script(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	var script_path: String = args.get("script_path", "")
	var node := _resolve_node(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)
	if not FileAccess.file_exists(script_path):
		return _error("Script not found: %s" % script_path)
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return _error("Could not load script: %s" % script_path)
	node.set_script(script)
	return _success("Attached %s to %s" % [script_path, node.name])
