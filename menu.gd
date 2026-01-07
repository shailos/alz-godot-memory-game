extends Control

# UI Elements
@onready var memory_game_label: Label
@onready var start_button: Button

func _ready():
	print("MENU READY running")
	# Ensure root Control fills the screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_background()
	_setup_ui()

func _setup_background():
	"""Setup sky blue background color matching the game"""
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.8, 0.95)  # Sky blue background (same as game)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	move_child(panel, 0)  # Move to back

func _setup_ui():
	"""Setup UI elements: Memory Game label and Start Game button"""
	# Hide/remove pre-existing UI elements
	var instruction_label = get_node_or_null("InstructionLabel")
	if instruction_label:
		instruction_label.visible = false
	
	var existing_vbox = get_node_or_null("VBoxContainer")
	if existing_vbox:
		for child in existing_vbox.get_children():
			child.visible = false
	
	var old_start_button = get_node_or_null("StartButton")
	if old_start_button:
		old_start_button.visible = false

	# ---- PERFECT CENTERING ----
	# 1) Create a full-screen CenterContainer
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 2) Put your VBox inside the CenterContainer
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 30)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.alignment = BoxContainer.ALIGNMENT_CENTER  # centers children inside VBox too
	center.add_child(container)

	# Create "Memory Game" label
	memory_game_label = Label.new()
	memory_game_label.text = "Memory Garden"
	memory_game_label.add_theme_font_size_override("font_size", 80)
	memory_game_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
	memory_game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memory_game_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	memory_game_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	memory_game_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(memory_game_label)

	# Create Start button
	start_button = Button.new()
	start_button.name = "StartButton"
	start_button.text = "Begin"
	start_button.custom_minimum_size = Vector2(150, 50)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(_on_start_button_pressed)
	container.add_child(start_button)

	_style_start_button()

func _style_start_button():
	"""Style the start button with pastel colors"""
	if not start_button:
		return
	
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.9, 0.85, 0.95)
	style_box.border_color = Color(0.7, 0.6, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	start_button.add_theme_stylebox_override("normal", style_box)
	
	var hover_style := style_box.duplicate()
	hover_style.bg_color = hover_style.bg_color.lightened(0.1)
	start_button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := style_box.duplicate()
	pressed_style.bg_color = pressed_style.bg_color.darkened(0.1)
	start_button.add_theme_stylebox_override("pressed", pressed_style)
	
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))

func _on_start_button_pressed():
	"""Start the Memory Game (Module 1: Object Memory / Episodic Memory)"""
	get_tree().change_scene_to_file("res://main.tscn")
