extends GodotWireTool
## Editor state, screenshots, play/stop controls, selection, project settings, and scene management.

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
		},
		{
			"name": "open_scene",
			"description": "Open a scene file in the editor",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path of the scene (e.g. res://scenes/main.tscn)"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "save_scene",
			"description": "Save the currently edited scene to disk",
			"inputSchema": {
				"type": "object",
				"properties": {},
				"required": []
			}
		},
		{
			"name": "get_project_setting",
			"description": "Read a Godot project setting value",
			"inputSchema": {
				"type": "object",
				"properties": {
					"setting": {"type": "string", "description": "Setting path (e.g. application/config/name, display/window/size/viewport_width)"}
				},
				"required": ["setting"]
			}
		},
		{
			"name": "set_project_setting",
			"description": "Set a Godot project setting value",
			"inputSchema": {
				"type": "object",
				"properties": {
					"setting": {"type": "string", "description": "Setting path"},
					"value": {"description": "Value to set"}
				},
				"required": ["setting", "value"]
			}
		},
		{
			"name": "save_project_settings",
			"description": "Save all project settings to project.godot",
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
		"open_scene":
			return _open_scene(args)
		"save_scene":
			return _save_scene()
		"get_project_setting":
			return _get_project_setting(args)
		"set_project_setting":
			return _set_project_setting(args)
		"save_project_settings":
			return _save_project_settings()
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

func _open_scene(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if not FileAccess.file_exists(path):
		return _error("Scene not found: %s" % path)
	_get_editor_interface().open_scene_from_path(path)
	return _success("Opened scene: %s" % path)

func _save_scene() -> Dictionary:
	var root := _get_edited_scene_root()
	if root == null:
		return _error("No scene is currently open")
	var scene_path := root.scene_file_path
	if scene_path.is_empty():
		return _error("Scene has no file path — save manually first")
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, scene_path)
	if err != OK:
		return _error("Failed to save scene: %s" % error_string(err))
	return _success("Saved scene: %s" % scene_path)

func _get_project_setting(args: Dictionary) -> Dictionary:
	var setting: String = args.get("setting", "")
	if not ProjectSettings.has_setting(setting):
		return _error("Setting not found: %s" % setting)
	var val = ProjectSettings.get_setting(setting)
	return _success("%s = %s" % [setting, str(val)])

func _set_project_setting(args: Dictionary) -> Dictionary:
	var setting: String = args.get("setting", "")
	var value = args.get("value")
	ProjectSettings.set_setting(setting, value)
	return _success("Set %s = %s" % [setting, str(value)])

func _save_project_settings() -> Dictionary:
	var err := ProjectSettings.save()
	if err != OK:
		return _error("Failed to save project settings: %s" % error_string(err))
	return _success("Project settings saved to project.godot")
