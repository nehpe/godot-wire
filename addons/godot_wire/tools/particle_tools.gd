@tool
extends GodotWireTool

## Particle system tools — create and configure GPUParticles2D/3D with process materials


func get_tools() -> Array:
	return [
		{
			"name": "create_particles",
			"description": "Create a GPUParticles2D or GPUParticles3D node with a configured ParticleProcessMaterial. Returns the node path.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {"type": "string", "description": "Path to parent node"},
					"name": {"type": "string", "description": "Node name"},
					"is_3d": {"type": "boolean", "description": "Use GPUParticles3D instead of 2D (default: false)"},
					"emitting": {"type": "boolean", "description": "Start emitting immediately (default: true)"},
					"amount": {"type": "integer", "description": "Number of particles (default: 16)"},
					"lifetime": {"type": "number", "description": "Particle lifetime in seconds (default: 1.0)"},
					"one_shot": {"type": "boolean", "description": "Emit once then stop (default: false)"},
					"explosiveness": {"type": "number", "description": "0.0=steady stream, 1.0=all at once (default: 0.0)"},
					"texture": {"type": "string", "description": "Path to particle texture (e.g. res://assets/textures/particle.png)"}
				},
				"required": ["parent_path", "name"]
			}
		},
		{
			"name": "set_particle_material",
			"description": "Configure the ParticleProcessMaterial on a GPUParticles2D/3D node. Set direction, spread, velocity, gravity, scale, color, emission shape, etc.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to the GPUParticles2D/3D node"},
					"direction": {"type": "object", "description": "Emission direction {x, y, z} (default: {x:0, y:-1, z:0} = upward for 2D)"},
					"spread": {"type": "number", "description": "Angular spread in degrees (default: 45)"},
					"initial_velocity_min": {"type": "number", "description": "Min initial velocity"},
					"initial_velocity_max": {"type": "number", "description": "Max initial velocity"},
					"gravity": {"type": "object", "description": "Gravity vector {x, y, z}"},
					"angular_velocity_min": {"type": "number", "description": "Min angular velocity (degrees/sec)"},
					"angular_velocity_max": {"type": "number", "description": "Max angular velocity (degrees/sec)"},
					"scale_min": {"type": "number", "description": "Min particle scale"},
					"scale_max": {"type": "number", "description": "Max particle scale"},
					"scale_curve": {"type": "string", "description": "Scale over lifetime: 'fade_out', 'fade_in', 'pulse'"},
					"color": {"type": "string", "description": "Particle color as hex (#RRGGBB) or named color"},
					"color_ramp": {"type": "array", "description": "Array of {offset, color} for gradient over lifetime", "items": {"type": "object"}},
					"emission_shape": {"type": "string", "description": "'point', 'sphere', 'box', 'ring'"},
					"emission_radius": {"type": "number", "description": "Radius for sphere/ring emission shape"},
					"emission_box_extents": {"type": "object", "description": "{x, y, z} half-extents for box emission"},
					"damping_min": {"type": "number", "description": "Min damping (slows particles over time)"},
					"damping_max": {"type": "number", "description": "Max damping"},
					"hue_variation_min": {"type": "number", "description": "Min hue shift (-0.5 to 0.5)"},
					"hue_variation_max": {"type": "number", "description": "Max hue shift (-0.5 to 0.5)"}
				},
				"required": ["node_path"]
			}
		},
		{
			"name": "get_particle_info",
			"description": "Get the current configuration of a GPUParticles2D/3D node including its process material settings.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to the GPUParticles2D/3D node"}
				},
				"required": ["node_path"]
			}
		},
		{
			"name": "create_particle_preset",
			"description": "Create a GPUParticles2D with a named VFX preset — pre-configured for common game effects.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {"type": "string", "description": "Path to parent node"},
					"name": {"type": "string", "description": "Node name"},
					"preset": {"type": "string", "description": "'explosion', 'spark', 'fire', 'smoke', 'trail', 'blood', 'confetti', 'dust', 'muzzle_flash', 'heal'"},
					"color": {"type": "string", "description": "Override color as hex (#RRGGBB). Uses preset default if omitted."},
					"scale": {"type": "number", "description": "Scale multiplier for the effect (default: 1.0)"},
					"one_shot": {"type": "boolean", "description": "Override one_shot (some presets default to true)"}
				},
				"required": ["parent_path", "name", "preset"]
			}
		},
		{
			"name": "emit_particles",
			"description": "Trigger emission on a one_shot particle node, or toggle emitting on/off at runtime.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to the GPUParticles2D/3D node"},
					"emitting": {"type": "boolean", "description": "true to start, false to stop (default: true)"},
					"restart": {"type": "boolean", "description": "Restart the particle system (default: false)"}
				},
				"required": ["node_path"]
			}
		}
	]


