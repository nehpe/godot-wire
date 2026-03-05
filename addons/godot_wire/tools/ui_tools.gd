@tool
extends GodotWireTool

## UI tools — create and configure Control nodes, anchors, themes, HUD layers


func get_tools() -> Array:
	return [
		{
			"name": "create_ui_element",
			"description": "Create a UI Control node (Label, Button, TextureRect, ProgressBar, Panel, etc.) with text, styling, and anchor preset in one call.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {"type": "string", "description": "Path to parent node"},
					"name": {"type": "string", "description": "Node name"},
					"type": {"type": "string", "description": "'label', 'button', 'texture_rect', 'progress_bar', 'panel', 'color_rect', 'nine_patch_rect', 'rich_text_label'"},
					"text": {"type": "string", "description": "Text content (for Label, Button, RichTextLabel)"},
					"texture": {"type": "string", "description": "Texture path for TextureRect/NinePatchRect"},
					"anchor_preset": {"type": "string", "description": "'full_rect', 'center', 'top_left', 'top_right', 'bottom_left', 'bottom_right', 'center_left', 'center_right', 'center_top', 'center_bottom', 'top_wide', 'bottom_wide', 'left_wide', 'right_wide'"},
					"position": {"type": "object", "description": "{x, y} position offset"},
					"size": {"type": "object", "description": "{x, y} custom minimum size"},
					"font_size": {"type": "integer", "description": "Font size override"},
					"color": {"type": "string", "description": "Font/modulate color as hex (#RRGGBB)"},
					"alignment": {"type": "string", "description": "'left', 'center', 'right' for Label/Button"},
					"min_value": {"type": "number", "description": "Min value for ProgressBar (default: 0)"},
					"max_value": {"type": "number", "description": "Max value for ProgressBar (default: 100)"},
					"value": {"type": "number", "description": "Current value for ProgressBar"}
				},
				"required": ["parent_path", "name", "type"]
			}
		},
		{
			"name": "set_anchor_preset",
			"description": "Apply an anchor preset to a Control node. Sets anchors, offsets, and grow direction for common layouts.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to the Control node"},
					"preset": {"type": "string", "description": "'full_rect', 'center', 'top_left', 'top_right', 'bottom_left', 'bottom_right', 'center_left', 'center_right', 'center_top', 'center_bottom', 'top_wide', 'bottom_wide', 'left_wide', 'right_wide'"},
					"margin": {"type": "number", "description": "Uniform margin/padding from edges (default: 0)"}
				},
				"required": ["node_path", "preset"]
			}
		},
		{
			"name": "set_theme_overrides",
			"description": "Apply theme overrides to a Control node — font size, colors, margins, styles. Much easier than setting individual properties.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to the Control node"},
					"font_size": {"type": "integer", "description": "Font size override"},
					"font_color": {"type": "string", "description": "Font color as hex (#RRGGBB)"},
					"font_outline_color": {"type": "string", "description": "Outline color as hex"},
					"font_outline_size": {"type": "integer", "description": "Outline thickness in pixels"},
					"font_shadow_color": {"type": "string", "description": "Shadow color as hex"},
					"font_shadow_offset": {"type": "object", "description": "{x, y} shadow offset"},
					"bg_color": {"type": "string", "description": "Background color (creates StyleBoxFlat)"},
					"corner_radius": {"type": "integer", "description": "Corner radius for background"},
					"padding": {"type": "object", "description": "{left, top, right, bottom} content margins"}
				},
				"required": ["node_path"]
			}
		},
		{
			"name": "create_container",
			"description": "Create a layout container (HBox, VBox, Grid, Margin, Center) with spacing and alignment options.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {"type": "string", "description": "Path to parent node"},
					"name": {"type": "string", "description": "Container name"},
					"type": {"type": "string", "description": "'hbox', 'vbox', 'grid', 'margin', 'center', 'panel'"},
					"anchor_preset": {"type": "string", "description": "Anchor preset (see set_anchor_preset)"},
					"separation": {"type": "integer", "description": "Spacing between children (for HBox/VBox/Grid)"},
					"columns": {"type": "integer", "description": "Number of columns (for Grid, default: 2)"},
					"margin_left": {"type": "integer", "description": "Left margin (for Margin container)"},
					"margin_top": {"type": "integer", "description": "Top margin"},
					"margin_right": {"type": "integer", "description": "Right margin"},
					"margin_bottom": {"type": "integer", "description": "Bottom margin"}
				},
				"required": ["parent_path", "name", "type"]
			}
		},
		{
			"name": "create_hud_layer",
			"description": "Create a CanvasLayer for HUD/UI overlay with configurable layer index.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {"type": "string", "description": "Path to parent node (usually '.' for scene root)"},
					"name": {"type": "string", "description": "Layer name (e.g. 'HUD', 'BossUI', 'PauseMenu')"},
					"layer": {"type": "integer", "description": "Canvas layer index (default: 10, higher = on top)"},
					"follow_viewport": {"type": "boolean", "description": "Follow viewport transforms (default: true)"}
				},
				"required": ["parent_path", "name"]
			}
		},
		{
			"name": "create_health_bar",
			"description": "Create a complete health bar with background, fill, and optional label — ready to use. Returns the ProgressBar node path.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {"type": "string", "description": "Path to parent node"},
					"name": {"type": "string", "description": "Health bar name"},
					"width": {"type": "number", "description": "Bar width in pixels (default: 200)"},
					"height": {"type": "number", "description": "Bar height in pixels (default: 20)"},
					"max_value": {"type": "number", "description": "Maximum health value (default: 100)"},
					"fill_color": {"type": "string", "description": "Fill color as hex (default: '#44FF44')"},
					"bg_color": {"type": "string", "description": "Background color as hex (default: '#333333')"},
					"border_color": {"type": "string", "description": "Border color as hex (default: '#FFFFFF')"},
					"show_label": {"type": "boolean", "description": "Show HP text label (default: false)"},
					"position": {"type": "object", "description": "{x, y} position"}
				},
				"required": ["parent_path", "name"]
			}
		}
	]


