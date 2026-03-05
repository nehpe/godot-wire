@tool
extends GodotWireTool
## Shader tools: create, edit, inspect, and manage shaders and materials.

func get_tools() -> Array:
	return [
		{
			"name": "create_shader",
			"description": "Create a new .gdshader file with optional initial code. If no code given, creates a minimal canvas_item or spatial shader.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Save path (e.g., 'res://shaders/my_effect.gdshader')"
					},
					"shader_type": {
						"type": "string",
						"description": "Shader type: canvas_item, spatial, particles, fog, sky. Default: canvas_item",
						"enum": ["canvas_item", "spatial", "particles", "fog", "sky"]
					},
					"code": {
						"type": "string",
						"description": "Full shader code. If omitted, generates a minimal template."
					},
					"uniforms": {
						"type": "array",
						"description": "Uniform declarations to include: [{name, type, default, hint}]",
						"items": {
							"type": "object",
							"properties": {
								"name": {"type": "string"},
								"type": {"type": "string", "description": "float, vec2, vec3, vec4, int, bool, sampler2D"},
								"default": {"type": "string", "description": "Default value as string (e.g., '1.0', 'vec4(1.0)')"},
								"hint": {"type": "string", "description": "Optional hint: source_color, range(0,1), etc."}
							}
						}
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "read_shader",
			"description": "Read the source code of a .gdshader file or get shader code from a ShaderMaterial on a node",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to .gdshader file, OR node path to read material shader from"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "edit_shader",
			"description": "Replace the full code of an existing .gdshader file",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the .gdshader file"
					},
					"code": {
						"type": "string",
						"description": "New shader code (replaces entire file)"
					}
				},
				"required": ["path", "code"]
			}
		},
		{
			"name": "set_shader_param",
			"description": "Set a shader parameter (uniform) on a node's ShaderMaterial",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {
						"type": "string",
						"description": "Path to the node with a ShaderMaterial"
					},
					"param": {
						"type": "string",
						"description": "Uniform name to set"
					},
					"value": {
						"description": "Value to set (number, array for vec2/3/4, string for color '#rrggbb')"
					},
					"material_property": {
						"type": "string",
						"description": "Which material property: 'material' (default) or 'canvas_item/material' for CanvasItem override",
						"enum": ["material", "canvas_item/material"]
					}
				},
				"required": ["node_path", "param", "value"]
			}
		},
		{
			"name": "get_shader_params",
			"description": "List all shader parameters (uniforms) and their current values on a node's ShaderMaterial",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {
						"type": "string",
						"description": "Path to the node with a ShaderMaterial"
					}
				},
				"required": ["node_path"]
			}
		},
		{
			"name": "apply_shader_to_node",
			"description": "Create a ShaderMaterial from a .gdshader file and apply it to a node",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {
						"type": "string",
						"description": "Path to the target node"
					},
					"shader_path": {
						"type": "string",
						"description": "Path to the .gdshader file"
					},
					"params": {
						"type": "object",
						"description": "Optional initial uniform values to set"
					}
				},
				"required": ["node_path", "shader_path"]
			}
		},
		{
			"name": "list_shaders",
			"description": "Find all .gdshader files in the project, with their type and uniform list",
			"inputSchema": {
				"type": "object",
				"properties": {
					"directory": {
						"type": "string",
						"description": "Directory to search (default: 'res://')"
					}
				},
				"required": []
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"create_shader":
			return _create_shader(args)
		"read_shader":
			return _read_shader(args)
		"edit_shader":
			return _edit_shader(args)
		"set_shader_param":
			return _set_shader_param(args)
		"get_shader_params":
			return _get_shader_params(args)
		"apply_shader_to_node":
			return _apply_shader_to_node(args)
		"list_shaders":
			return _list_shaders(args)
	return _error("Unknown tool: %s" % tool_name)

# --- create_shader ---

func _create_shader(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty():
		return _error("path is required")
	var shader_type: String = args.get("shader_type", "canvas_item")
	var code: String = args.get("code", "")
	var uniforms: Array = args.get("uniforms", [])

	if code.is_empty():
		code = _generate_template(shader_type, uniforms)

	# Ensure directory exists
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("Cannot write to: %s (error: %s)" % [path, error_string(FileAccess.get_open_error())])
	file.store_string(code)
	file.close()

	# Tell editor about the new file
	EditorInterface.get_resource_filesystem().scan()

	return _success("Created %s shader at %s (%d bytes)" % [shader_type, path, code.length()])

# --- read_shader ---

func _read_shader(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	if path.is_empty():
		return _error("path is required")

	# If it's a .gdshader file, read directly
	if path.ends_with(".gdshader") or path.ends_with(".shader"):
		if not FileAccess.file_exists(path):
			return _error("Shader file not found: %s" % path)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return _error("Cannot read: %s" % path)
		var code := file.get_as_text()
		file.close()
		return _success(code)

	# Otherwise treat as node path — read shader from material
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var mat := _get_shader_material(node)
	if mat == null:
		return _error("No ShaderMaterial on node: %s" % path)
	if mat.shader == null:
		return _error("ShaderMaterial has no shader assigned")
	return _success(mat.shader.code)

# --- edit_shader ---

func _edit_shader(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var code: String = args.get("code", "")
	if path.is_empty() or code.is_empty():
		return _error("path and code are required")
	if not FileAccess.file_exists(path):
		return _error("Shader file not found: %s" % path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("Cannot write to: %s" % path)
	file.store_string(code)
	file.close()

	# Reload the resource so editor picks up changes
	var shader := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	EditorInterface.get_resource_filesystem().scan()

	return _success("Updated shader at %s (%d bytes)" % [path, code.length()])

# --- set_shader_param ---

func _set_shader_param(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	var param_name: String = args.get("param", "")
	var value = args.get("value")
	var node := _resolve_node(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)
	var mat := _get_shader_material(node)
	if mat == null:
		return _error("No ShaderMaterial on node: %s" % node_path)

	var converted = _convert_shader_value(value)
	mat.set_shader_parameter(param_name, converted)
	return _success("Set shader param %s = %s on %s" % [param_name, str(converted), node.name])

# --- get_shader_params ---

func _get_shader_params(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	var node := _resolve_node(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)
	var mat := _get_shader_material(node)
	if mat == null:
		return _error("No ShaderMaterial on node: %s" % node_path)
	if mat.shader == null:
		return _error("ShaderMaterial has no shader assigned")

	var params := {}
	for prop in mat.get_property_list():
		if prop.name.begins_with("shader_parameter/"):
			var pname: String = prop.name.replace("shader_parameter/", "")
			var val = mat.get_shader_parameter(pname)
			params[pname] = _serialize_value(val)

	var info := {
		"shader_path": mat.shader.resource_path if mat.shader.resource_path else "inline",
		"shader_type": _get_shader_type_string(mat.shader.code),
		"params": params
	}
	return _success(JSON.stringify(info, "\t"))

# --- apply_shader_to_node ---

func _apply_shader_to_node(args: Dictionary) -> Dictionary:
	var node_path: String = args.get("node_path", "")
	var shader_path: String = args.get("shader_path", "")
	var params: Dictionary = args.get("params", {})
	var node := _resolve_node(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)
	var shader := ResourceLoader.load(shader_path) as Shader
	if shader == null:
		return _error("Cannot load shader: %s" % shader_path)

	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key in params:
		mat.set_shader_parameter(key, _convert_shader_value(params[key]))

	var undo := plugin.get_undo_redo()
	var old_mat = node.get("material")
	undo.create_action("Apply shader to %s" % node.name)
	undo.add_do_property(node, "material", mat)
	undo.add_undo_property(node, "material", old_mat)
	undo.commit_action()

	return _success("Applied %s to %s with %d params" % [shader_path, node.name, params.size()])

# --- list_shaders ---

func _list_shaders(args: Dictionary) -> Dictionary:
	var dir_path: String = args.get("directory", "res://")
	var shaders := _find_shaders(dir_path)
	var results: Array = []
	for path in shaders:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var code := file.get_as_text()
		file.close()
		var info := {
			"path": path,
			"type": _get_shader_type_string(code),
			"uniforms": _parse_uniforms(code),
			"size": code.length()
		}
		results.append(info)
	return _success(JSON.stringify(results, "\t"))

# --- Helpers ---

func _get_shader_material(node: Node) -> ShaderMaterial:
	if node.get("material") is ShaderMaterial:
		return node.get("material") as ShaderMaterial
	return null

func _get_shader_type_string(code: String) -> String:
	if code.find("shader_type spatial") >= 0:
		return "spatial"
	elif code.find("shader_type particles") >= 0:
		return "particles"
	elif code.find("shader_type fog") >= 0:
		return "fog"
	elif code.find("shader_type sky") >= 0:
		return "sky"
	return "canvas_item"

func _parse_uniforms(code: String) -> Array:
	var uniforms: Array = []
	for line in code.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("uniform "):
			uniforms.append(stripped.trim_suffix(";"))
	return uniforms

func _find_shaders(dir_path: String) -> Array:
	var results: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return results
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if d.current_is_dir():
			if fname != "." and fname != ".." and fname != ".godot":
				results.append_array(_find_shaders(dir_path.path_join(fname)))
		elif fname.ends_with(".gdshader"):
			results.append(dir_path.path_join(fname))
		fname = d.get_next()
	d.list_dir_end()
	return results

func _convert_shader_value(value):
	# Handle color strings like "#ff00ff"
	if value is String and value.begins_with("#"):
		var c := Color.html(value)
		return c
	# Handle arrays as vectors
	if value is Array:
		match value.size():
			2: return Vector2(value[0], value[1])
			3: return Vector3(value[0], value[1], value[2])
			4: return Color(value[0], value[1], value[2], value[3])
	return value

func _serialize_value(val) -> String:
	if val is Color:
		return "#%s (%.2f, %.2f, %.2f, %.2f)" % [val.to_html(), val.r, val.g, val.b, val.a]
	if val is Vector2:
		return "vec2(%.3f, %.3f)" % [val.x, val.y]
	if val is Vector3:
		return "vec3(%.3f, %.3f, %.3f)" % [val.x, val.y, val.z]
	if val is Vector4:
		return "vec4(%.3f, %.3f, %.3f, %.3f)" % [val.x, val.y, val.z, val.w]
	return str(val)

func _generate_template(shader_type: String, uniforms: Array) -> String:
	var code := "shader_type %s;\n\n" % shader_type

	# Add uniforms
	for u in uniforms:
		var line := "uniform %s %s" % [u.get("type", "float"), u.get("name", "param")]
		var hint: String = u.get("hint", "")
		if not hint.is_empty():
			line += " : %s" % hint
		var default_val: String = u.get("default", "")
		if not default_val.is_empty():
			line += " = %s" % default_val
		code += line + ";\n"

	if uniforms.size() > 0:
		code += "\n"

	# Add main function
	match shader_type:
		"canvas_item":
			code += "void fragment() {\n\tvec4 tex = texture(TEXTURE, UV);\n\tCOLOR = tex;\n}\n"
		"spatial":
			code += "void fragment() {\n\tALBEDO = vec3(1.0);\n}\n"
		"particles":
			code += "void process() {\n\t// Particle logic\n}\n"
		"fog":
			code += "void fog() {\n\tDENSITY = 0.1;\n\tALBEDO = vec3(1.0);\n}\n"
		"sky":
			code += "void sky() {\n\tCOLOR = vec3(0.2, 0.4, 0.8);\n}\n"

	return code
