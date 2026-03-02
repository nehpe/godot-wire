extends GodotWireTool
## File system tools: read, write, delete, list, and search.

func get_tools() -> Array:
	return [
		{
			"name": "read_file",
			"description": "Read the contents of a file in the project",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path (e.g. res://scripts/player.gd)"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "write_file",
			"description": "Write content to a file (creates or overwrites)",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path for the file"},
					"content": {"type": "string", "description": "Content to write"}
				},
				"required": ["path", "content"]
			}
		},
		{
			"name": "delete_file",
			"description": "Delete a file from the project",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path of the file to delete"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "list_directory",
			"description": "List files and directories at a path",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path to list (default: res://)"}
				},
				"required": []
			}
		},
		{
			"name": "search_files",
			"description": "Search for text across project files using a pattern",
			"inputSchema": {
				"type": "object",
				"properties": {
					"query": {"type": "string", "description": "Text or pattern to search for"},
					"file_pattern": {"type": "string", "description": "File extension filter (e.g. gd, tscn, tres)"},
					"path": {"type": "string", "description": "Directory to search in (default: res://)"}
				},
				"required": ["query"]
			}
		},
		{
			"name": "create_file",
			"description": "Create a new file (fails if it already exists)",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path for the new file"},
					"content": {"type": "string", "description": "File content"}
				},
				"required": ["path", "content"]
			}
		},
		{
			"name": "rename_file",
			"description": "Rename or move a file",
			"inputSchema": {
				"type": "object",
				"properties": {
					"from": {"type": "string", "description": "Current resource path"},
					"to": {"type": "string", "description": "New resource path"}
				},
				"required": ["from", "to"]
			}
		},
		{
			"name": "replace_string_in_file",
			"description": "Search and replace text in a file",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path of the file"},
					"search": {"type": "string", "description": "Text to find"},
					"replace": {"type": "string", "description": "Replacement text"}
				},
				"required": ["path", "search", "replace"]
			}
		},
		{
			"name": "create_resource",
			"description": "Create a Godot resource file (.tres) of a given type",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path (e.g. res://materials/red.tres)"},
					"type": {"type": "string", "description": "Resource type (e.g. StandardMaterial3D, Environment, AudioBusLayout)"},
					"properties": {"type": "object", "description": "Properties to set on the resource"}
				},
				"required": ["path", "type"]
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"read_file":
			return _read_file(args)
		"write_file":
			return _write_file(args)
		"delete_file":
			return _delete_file(args)
		"list_directory":
			return _list_directory(args)
		"search_files":
			return _search_files(args)
		"create_file":
			return _create_file(args)
		"rename_file":
			return _rename_file(args)
		"replace_string_in_file":
			return _replace_string_in_file(args)
		"create_resource":
			return _create_resource(args)
		_:
			return _error("Unknown tool: %s" % tool_name)

func _read_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if not FileAccess.file_exists(path):
		return _error("File not found: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("Could not open: %s" % path)
	var content := file.get_as_text()
	file.close()
	return _success(content)

func _write_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var content: String = args.get("content", "")
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("Could not write to: %s" % path)
	file.store_string(content)
	file.close()
	_get_editor_interface().get_resource_filesystem().scan()
	return _success("Wrote %d bytes to %s" % [content.length(), path])

func _delete_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if not FileAccess.file_exists(path):
		return _error("File not found: %s" % path)
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		return _error("Could not delete %s: %s" % [path, error_string(err)])
	_get_editor_interface().get_resource_filesystem().scan()
	return _success("Deleted: %s" % path)

func _list_directory(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "res://")
	var dir := DirAccess.open(path)
	if dir == null:
		return _error("Could not open directory: %s" % path)
	var entries: Array = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var prefix := "[DIR]  " if dir.current_is_dir() else "[FILE] "
			entries.append(prefix + name)
		name = dir.get_next()
	dir.list_dir_end()
	entries.sort()
	return _success("Contents of %s:\n%s" % [path, "\n".join(entries)])

func _search_files(args: Dictionary) -> Dictionary:
	var query: String = args.get("query", "")
	var file_pattern: String = args.get("file_pattern", "")
	var search_path: String = args.get("path", "res://")
	if query.is_empty():
		return _error("Query is required")
	var matches: Array = []
	_search_recursive(search_path, query, file_pattern, matches)
	if matches.is_empty():
		return _success("No matches found for '%s'" % query)
	var text := "Found %d match(es) for '%s':\n\n" % [matches.size(), query]
	for m in matches:
		text += "--- %s (line %d) ---\n%s\n\n" % [m.path, m.line, m.context]
	return _success(text)

func _search_recursive(dir_path: String, query: String, file_pattern: String, results: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full_path := dir_path.path_join(name)
		if dir.current_is_dir():
			_search_recursive(full_path, query, file_pattern, results)
		else:
			if file_pattern.is_empty() or name.ends_with("." + file_pattern):
				_search_in_file(full_path, query, results)
		name = dir.get_next()
	dir.list_dir_end()

func _search_in_file(path: String, query: String, results: Array) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	var lines := content.split("\n")
	for i in lines.size():
		if lines[i].findn(query) != -1:
			var start := maxi(0, i - 1)
			var end := mini(lines.size() - 1, i + 1)
			var context_lines: Array = []
			for j in range(start, end + 1):
				var prefix := ">> " if j == i else "   "
				context_lines.append("%s%d: %s" % [prefix, j + 1, lines[j]])
			results.append({"path": path, "line": i + 1, "context": "\n".join(context_lines)})

func _create_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var content: String = args.get("content", "")
	if FileAccess.file_exists(path):
		return _error("File already exists: %s (use write_file to overwrite)" % path)
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("Could not create file: %s" % path)
	file.store_string(content)
	file.close()
	_get_editor_interface().get_resource_filesystem().scan()
	return _success("Created file: %s (%d bytes)" % [path, content.length()])

func _rename_file(args: Dictionary) -> Dictionary:
	var from: String = args.get("from", "")
	var to: String = args.get("to", "")
	if not FileAccess.file_exists(from):
		return _error("Source file not found: %s" % from)
	var dir_path := to.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var dir := DirAccess.open(from.get_base_dir())
	if dir == null:
		return _error("Could not access directory")
	var err := dir.rename(from, to)
	if err != OK:
		return _error("Rename failed: %s" % error_string(err))
	_get_editor_interface().get_resource_filesystem().scan()
	return _success("Renamed %s -> %s" % [from, to])

func _replace_string_in_file(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var search: String = args.get("search", "")
	var replace_text: String = args.get("replace", "")
	if not FileAccess.file_exists(path):
		return _error("File not found: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	var count := content.count(search)
	if count == 0:
		return _error("Search text not found in %s" % path)
	content = content.replace(search, replace_text)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	_get_editor_interface().get_resource_filesystem().scan()
	return _success("Replaced %d occurrence(s) in %s" % [count, path])

func _create_resource(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var res_type: String = args.get("type", "")
	var props: Dictionary = args.get("properties", {})
	if path.is_empty() or res_type.is_empty():
		return _error("Path and type are required")
	if not ClassDB.class_exists(res_type):
		return _error("Unknown resource type: %s" % res_type)
	var res: Resource = ClassDB.instantiate(res_type) as Resource
	if res == null:
		return _error("Could not create resource of type: %s" % res_type)
	for key in props:
		res.set(key, props[key])
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return _error("Failed to save resource: %s" % error_string(err))
	_get_editor_interface().get_resource_filesystem().scan()
	return _success("Created %s resource at %s" % [res_type, path])
