@tool
extends GodotWireTool
## Script execution, creation, editing, and error checking tools.

func get_tools() -> Array:
	return [
		{
			"name": "execute_gdscript",
			"description": "Execute arbitrary GDScript code in the editor context and return the result",
			"inputSchema": {
				"type": "object",
				"properties": {
					"code": {"type": "string", "description": "GDScript code to execute. Use 'return' to return a value."}
				},
				"required": ["code"]
			}
		},
		{
			"name": "create_script",
			"description": "Create a new GDScript file",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path for the script (e.g. res://scripts/player.gd)"},
					"content": {"type": "string", "description": "Full script content"},
					"base_class": {"type": "string", "description": "Base class to extend (default: Node)"}
				},
				"required": ["path", "content"]
			}
		},
		{
			"name": "edit_script",
			"description": "Edit an existing GDScript file using search and replace",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path of the script to edit"},
					"search": {"type": "string", "description": "Text to search for (exact match)"},
					"replace": {"type": "string", "description": "Replacement text"}
				},
				"required": ["path", "search", "replace"]
			}
		},
		{
			"name": "check_script_errors",
			"description": "Check a GDScript file for syntax and parse errors",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path of the script to check"}
				},
				"required": ["path"]
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"execute_gdscript":
			return _execute_gdscript(args)
		"create_script":
			return _create_script(args)
		"edit_script":
			return _edit_script(args)
		"check_script_errors":
			return _check_script_errors(args)
		_:
			return _error("Unknown tool: %s" % tool_name)

func _execute_gdscript(args: Dictionary) -> Dictionary:
	var code: String = args.get("code", "")
	if code.is_empty():
		return _error("No code provided")
	var script := GDScript.new()
	var wrapped := "extends RefCounted\nvar _ei\nfunc _run():\n"
	for line in code.split("\n"):
		wrapped += "\t" + line + "\n"
	script.source_code = wrapped
	var err := script.reload()
	if err != OK:
		return _error("Script compilation error: %s" % error_string(err))
	var obj = script.new()
	obj._ei = _get_editor_interface()
	var result = obj._run()
	if result == null:
		return _success("Executed successfully (no return value)")
	return _success(str(result))

func _create_script(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var content: String = args.get("content", "")
	if path.is_empty() or content.is_empty():
		return _error("Path and content are required")
	# Ensure directory exists
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("Could not create file: %s (error: %s)" % [path, error_string(FileAccess.get_open_error())])
	file.store_string(content)
	file.close()
	_get_editor_interface().get_resource_filesystem().scan()
	return _success("Created script: %s" % path)

func _edit_script(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var search: String = args.get("search", "")
	var replace_text: String = args.get("replace", "")
	if path.is_empty() or search.is_empty():
		return _error("Path and search text are required")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("Could not open file: %s" % path)
	var content := file.get_as_text()
	file.close()
	var idx := content.find(search)
	if idx == -1:
		return _error("Search text not found in %s" % path)
	var count := content.count(search)
	content = content.replace(search, replace_text)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	_get_editor_interface().get_resource_filesystem().scan()
	return _success("Replaced %d occurrence(s) in %s" % [count, path])

func _check_script_errors(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty():
		return _error("Path is required")
	if not FileAccess.file_exists(path):
		return _error("File not found: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	var script := GDScript.new()
	script.source_code = content
	var err := script.reload()
	if err != OK:
		return _error("Parse error %d in %s: %s" % [err, path, error_string(err)])
	return _success("No errors found in %s" % path)