func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"create_particles":
			return _create_particles(args)
		"set_particle_material":
			return _set_particle_material(args)
		"get_particle_info":
			return _get_particle_info(args)
		"create_particle_preset":
			return _create_particle_preset(args)
		"emit_particles":
			return _emit_particles(args)
	return _error("Unknown tool: %s" % tool_name)


# ---------------------------------------------------------------------------
# create_particles
# ---------------------------------------------------------------------------
func _create_particles(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var parent_path: String = args.get("parent_path", ".")
	var parent := root.get_node_or_null(parent_path) if parent_path != "." else root
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var node_name: String = args.get("name", "Particles")
	var is_3d: bool = args.get("is_3d", false)

	var node: Node
	if is_3d:
		node = GPUParticles3D.new()
	else:
		node = GPUParticles2D.new()

	node.name = node_name

	var mat := ParticleProcessMaterial.new()
	if is_3d:
		(node as GPUParticles3D).process_material = mat
		(node as GPUParticles3D).emitting = args.get("emitting", true)
		(node as GPUParticles3D).amount = args.get("amount", 16)
		(node as GPUParticles3D).lifetime = args.get("lifetime", 1.0)
		(node as GPUParticles3D).one_shot = args.get("one_shot", false)
		(node as GPUParticles3D).explosiveness = args.get("explosiveness", 0.0)
	else:
		(node as GPUParticles2D).process_material = mat
		(node as GPUParticles2D).emitting = args.get("emitting", true)
		(node as GPUParticles2D).amount = args.get("amount", 16)
		(node as GPUParticles2D).lifetime = args.get("lifetime", 1.0)
		(node as GPUParticles2D).one_shot = args.get("one_shot", false)
		(node as GPUParticles2D).explosiveness = args.get("explosiveness", 0.0)

	var tex_path: String = args.get("texture", "")
	if tex_path != "":
		var tex := load(tex_path)
		if tex and not is_3d:
			(node as GPUParticles2D).texture = tex

	var undo := plugin.get_undo_redo()
	undo.create_action("Create particles: %s" % node_name)
	undo.add_do_method(parent, "add_child", node)
	undo.add_do_method(node, "set_owner", root)
	undo.add_do_reference(node)
	undo.add_undo_method(parent, "remove_child", node)
	undo.commit_action()

	return _success("Created %s at %s/%s" % [
		"GPUParticles3D" if is_3d else "GPUParticles2D",
		parent.get_path(), node_name
	])


# ---------------------------------------------------------------------------
# set_particle_material
# ---------------------------------------------------------------------------
func _set_particle_material(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var node_path: String = args.get("node_path", "")
	var node := root.get_node_or_null(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)

	var mat: ParticleProcessMaterial
	if node is GPUParticles2D:
		mat = (node as GPUParticles2D).process_material as ParticleProcessMaterial
	elif node is GPUParticles3D:
		mat = (node as GPUParticles3D).process_material as ParticleProcessMaterial
	else:
		return _error("Node is not a GPUParticles2D/3D: %s" % node_path)

	if mat == null:
		mat = ParticleProcessMaterial.new()
		if node is GPUParticles2D:
			(node as GPUParticles2D).process_material = mat
		else:
			(node as GPUParticles3D).process_material = mat

	var changes: Array = []

	if args.has("direction"):
		var d: Dictionary = args["direction"]
		mat.direction = Vector3(d.get("x", 0), d.get("y", -1), d.get("z", 0))
		changes.append("direction")
	if args.has("spread"):
		mat.spread = args["spread"]
		changes.append("spread")
	if args.has("initial_velocity_min"):
		mat.initial_velocity_min = args["initial_velocity_min"]
		changes.append("velocity_min")
	if args.has("initial_velocity_max"):
		mat.initial_velocity_max = args["initial_velocity_max"]
		changes.append("velocity_max")
	if args.has("gravity"):
		var g: Dictionary = args["gravity"]
		mat.gravity = Vector3(g.get("x", 0), g.get("y", 0), g.get("z", 0))
		changes.append("gravity")
	if args.has("angular_velocity_min"):
		mat.angular_velocity_min = args["angular_velocity_min"]
		changes.append("angular_vel_min")
	if args.has("angular_velocity_max"):
		mat.angular_velocity_max = args["angular_velocity_max"]
		changes.append("angular_vel_max")
	if args.has("scale_min"):
		mat.scale_min = args["scale_min"]
		changes.append("scale_min")
	if args.has("scale_max"):
		mat.scale_max = args["scale_max"]
		changes.append("scale_max")
	if args.has("damping_min"):
		mat.damping_min = args["damping_min"]
		changes.append("damping_min")
	if args.has("damping_max"):
		mat.damping_max = args["damping_max"]
		changes.append("damping_max")
	if args.has("hue_variation_min"):
		mat.hue_variation_min = args["hue_variation_min"]
		changes.append("hue_var_min")
	if args.has("hue_variation_max"):
		mat.hue_variation_max = args["hue_variation_max"]
		changes.append("hue_var_max")

	if args.has("color"):
		mat.color = Color.from_string(args["color"], Color.WHITE)
		changes.append("color")

	if args.has("color_ramp"):
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array()
		gradient.colors = PackedColorArray()
		for point in args["color_ramp"]:
			gradient.add_point(point.get("offset", 0.0), Color.from_string(point.get("color", "#FFFFFF"), Color.WHITE))
		var tex := GradientTexture1D.new()
		tex.gradient = gradient
		mat.color_ramp = tex
		changes.append("color_ramp")

	if args.has("scale_curve"):
		var curve := CurveTexture.new()
		var c := Curve.new()
		match args["scale_curve"]:
			"fade_out":
				c.add_point(Vector2(0, 1))
				c.add_point(Vector2(1, 0))
			"fade_in":
				c.add_point(Vector2(0, 0))
				c.add_point(Vector2(1, 1))
			"pulse":
				c.add_point(Vector2(0, 0))
				c.add_point(Vector2(0.3, 1))
				c.add_point(Vector2(0.7, 1))
				c.add_point(Vector2(1, 0))
		curve.curve = c
		mat.scale_curve = curve
		changes.append("scale_curve")

	if args.has("emission_shape"):
		match args["emission_shape"]:
			"point":
				mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			"sphere":
				mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
				if args.has("emission_radius"):
					mat.emission_sphere_radius = args["emission_radius"]
			"box":
				mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
				if args.has("emission_box_extents"):
					var e: Dictionary = args["emission_box_extents"]
					mat.emission_box_extents = Vector3(e.get("x", 1), e.get("y", 1), e.get("z", 1))
			"ring":
				mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
				if args.has("emission_radius"):
					mat.emission_ring_radius = args["emission_radius"]
		changes.append("emission_shape")

	return _success("Updated particle material: %s" % ", ".join(changes))


# ---------------------------------------------------------------------------
# get_particle_info
# ---------------------------------------------------------------------------
func _get_particle_info(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var node_path: String = args.get("node_path", "")
	var node := root.get_node_or_null(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)

	var info := {}
	var mat: ParticleProcessMaterial

	if node is GPUParticles2D:
		var p := node as GPUParticles2D
		info["type"] = "GPUParticles2D"
		info["emitting"] = p.emitting
		info["amount"] = p.amount
		info["lifetime"] = p.lifetime
		info["one_shot"] = p.one_shot
		info["explosiveness"] = p.explosiveness
		info["has_texture"] = p.texture != null
		mat = p.process_material as ParticleProcessMaterial
	elif node is GPUParticles3D:
		var p := node as GPUParticles3D
		info["type"] = "GPUParticles3D"
		info["emitting"] = p.emitting
		info["amount"] = p.amount
		info["lifetime"] = p.lifetime
		info["one_shot"] = p.one_shot
		info["explosiveness"] = p.explosiveness
		mat = p.process_material as ParticleProcessMaterial
	else:
		return _error("Not a particle node: %s" % node_path)

	if mat:
		info["material"] = {
			"direction": {"x": mat.direction.x, "y": mat.direction.y, "z": mat.direction.z},
			"spread": mat.spread,
			"initial_velocity_min": mat.initial_velocity_min,
			"initial_velocity_max": mat.initial_velocity_max,
			"gravity": {"x": mat.gravity.x, "y": mat.gravity.y, "z": mat.gravity.z},
			"scale_min": mat.scale_min,
			"scale_max": mat.scale_max,
			"damping_min": mat.damping_min,
			"damping_max": mat.damping_max,
			"color": "#%s" % mat.color.to_html(false),
			"has_color_ramp": mat.color_ramp != null,
			"has_scale_curve": mat.scale_curve != null,
		}

	return _success(JSON.stringify(info, "\t"))


# ---------------------------------------------------------------------------
# create_particle_preset
# ---------------------------------------------------------------------------
func _create_particle_preset(args: Dictionary) -> Dictionary:
	var preset: String = args.get("preset", "")
	var color_override: String = args.get("color", "")
	var scale_mult: float = args.get("scale", 1.0)

	var config := _get_preset_config(preset)
	if config.is_empty():
		return _error("Unknown preset: %s. Available: explosion, spark, fire, smoke, trail, blood, confetti, dust, muzzle_flash, heal" % preset)

	# Override one_shot if specified
	if args.has("one_shot"):
		config["one_shot"] = args["one_shot"]

	# Create the particle node
	var create_args := {
		"parent_path": args.get("parent_path", "."),
		"name": args.get("name", preset),
		"amount": config.get("amount", 16),
		"lifetime": config.get("lifetime", 1.0),
		"one_shot": config.get("one_shot", false),
		"explosiveness": config.get("explosiveness", 0.0),
		"emitting": config.get("emitting", true),
	}

	var result := _create_particles(create_args)
	if result.get("isError", false):
		return result

	# Now configure the material
	var root := _get_edited_root()
	var parent_path: String = args.get("parent_path", ".")
	var parent := root.get_node_or_null(parent_path) if parent_path != "." else root
	var node_name: String = args.get("name", preset)
	var node_path: String = "%s/%s" % [parent.get_path(), node_name] if parent != root else node_name

	var mat_args: Dictionary = config.get("material", {}).duplicate(true)
	mat_args["node_path"] = node_path

	# Apply color override
	if color_override != "":
		mat_args["color"] = color_override
		# Also update color_ramp first color if present
		if mat_args.has("color_ramp"):
			mat_args["color_ramp"][0]["color"] = color_override

	# Apply scale multiplier
	if mat_args.has("scale_min"):
		mat_args["scale_min"] *= scale_mult
	if mat_args.has("scale_max"):
		mat_args["scale_max"] *= scale_mult

	var mat_result := _set_particle_material(mat_args)

	return _success("Created '%s' preset particle at %s\n%s" % [preset, node_path, mat_result.get("content", [{}])[0].get("text", "")])


func _get_preset_config(preset: String) -> Dictionary:
	match preset:
		"explosion":
			return {
				"amount": 32, "lifetime": 0.6, "one_shot": true, "explosiveness": 1.0, "emitting": false,
				"material": {
					"direction": {"x": 0, "y": 0, "z": 0}, "spread": 180.0,
					"initial_velocity_min": 150.0, "initial_velocity_max": 350.0,
					"gravity": {"x": 0, "y": 0, "z": 0},
					"scale_min": 1.5, "scale_max": 3.0, "scale_curve": "fade_out",
					"damping_min": 20.0, "damping_max": 40.0,
					"color": "#FF8833",
					"color_ramp": [
						{"offset": 0.0, "color": "#FFDD44"},
						{"offset": 0.4, "color": "#FF6600"},
						{"offset": 1.0, "color": "#33000000"}
					]
				}
			}
		"spark":
			return {
				"amount": 24, "lifetime": 0.4, "one_shot": true, "explosiveness": 1.0, "emitting": false,
				"material": {
					"direction": {"x": 0, "y": 0, "z": 0}, "spread": 180.0,
					"initial_velocity_min": 200.0, "initial_velocity_max": 500.0,
					"gravity": {"x": 0, "y": 200, "z": 0},
					"scale_min": 0.5, "scale_max": 1.0, "scale_curve": "fade_out",
					"color": "#FFEE88"
				}
			}
		"fire":
			return {
				"amount": 24, "lifetime": 0.8, "one_shot": false, "explosiveness": 0.0,
				"material": {
					"direction": {"x": 0, "y": -1, "z": 0}, "spread": 15.0,
					"initial_velocity_min": 40.0, "initial_velocity_max": 80.0,
					"gravity": {"x": 0, "y": -30, "z": 0},
					"scale_min": 1.0, "scale_max": 2.0, "scale_curve": "fade_out",
					"color": "#FF6600",
					"color_ramp": [
						{"offset": 0.0, "color": "#FFEE44"},
						{"offset": 0.5, "color": "#FF4400"},
						{"offset": 1.0, "color": "#22000000"}
					]
				}
			}
		"smoke":
			return {
				"amount": 16, "lifetime": 1.5, "one_shot": false, "explosiveness": 0.0,
				"material": {
					"direction": {"x": 0, "y": -1, "z": 0}, "spread": 25.0,
					"initial_velocity_min": 20.0, "initial_velocity_max": 50.0,
					"gravity": {"x": 0, "y": -10, "z": 0},
					"scale_min": 2.0, "scale_max": 4.0, "scale_curve": "fade_in",
					"damping_min": 5.0, "damping_max": 10.0,
					"color": "#88888866"
				}
			}
		"trail":
			return {
				"amount": 16, "lifetime": 0.5, "one_shot": false, "explosiveness": 0.0,
				"material": {
					"direction": {"x": 0, "y": 1, "z": 0}, "spread": 5.0,
					"initial_velocity_min": 10.0, "initial_velocity_max": 30.0,
					"gravity": {"x": 0, "y": 0, "z": 0},
					"scale_min": 0.5, "scale_max": 1.0, "scale_curve": "fade_out",
					"color": "#44AAFF"
				}
			}
		"blood":
			return {
				"amount": 20, "lifetime": 0.5, "one_shot": true, "explosiveness": 0.9, "emitting": false,
				"material": {
					"direction": {"x": 0, "y": 0, "z": 0}, "spread": 120.0,
					"initial_velocity_min": 80.0, "initial_velocity_max": 200.0,
					"gravity": {"x": 0, "y": 300, "z": 0},
					"scale_min": 0.8, "scale_max": 1.5,
					"color": "#CC0022"
				}
			}
		"confetti":
			return {
				"amount": 40, "lifetime": 2.0, "one_shot": true, "explosiveness": 0.8, "emitting": false,
				"material": {
					"direction": {"x": 0, "y": -1, "z": 0}, "spread": 60.0,
					"initial_velocity_min": 100.0, "initial_velocity_max": 250.0,
					"gravity": {"x": 0, "y": 150, "z": 0},
					"angular_velocity_min": -200.0, "angular_velocity_max": 200.0,
					"scale_min": 0.5, "scale_max": 1.5,
					"hue_variation_min": -0.5, "hue_variation_max": 0.5,
					"color": "#FF44AA"
				}
			}
		"dust":
			return {
				"amount": 8, "lifetime": 1.0, "one_shot": false, "explosiveness": 0.0,
				"material": {
					"direction": {"x": 0, "y": -1, "z": 0}, "spread": 30.0,
					"initial_velocity_min": 5.0, "initial_velocity_max": 15.0,
					"gravity": {"x": 0, "y": 0, "z": 0},
					"scale_min": 0.3, "scale_max": 0.6, "scale_curve": "pulse",
					"color": "#AAAAAA44"
				}
			}
		"muzzle_flash":
			return {
				"amount": 12, "lifetime": 0.15, "one_shot": true, "explosiveness": 1.0, "emitting": false,
				"material": {
					"direction": {"x": 0, "y": -1, "z": 0}, "spread": 30.0,
					"initial_velocity_min": 100.0, "initial_velocity_max": 200.0,
					"gravity": {"x": 0, "y": 0, "z": 0},
					"scale_min": 0.8, "scale_max": 1.5, "scale_curve": "fade_out",
					"color": "#FFEE88"
				}
			}
		"heal":
			return {
				"amount": 16, "lifetime": 1.0, "one_shot": true, "explosiveness": 0.3, "emitting": false,
				"material": {
					"direction": {"x": 0, "y": -1, "z": 0}, "spread": 45.0,
					"initial_velocity_min": 30.0, "initial_velocity_max": 80.0,
					"gravity": {"x": 0, "y": -20, "z": 0},
					"scale_min": 0.5, "scale_max": 1.0, "scale_curve": "fade_out",
					"color": "#44FF88"
				}
			}
	return {}


# ---------------------------------------------------------------------------
# emit_particles
# ---------------------------------------------------------------------------
func _emit_particles(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var node_path: String = args.get("node_path", "")
	var node := root.get_node_or_null(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)

	var do_emit: bool = args.get("emitting", true)
	var restart: bool = args.get("restart", false)

	if node is GPUParticles2D:
		if restart:
			(node as GPUParticles2D).restart()
		(node as GPUParticles2D).emitting = do_emit
	elif node is GPUParticles3D:
		if restart:
			(node as GPUParticles3D).restart()
		(node as GPUParticles3D).emitting = do_emit
	else:
		return _error("Not a particle node: %s" % node_path)

	var action: String = "restarted" if restart else ("started" if do_emit else "stopped")
	return _success("Particles %s: %s" % [action, node_path])


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _get_edited_root() -> Node:
	var ei := EditorInterface
	if ei:
		return ei.get_edited_scene_root()
	return null
