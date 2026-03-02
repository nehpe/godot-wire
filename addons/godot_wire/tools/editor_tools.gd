extends GodotWireTool
## Editor state, screenshots, play/stop controls, and selection tools.

func get_tools() -> Array:
	return [
		{
			"name": "get_editor_screenshot",
			"description": "Capture a screenshot of the editor viewport",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		},
		{
			"name": "play_project",
			"description": "Start playing the current project in the editor",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		},
		{
			"name": "stop_project",
			"description": "Stop the currently running project",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		},
		{
			"name": "get_editor_selection",
			"description": "Get the currently selected nodes in the editor",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		},
		{
			"name": "get_editor_errors",
			"description": "Scan all project scripts for parse errors",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"get_editor_screenshot":
			return _get_editor_screenshot()
		"play_project":
			return _play_project()
		"stop_project":
			return _stop_project()
		"get_editor_selection":
			return _get_editor_selection()
		"get_editor_errors":
			return _get_editor_errors()
		_:
			return _error("Unknown tool: %s" % tool_name)

func _get_editor_screenshot() -> Dictionary:
	var viewport := _get_editor_interface().get_editor_viewport_3d()
	if viewport == null:
		return _error("Could not access editor viewport")
	var img := viewport.get_texture().get_image()
	if img == null:
		return _error("Could not capture viewport image")
	var png := img.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png)
	return {"content": [{"type": "image", "data": b64, "mimeType": "image/png"}]}

func _play_project() -> Dictionary:
	_get_editor_interface().play_main_scene()
	return _success("Project started")

func _stop_project() -> Dictionary:
	_get_editor_interface().stop_playing_scene()
	return _success("Project stopped")

func _get_editor_selection() -> Dictionary:
	var selection := _get_editor_interface().get_selection()
	var nodes := selection.get_selected_nodes()
	if nodes.is_empty():
		return _success("No nodes selected")
	var lines: Array = ["Selected %d node(s):" % nodes.size()]
	var root := _get_edited_scene_root()
	for node in nodes:
		var path := str(root.get_path_to(node)) if root else str(node.name)
		lines.append("  %s [%s] @ %s" % [node.name, node.get_class(), path])
	return _success("\n".join(lines))

func _get_editor_errors() -> Dictionary:
	var errors: Array = []
	var scripts := _find_all_scripts("res://")
	for script_path in scripts:
		if not FileAccess.file_exists(script_path):
			continue
		var file := FileAccess.open(script_path, FileAccess.READ)
		if file == null:
			continue
		var content := file.get_as_text()
		file.close()
		var script := GDScript.new()
		script.source_code = content
		var err := script.reload()
		if err != OK:
			errors.append("%s: error %d (%s)" % [script_path, err, error_string(err)])
	if errors.is_empty():
		return _success("No script errors found (%d scripts scanned)" % scripts.size())
	return _error("Found %d error(s):\n%s" % [errors.size(), "\n".join(errors)])

func _find_all_scripts(dir_path: String) -> Array:
	var results: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				results.append_array(_find_all_scripts(dir_path.path_join(file_name)))
		elif file_name.ends_with(".gd"):
			results.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return results
