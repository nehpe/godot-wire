@tool
extends GodotWireTool
## Navigation region, navmesh baking, and navigation agent tools.

func get_tools() -> Array:
	return [
		{
			"name": "create_navigation_region",
			"description": "Create a NavigationRegion3D with a configured NavigationMesh",
			"inputSchema": {
				"type": "object",
				"properties": {
					"name": {"type": "string", "description": "Name for the NavigationRegion3D node"},
					"parent": {"type": "string", "description": "Parent node path (default: scene root)"},
					"cell_size": {"type": "number", "description": "Navigation mesh cell size (default: 0.25)"},
					"cell_height": {"type": "number", "description": "Cell height (default: 0.25)"},
					"agent_radius": {"type": "number", "description": "Agent radius for navmesh (default: 0.5)"},
					"agent_height": {"type": "number", "description": "Agent height (default: 1.5)"},
					"agent_max_climb": {"type": "number", "description": "Max step climb height (default: 0.25)"},
					"agent_max_slope": {"type": "number", "description": "Max slope angle in degrees (default: 45.0)"}
				},
				"required": []
			}
		},
		{
			"name": "bake_navigation_mesh",
			"description": "Bake the navigation mesh for a NavigationRegion3D from its child geometry",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the NavigationRegion3D node"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "setup_navigation_agent",
			"description": "Add and configure a NavigationAgent3D on a CharacterBody3D",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Path to the CharacterBody3D node"},
					"radius": {"type": "number", "description": "Agent radius (default: 0.5)"},
					"height": {"type": "number", "description": "Agent height (default: 1.0)"},
					"max_speed": {"type": "number", "description": "Max speed (default: 10.0)"},
					"path_desired_distance": {"type": "number", "description": "Distance to consider waypoint reached (default: 1.0)"},
					"target_desired_distance": {"type": "number", "description": "Distance to consider target reached (default: 1.0)"},
					"avoidance_enabled": {"type": "boolean", "description": "Enable agent avoidance (default: true)"}
				},
				"required": ["path"]
			}
		}
	]

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"create_navigation_region":
			return _create_nav_region(args)
		"bake_navigation_mesh":
			return _bake_nav_mesh(args)
		"setup_navigation_agent":
			return _setup_nav_agent(args)
		_:
			return _error("Unknown tool: %s" % tool_name)

func _create_nav_region(args: Dictionary) -> Dictionary:
	var root := _get_edited_scene_root()
	if root == null:
		return _error("No scene is currently open")
	var region_name: String = args.get("name", "NavigationRegion3D")
	var parent_path: String = args.get("parent", "")
	var parent := root if parent_path.is_empty() else _resolve_node(parent_path)
	if parent == null:
		return _error("Parent node not found: %s" % parent_path)

	var region := NavigationRegion3D.new()
	region.name = region_name

	var navmesh := NavigationMesh.new()
	navmesh.cell_size = args.get("cell_size", 0.25)
	navmesh.cell_height = args.get("cell_height", 0.25)
	navmesh.agent_radius = args.get("agent_radius", 0.5)
	navmesh.agent_height = args.get("agent_height", 1.5)
	navmesh.agent_max_climb = args.get("agent_max_climb", 0.25)
	navmesh.agent_max_slope = args.get("agent_max_slope", 45.0)
	region.navigation_mesh = navmesh

	parent.add_child(region)
	_set_owner_recursive(region, root)
	return _success("Created %s under %s (cell_size=%.2f, agent_radius=%.2f)" % [
		region_name, parent.name, navmesh.cell_size, navmesh.agent_radius
	])

func _bake_nav_mesh(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not node is NavigationRegion3D:
		return _error("Node is not a NavigationRegion3D: %s [%s]" % [node.name, node.get_class()])
	var region: NavigationRegion3D = node
	if region.navigation_mesh == null:
		return _error("NavigationRegion3D has no NavigationMesh resource")
	region.bake_navigation_mesh(false)
	var poly_count := region.navigation_mesh.get_polygon_count()
	return _success("Baked navigation mesh for %s — %d polygons" % [region.name, poly_count])

func _setup_nav_agent(args: Dictionary) -> Dictionary:
	var path: String = args.get("path", "")
	var node := _resolve_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	if not node is CharacterBody3D:
		return _error("Node is not a CharacterBody3D: %s [%s]" % [node.name, node.get_class()])

	# Check if already has a NavigationAgent3D
	var agent: NavigationAgent3D = null
	for child in node.get_children():
		if child is NavigationAgent3D:
			agent = child
			break
	if agent == null:
		agent = NavigationAgent3D.new()
		agent.name = "NavigationAgent3D"
		node.add_child(agent)
		var root := _get_edited_scene_root()
		agent.owner = root

	agent.radius = args.get("radius", 0.5)
	agent.height = args.get("height", 1.0)
	agent.max_speed = args.get("max_speed", 10.0)
	agent.path_desired_distance = args.get("path_desired_distance", 1.0)
	agent.target_desired_distance = args.get("target_desired_distance", 1.0)
	agent.avoidance_enabled = args.get("avoidance_enabled", true)

	return _success("NavigationAgent3D configured on %s (radius=%.1f, max_speed=%.1f, avoidance=%s)" % [
		node.name, agent.radius, agent.max_speed, str(agent.avoidance_enabled)
	])
