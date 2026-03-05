@tool
class_name GodotWireTool extends RefCounted
## Abstract base class for all GodotWire tool modules.
## Subclasses implement get_tools() and call_tool() to register MCP tools.

var plugin: EditorPlugin
var game_bridge  # Reference to GameBridge node for runtime tools

func _init(p_plugin: EditorPlugin, p_bridge = null) -> void:
	plugin = p_plugin
	game_bridge = p_bridge

func get_tools() -> Array:
	return []

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	return _error("Tool '%s' not implemented" % tool_name)

# --- Shared Helpers ---

func _get_editor_interface() -> EditorInterface:
	return plugin.get_editor_interface()

func _get_edited_scene_root() -> Node:
	return _get_editor_interface().get_edited_scene_root()

func _resolve_node(path: String) -> Node:
	var root := _get_edited_scene_root()
	if root == null:
		return null
	if path == "" or path == ".":
		return root
	if path == root.name or path == "/" + root.name:
		return root
	# Try relative to scene root
	var node := root.get_node_or_null(NodePath(path))
	if node:
		return node
	# Try absolute
	node = root.get_node_or_null(NodePath("/" + path))
	if node:
		return node
	# Try by name anywhere in tree
	return _find_by_name(root, path)

func _find_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_by_name(child, target_name)
		if found:
			return found
	return null

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for child in node.get_children():
		# Skip internals of instanced sub-scenes (.glb, .tscn instances)
		if child.scene_file_path != "":
			continue
		_set_owner_recursive(child, owner)

func _success(text: String) -> Dictionary:
	return {"content": [{"type": "text", "text": text}]}

func _error(text: String) -> Dictionary:
	return {"content": [{"type": "text", "text": text}], "isError": true}
