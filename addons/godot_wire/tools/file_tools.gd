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
