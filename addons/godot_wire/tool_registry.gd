class_name ToolRegistry extends RefCounted
## Discovers and manages GodotWire tool modules from the tools/ directory.

var _tools: Array[GodotWireTool] = []
var _tool_map: Dictionary = {}  # tool_name -> GodotWireTool instance

func register_module(module: GodotWireTool) -> void:
	_tools.append(module)
	for tool_def in module.get_tools():
		var name: String = tool_def.get("name", "")
		if name != "":
			_tool_map[name] = module

func list_tools() -> Array:
	var all_tools: Array = []
	for module in _tools:
		all_tools.append_array(module.get_tools())
	return all_tools

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	var module = _tool_map.get(tool_name)
	if module == null:
		return {"content": [{"type": "text", "text": "Unknown tool: %s" % tool_name}], "isError": true}
	return module.call_tool(tool_name, args)

func get_tool_count() -> int:
	return _tool_map.size()