func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"create_ui_element":
			return _create_ui_element(args)
		"set_anchor_preset":
			return _set_anchor_preset(args)
		"set_theme_overrides":
			return _set_theme_overrides(args)
		"create_container":
			return _create_container(args)
		"create_hud_layer":
			return _create_hud_layer(args)
		"create_health_bar":
			return _create_health_bar(args)
	return _error("Unknown tool: %s" % tool_name)


# ---------------------------------------------------------------------------
# create_ui_element
# ---------------------------------------------------------------------------
func _create_ui_element(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var parent_path: String = args.get("parent_path", ".")
	var parent := root.get_node_or_null(parent_path) if parent_path != "." else root
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var node_name: String = args.get("name", "UIElement")
	var ui_type: String = args.get("type", "label")

	var node: Control
	match ui_type:
		"label":
			var lbl := Label.new()
			lbl.text = args.get("text", "")
			var align_str: String = args.get("alignment", "left")
			match align_str:
				"center": lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				"right": lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				_: lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			node = lbl
		"button":
			var btn := Button.new()
			btn.text = args.get("text", "Button")
			node = btn
		"texture_rect":
			var tex_rect := TextureRect.new()
			var tex_path: String = args.get("texture", "")
			if tex_path != "":
				var tex := load(tex_path)
				if tex:
					tex_rect.texture = tex
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			node = tex_rect
		"progress_bar":
			var bar := ProgressBar.new()
			bar.min_value = args.get("min_value", 0.0)
			bar.max_value = args.get("max_value", 100.0)
			bar.value = args.get("value", bar.max_value)
			bar.show_percentage = false
			node = bar
		"panel":
			node = Panel.new()
		"color_rect":
			var cr := ColorRect.new()
			if args.has("color"):
				cr.color = Color.from_string(args["color"], Color.WHITE)
			node = cr
		"nine_patch_rect":
			var np := NinePatchRect.new()
			var tex_path2: String = args.get("texture", "")
			if tex_path2 != "":
				var tex := load(tex_path2)
				if tex:
					np.texture = tex
			node = np
		"rich_text_label":
			var rtl := RichTextLabel.new()
			rtl.bbcode_enabled = true
			rtl.text = args.get("text", "")
			node = rtl
		_:
			return _error("Unknown UI type: %s" % ui_type)

	node.name = node_name

	# Apply common properties
	if args.has("size"):
		var sz: Dictionary = args["size"]
		node.custom_minimum_size = Vector2(sz.get("x", 0), sz.get("y", 0))

	if args.has("font_size"):
		node.add_theme_font_size_override("font_size", args["font_size"])

	if args.has("color"):
		if node is Label or node is Button or node is RichTextLabel:
			node.add_theme_color_override("font_color", Color.from_string(args["color"], Color.WHITE))
		else:
			node.modulate = Color.from_string(args["color"], Color.WHITE)

	# Add to scene
	var undo := plugin.get_undo_redo()
	undo.create_action("Create UI: %s" % node_name)
	undo.add_do_method(parent, "add_child", node)
	undo.add_do_method(node, "set_owner", root)
	undo.add_do_reference(node)
	undo.add_undo_method(parent, "remove_child", node)
	undo.commit_action()

	# Apply anchor preset after adding to tree
	if args.has("anchor_preset"):
		_apply_anchor_preset(node, args["anchor_preset"], 0)

	# Apply position after anchors
	if args.has("position"):
		var pos: Dictionary = args["position"]
		node.position = Vector2(pos.get("x", 0), pos.get("y", 0))

	return _success("Created %s '%s' at %s" % [ui_type, node_name, parent.get_path()])


# ---------------------------------------------------------------------------
# set_anchor_preset
# ---------------------------------------------------------------------------
func _set_anchor_preset(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var node_path: String = args.get("node_path", "")
	var node := root.get_node_or_null(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)
	if not (node is Control):
		return _error("Not a Control node: %s" % node_path)

	var preset: String = args.get("preset", "top_left")
	var margin: float = args.get("margin", 0.0)

	_apply_anchor_preset(node as Control, preset, margin)

	return _success("Applied anchor preset '%s' to %s" % [preset, node_path])


func _apply_anchor_preset(ctrl: Control, preset: String, margin: float) -> void:
	match preset:
		"full_rect":
			ctrl.anchor_left = 0; ctrl.anchor_top = 0
			ctrl.anchor_right = 1; ctrl.anchor_bottom = 1
			ctrl.offset_left = margin; ctrl.offset_top = margin
			ctrl.offset_right = -margin; ctrl.offset_bottom = -margin
		"center":
			ctrl.anchor_left = 0.5; ctrl.anchor_top = 0.5
			ctrl.anchor_right = 0.5; ctrl.anchor_bottom = 0.5
			ctrl.offset_left = -ctrl.size.x / 2; ctrl.offset_top = -ctrl.size.y / 2
			ctrl.offset_right = ctrl.size.x / 2; ctrl.offset_bottom = ctrl.size.y / 2
		"top_left":
			ctrl.anchor_left = 0; ctrl.anchor_top = 0
			ctrl.anchor_right = 0; ctrl.anchor_bottom = 0
			ctrl.offset_left = margin; ctrl.offset_top = margin
		"top_right":
			ctrl.anchor_left = 1; ctrl.anchor_top = 0
			ctrl.anchor_right = 1; ctrl.anchor_bottom = 0
			ctrl.offset_right = -margin; ctrl.offset_top = margin
		"bottom_left":
			ctrl.anchor_left = 0; ctrl.anchor_top = 1
			ctrl.anchor_right = 0; ctrl.anchor_bottom = 1
			ctrl.offset_left = margin; ctrl.offset_bottom = -margin
		"bottom_right":
			ctrl.anchor_left = 1; ctrl.anchor_top = 1
			ctrl.anchor_right = 1; ctrl.anchor_bottom = 1
			ctrl.offset_right = -margin; ctrl.offset_bottom = -margin
		"center_top":
			ctrl.anchor_left = 0.5; ctrl.anchor_top = 0
			ctrl.anchor_right = 0.5; ctrl.anchor_bottom = 0
			ctrl.offset_top = margin
		"center_bottom":
			ctrl.anchor_left = 0.5; ctrl.anchor_top = 1
			ctrl.anchor_right = 0.5; ctrl.anchor_bottom = 1
			ctrl.offset_bottom = -margin
		"center_left":
			ctrl.anchor_left = 0; ctrl.anchor_top = 0.5
			ctrl.anchor_right = 0; ctrl.anchor_bottom = 0.5
			ctrl.offset_left = margin
		"center_right":
			ctrl.anchor_left = 1; ctrl.anchor_top = 0.5
			ctrl.anchor_right = 1; ctrl.anchor_bottom = 0.5
			ctrl.offset_right = -margin
		"top_wide":
			ctrl.anchor_left = 0; ctrl.anchor_top = 0
			ctrl.anchor_right = 1; ctrl.anchor_bottom = 0
			ctrl.offset_left = margin; ctrl.offset_top = margin
			ctrl.offset_right = -margin
		"bottom_wide":
			ctrl.anchor_left = 0; ctrl.anchor_top = 1
			ctrl.anchor_right = 1; ctrl.anchor_bottom = 1
			ctrl.offset_left = margin; ctrl.offset_bottom = -margin
			ctrl.offset_right = -margin
		"left_wide":
			ctrl.anchor_left = 0; ctrl.anchor_top = 0
			ctrl.anchor_right = 0; ctrl.anchor_bottom = 1
			ctrl.offset_left = margin; ctrl.offset_top = margin
			ctrl.offset_bottom = -margin
		"right_wide":
			ctrl.anchor_left = 1; ctrl.anchor_top = 0
			ctrl.anchor_right = 1; ctrl.anchor_bottom = 1
			ctrl.offset_right = -margin; ctrl.offset_top = margin
			ctrl.offset_bottom = -margin


# ---------------------------------------------------------------------------
# set_theme_overrides
# ---------------------------------------------------------------------------
func _set_theme_overrides(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var node_path: String = args.get("node_path", "")
	var node := root.get_node_or_null(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)
	if not (node is Control):
		return _error("Not a Control node: %s" % node_path)

	var ctrl := node as Control
	var changes: Array = []

	if args.has("font_size"):
		ctrl.add_theme_font_size_override("font_size", args["font_size"])
		changes.append("font_size=%d" % args["font_size"])

	if args.has("font_color"):
		ctrl.add_theme_color_override("font_color", Color.from_string(args["font_color"], Color.WHITE))
		changes.append("font_color")

	if args.has("font_outline_color"):
		ctrl.add_theme_color_override("font_outline_color", Color.from_string(args["font_outline_color"], Color.BLACK))
		changes.append("outline_color")

	if args.has("font_outline_size"):
		ctrl.add_theme_constant_override("outline_size", args["font_outline_size"])
		changes.append("outline_size=%d" % args["font_outline_size"])

	if args.has("font_shadow_color"):
		ctrl.add_theme_color_override("font_shadow_color", Color.from_string(args["font_shadow_color"], Color.BLACK))
		changes.append("shadow_color")

	if args.has("font_shadow_offset"):
		var off: Dictionary = args["font_shadow_offset"]
		ctrl.add_theme_constant_override("shadow_offset_x", int(off.get("x", 2)))
		ctrl.add_theme_constant_override("shadow_offset_y", int(off.get("y", 2)))
		changes.append("shadow_offset")

	if args.has("bg_color"):
		var style := StyleBoxFlat.new()
		style.bg_color = Color.from_string(args["bg_color"], Color(0.2, 0.2, 0.2))
		if args.has("corner_radius"):
			var r: int = args["corner_radius"]
			style.corner_radius_top_left = r
			style.corner_radius_top_right = r
			style.corner_radius_bottom_left = r
			style.corner_radius_bottom_right = r
		if args.has("padding"):
			var pad: Dictionary = args["padding"]
			style.content_margin_left = pad.get("left", 0)
			style.content_margin_top = pad.get("top", 0)
			style.content_margin_right = pad.get("right", 0)
			style.content_margin_bottom = pad.get("bottom", 0)
		# Apply to the most common style name
		if ctrl is Button:
			ctrl.add_theme_stylebox_override("normal", style)
		elif ctrl is Panel or ctrl is ProgressBar:
			ctrl.add_theme_stylebox_override("panel", style)
		else:
			ctrl.add_theme_stylebox_override("normal", style)
		changes.append("bg_color")

	return _success("Theme overrides applied: %s" % ", ".join(changes))


# ---------------------------------------------------------------------------
# create_container
# ---------------------------------------------------------------------------
func _create_container(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var parent_path: String = args.get("parent_path", ".")
	var parent := root.get_node_or_null(parent_path) if parent_path != "." else root
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var node_name: String = args.get("name", "Container")
	var cont_type: String = args.get("type", "vbox")

	var node: Container
	match cont_type:
		"hbox":
			var hb := HBoxContainer.new()
			if args.has("separation"):
				hb.add_theme_constant_override("separation", args["separation"])
			node = hb
		"vbox":
			var vb := VBoxContainer.new()
			if args.has("separation"):
				vb.add_theme_constant_override("separation", args["separation"])
			node = vb
		"grid":
			var gr := GridContainer.new()
			gr.columns = args.get("columns", 2)
			if args.has("separation"):
				gr.add_theme_constant_override("h_separation", args["separation"])
				gr.add_theme_constant_override("v_separation", args["separation"])
			node = gr
		"margin":
			var mc := MarginContainer.new()
			mc.add_theme_constant_override("margin_left", args.get("margin_left", 10))
			mc.add_theme_constant_override("margin_top", args.get("margin_top", 10))
			mc.add_theme_constant_override("margin_right", args.get("margin_right", 10))
			mc.add_theme_constant_override("margin_bottom", args.get("margin_bottom", 10))
			node = mc
		"center":
			node = CenterContainer.new()
		"panel":
			node = PanelContainer.new()
		_:
			return _error("Unknown container type: %s" % cont_type)

	node.name = node_name

	var undo := plugin.get_undo_redo()
	undo.create_action("Create container: %s" % node_name)
	undo.add_do_method(parent, "add_child", node)
	undo.add_do_method(node, "set_owner", root)
	undo.add_do_reference(node)
	undo.add_undo_method(parent, "remove_child", node)
	undo.commit_action()

	if args.has("anchor_preset"):
		_apply_anchor_preset(node, args["anchor_preset"], 0)

	return _success("Created %s container '%s' at %s" % [cont_type, node_name, parent.get_path()])


# ---------------------------------------------------------------------------
# create_hud_layer
# ---------------------------------------------------------------------------
func _create_hud_layer(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var parent_path: String = args.get("parent_path", ".")
	var parent := root.get_node_or_null(parent_path) if parent_path != "." else root
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var node_name: String = args.get("name", "HUDLayer")
	var layer_idx: int = args.get("layer", 10)
	var follow: bool = args.get("follow_viewport", true)

	var canvas := CanvasLayer.new()
	canvas.name = node_name
	canvas.layer = layer_idx
	canvas.follow_viewport_enabled = follow

	var undo := plugin.get_undo_redo()
	undo.create_action("Create HUD layer: %s" % node_name)
	undo.add_do_method(parent, "add_child", canvas)
	undo.add_do_method(canvas, "set_owner", root)
	undo.add_do_reference(canvas)
	undo.add_undo_method(parent, "remove_child", canvas)
	undo.commit_action()

	return _success("Created CanvasLayer '%s' at layer %d" % [node_name, layer_idx])


# ---------------------------------------------------------------------------
# create_health_bar
# ---------------------------------------------------------------------------
func _create_health_bar(args: Dictionary) -> Dictionary:
	var root := _get_edited_root()
	if root == null:
		return _error("No scene open")

	var parent_path: String = args.get("parent_path", ".")
	var parent := root.get_node_or_null(parent_path) if parent_path != "." else root
	if parent == null:
		return _error("Parent not found: %s" % parent_path)

	var bar_name: String = args.get("name", "HealthBar")
	var bar_width: float = args.get("width", 200.0)
	var bar_height: float = args.get("height", 20.0)
	var max_val: float = args.get("max_value", 100.0)
	var fill_color_str: String = args.get("fill_color", "#44FF44")
	var bg_color_str: String = args.get("bg_color", "#333333")
	var border_color_str: String = args.get("border_color", "#FFFFFF")
	var show_label: bool = args.get("show_label", false)

	# Create container
	var container := Control.new()
	container.name = bar_name
	container.custom_minimum_size = Vector2(bar_width, bar_height)

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color.from_string(bg_color_str, Color(0.2, 0.2, 0.2))
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0

	# Border (slightly larger)
	var border := ColorRect.new()
	border.name = "Border"
	border.color = Color.from_string(border_color_str, Color.WHITE)
	border.anchor_right = 1.0
	border.anchor_bottom = 1.0
	border.offset_left = -1; border.offset_top = -1
	border.offset_right = 1; border.offset_bottom = 1

	# Progress bar
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.min_value = 0
	bar.max_value = max_val
	bar.value = max_val
	bar.show_percentage = false
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 2; bar.offset_top = 2
	bar.offset_right = -2; bar.offset_bottom = -2

	# Style the fill
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color.from_string(fill_color_str, Color(0.2, 1.0, 0.2))
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("background", bg_style)

	# Add to scene with undo
	var undo := plugin.get_undo_redo()
	undo.create_action("Create health bar: %s" % bar_name)
	undo.add_do_method(parent, "add_child", container)
	undo.add_do_method(container, "set_owner", root)
	undo.add_do_reference(container)
	undo.add_undo_method(parent, "remove_child", container)

	undo.add_do_method(container, "add_child", border)
	undo.add_do_method(border, "set_owner", root)
	undo.add_do_reference(border)

	undo.add_do_method(container, "add_child", bg)
	undo.add_do_method(bg, "set_owner", root)
	undo.add_do_reference(bg)

	undo.add_do_method(container, "add_child", bar)
	undo.add_do_method(bar, "set_owner", root)
	undo.add_do_reference(bar)

	if show_label:
		var lbl := Label.new()
		lbl.name = "Label"
		lbl.text = "%d / %d" % [int(max_val), int(max_val)]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		lbl.add_theme_font_size_override("font_size", int(bar_height * 0.7))
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 2)
		undo.add_do_method(container, "add_child", lbl)
		undo.add_do_method(lbl, "set_owner", root)
		undo.add_do_reference(lbl)

	undo.commit_action()

	# Position
	if args.has("position"):
		var pos: Dictionary = args["position"]
		container.position = Vector2(pos.get("x", 0), pos.get("y", 0))

	return _success("Created health bar '%s' (%dx%d, max=%d) at %s" % [bar_name, int(bar_width), int(bar_height), int(max_val), parent.get_path()])


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _get_edited_root() -> Node:
	var ei := EditorInterface
	if ei:
		return ei.get_edited_scene_root()
	return null
