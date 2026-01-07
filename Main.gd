# ============================================================================
# Cognitive Memory Game - Object Location Memory Task (Module 1)
# ============================================================================
# Project: Cognitive Engagement Game for Alzheimer's & Dementia
# Purpose: Interactive memory game focusing on object-location recall
#          Designed as a cognitive engagement tool with advanced adaptive difficulty
# 
# Game Mechanics:
#   1. Study Phase: Player views objects placed in a 3x3 grid
#   2. Quiz Phase: Player recalls where each object was located
#   3. Adaptive Difficulty: Automatically adjusts based on THREE factors:
#      - Accuracy (primary): Score performance
#      - Response Time (secondary): Speed of answers
#      - Frequency of Play (tertiary): Session frequency
#
# Design Principles:
#   - Accessibility: Large buttons, high contrast, minimal text
#   - Low Pressure: Encouraging feedback, no penalties
#   - Adaptive: Difficulty adjusts smoothly based on multiple factors
#   - Visual Engagement: Calm color palette, styled buttons
#   - Distractors: Visually similar objects to test recognition (per RFC Module 1)
#
# Technical Notes:
#   - Built with Godot 4 and GDScript
#   - Uses Node2D as base, CanvasLayer for UI
#   - State machine pattern: intro -> study -> quiz -> done
#   - Dynamic UI generation for grid buttons with visual styling
#   - Response time tracking for adaptive difficulty
#   - Session frequency tracking for engagement-based adaptation
# ============================================================================

extends Node2D

# UI Element References - Using @onready for automatic initialization
# NOTE: NextButton should be positioned below the Grid in the scene hierarchy for proper layout
@onready var canvas_layer = $CanvasLayer
@onready var ui_container = $CanvasLayer/UI
@onready var vbox = $CanvasLayer/UI/MarginContainer/VBoxContainer
@onready var instruction_label: Label = $CanvasLayer/UI/MarginContainer/VBoxContainer/InstructionLabel
@onready var feedback_label: Label = $CanvasLayer/UI/MarginContainer/VBoxContainer/FeedbackLabel
@onready var next_button: Button = $CanvasLayer/UI/MarginContainer/NextButton
@onready var grid: GridContainer = $CanvasLayer/UI/MarginContainer/VBoxContainer/CenterContainer/Grid
@onready var center_container: CenterContainer = $CanvasLayer/UI/MarginContainer/VBoxContainer/CenterContainer

# Pause, Reset, and Quit buttons (created dynamically)
var pause_button: Button = null
var reset_button: Button = null
var quit_button: Button = null
var is_paused := false
var pause_overlay: Panel = null  # Pause screen overlay
# End of session buttons (created dynamically)
var return_to_menu_button: Button = null
var continue_button: Button = null

# Game Configuration Constants
const GRID_SIZE := 9  # 3x3 grid for object placement
const COLS := 3        # Grid columns (used for layout)

# Game State Variables
var phase := "intro"  # State machine: "intro", "study", "quiz", "done"
var objects := []     # Current round's objects (dynamically selected)
var positions := {}   # Dictionary mapping object_name -> cell_index
var quiz_index := 0   # Current question index in quiz phase
var score := 0        # Correct answers in current round
var round_number := 0 # Total rounds completed (for tracking)
# Removed pulse_timer - intro screen now handled by menu

# Response Time Tracking (for adaptive difficulty)
var question_start_time := 0.0
var response_times := []  # Store response times for current round

# Frequency of Play Tracking (for adaptive difficulty)
var sessions_today := 0
var last_session_date := ""  # Store date as string (YYYY-MM-DD format)
var total_sessions := 0

# --- Adaptive difficulty state (no UI levels shown) ---
var difficulty := 0.0  # floats make it smoother; clamp 0..1
var last_accuracy := 0.0
var last_avg_time := 0.0  # Average response time in seconds
var consecutive_poor_performance := 0  # Track consecutive rounds with poor performance
var consecutive_good_performance := 0  # Track consecutive rounds with good performance

# Research-Aligned Enhancement Variables
# Delayed Recall: Store object-location pairs from previous rounds (episodic memory research)
# Research foundation: Longer delays (≥3 days) are more sensitive than immediate recall
var previous_round_objects := {}  # Dictionary: object_name -> cell_index from previous rounds
var accuracy_history := []  # Track accuracy for fatigue detection (low-pressure daily engagement research)
var caregiver_assist_bias := 0.0  # Internal bias for difficulty adjustment (-0.2 to +0.2, user-centered design)
var round1_objects := {}  # Store Round 1 object-location pairs specifically for delayed recall
var current_round_has_delayed_recall := false  # Track if current round includes delayed recall question
var delayed_recall_objects := []  # Track which objects from Round 1 will be tested in Round 3 delayed recall
var round3_delayed_recall_index := -1  # Track which question in Round 3 is the delayed recall (Part A)

# Object pool organized by similarity groups for distractors (per RFC Module 1)
# Objects in same group are visually/conceptually similar to create recognition challenges
var objects_pool := [
	"Apple", "Banana", "Bread", "Egg", "Milk",
	"Cup", "Spoon", "Plate", "Bowl", "Glass",
	"Key", "Book", "Hat", "Shoe", "Sock",
	"Phone", "Ring", "Pen", "Watch", "Bag"
]

# Similarity groups for distractor selection (objects that might be confused)
# Expanded groups to allow Round 2 semantic similarity testing with adaptive difficulty increases
var object_groups := {
	"fruit": ["Apple", "Banana"],  # 2 objects (food category)
	"food": ["Bread", "Egg", "Milk", "Apple", "Banana"],  # Expanded: 5 objects (food category)
	"containers": ["Cup", "Bowl", "Glass", "Plate"],  # Expanded: 4 objects (container/utensil category)
	"utensils": ["Spoon", "Plate", "Cup", "Bowl"],  # Expanded: 4 objects (kitchen items)
	"clothing": ["Hat", "Shoe", "Sock", "Bag"],  # Expanded: 4 objects (wearable items)
	"small_items": ["Key", "Ring", "Pen", "Watch"],  # Expanded: 4 objects (small personal items)
	"personal": ["Phone", "Watch", "Bag", "Ring", "Pen"],  # Expanded: 5 objects (personal belongings)
	"reading": ["Book", "Pen", "Phone"]  # Expanded: 3 objects (items used for information/reading)
}

# Emoji mapping for colorful visual representation
# Research: Visual memory is often more robust than verbal memory, especially for dementia patients
# Colorful emojis provide visual cues that are easier to remember than text alone
var object_emojis := {
	"Apple": "🍎",
	"Banana": "🍌",
	"Bread": "🍞",
	"Egg": "🥚",
	"Milk": "🥛",
	"Cup": "☕",
	"Spoon": "🥄",
	"Plate": "🍽️",
	"Bowl": "🥣",
	"Glass": "🥤",
	"Key": "🔑",
	"Book": "📖",
	"Hat": "🧢",
	"Shoe": "👟",
	"Sock": "🧦",
	"Phone": "📱",
	"Ring": "💍",
	"Pen": "✏️",
	"Watch": "⌚",
	"Bag": "👜"
}

# how many objects per round depends on difficulty
var min_objects := 3
var max_objects := 7  # keep under GRID_SIZE for now

# Adaptive Difficulty System
# Difficulty ranges from 0.0 (easiest) to 1.0 (hardest)
# Controls number of objects shown: min_objects (easy) to max_objects (hard)
var study_seconds := 3.0  # Reserved for future timer feature

# ============================================================================
# INITIALIZATION
# ============================================================================

# Removed intro phase pulsing animation - menu now handles intro screen

func _get_object_emoji(object_name: String) -> String:
	"""Get emoji for an object, returns empty string if not found"""
	return object_emojis.get(object_name, "")

func _show_intro():
	"""Display the game introduction screen"""
	phase = "intro"
	instruction_label.text = "Memory Game"
	feedback_label.text = ""
	feedback_label.visible = false
	instruction_label.visible = true
	
	# Style the intro text: bigger, positioned above button
	if instruction_label:
		instruction_label.add_theme_font_size_override("font_size", 120)  # Much bigger text
		instruction_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))  # Dark text
		instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Position text above button with proper spacing
		instruction_label.custom_minimum_size = Vector2(0, 250)  # Proper spacing above button

	if next_button:
		next_button.visible = true
		next_button.text = "Begin"

	if grid:
		grid.visible = false


func _ready():
	"""Initialize the game: build UI, connect signals, show intro screen"""
	# Setup pastel background
	_setup_pastel_background()
	
	# Build the dynamic grid of buttons
	_build_grid_buttons()
	
	# Create pause and quit buttons (top right, small squares)
	_create_top_buttons()
	
	# Create pause overlay (hidden initially)
	_create_pause_overlay()
	
	# Move NextButton below the grid (reparent to VBoxContainer after CenterContainer)
	if next_button and vbox:
		var current_parent = next_button.get_parent()
		if current_parent != vbox:
			# Remove from current parent
			current_parent.remove_child(next_button)
			# Add to VBoxContainer
			vbox.add_child(next_button)
			# Move to be after CenterContainer (which contains the grid)
			var center_container = vbox.get_node_or_null("CenterContainer")
			if center_container:
				var center_index = center_container.get_index()
				vbox.move_child(next_button, center_index + 1)
	
	# Style the next button (smaller, not full width, pastel)
	_style_next_button()
	
	# Load saved progress
	_load_progress()
	
	# Initialize frequency tracking
	_update_session_tracking()
	
	# Setup instruction label styling (bigger, centered text, darker for visibility)
	if instruction_label:
		instruction_label.add_theme_font_size_override("font_size", 36)  # Larger text
		instruction_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))  # Much darker text for better visibility
		instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Add more spacing from top by setting custom minimum size (adds space)
		instruction_label.custom_minimum_size = Vector2(0, 120)  # Extra vertical space to move down from edge
	
	# Add spacing to VBoxContainer to push everything down
	if vbox:
		vbox.add_theme_constant_override("separation", 20)  # Add spacing between elements
	
	# Setup feedback label styling (bigger, centered text, darker for visibility)
	if feedback_label:
		feedback_label.add_theme_font_size_override("font_size", 32)  # Larger text (will be overridden to 48 in _finish)
		feedback_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))  # Much darker text for better visibility
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Ensure label has proper width to prevent vertical stacking
		feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Connect the Next button signal with error prevention
	# Disconnect first to prevent duplicate connections during development
	if next_button:
		if next_button.pressed.is_connected(_on_next_pressed):
			next_button.pressed.disconnect(_on_next_pressed)
		next_button.pressed.connect(_on_next_pressed)
	else:
		push_error("NextButton not found — check scene tree path")

	# Skip intro screen - go directly to first round (menu now handles intro)
	_start_round_prep()




# ============================================================================
# ADAPTIVE DIFFICULTY SYSTEM
# ============================================================================

func _clamp01(x: float) -> float:
	"""Utility function to clamp values between 0.0 and 1.0"""
	return max(0.0, min(1.0, x))

func _desired_object_count() -> int:
	"""
	Calculate how many objects to show based on current difficulty.
	Uses linear interpolation: difficulty 0.0 = min_objects, 1.0 = max_objects
	"""
	var t := _clamp01(difficulty)
	return int(round(lerp(float(min_objects), float(max_objects), t)))

func _pick_objects_for_round():
	"""
	Select objects based on structured round roles (research-aligned):
	
	Round 1: Baseline Episodic Memory - Highly distinct objects from different semantic categories
	Research: Establishes baseline object-location memory, reduces anxiety, tests hippocampal engagement
	
	Round 2: Semantic Similarity & Recognition Errors - Objects from same semantic category
	Research: Tests perirhinal cortex function, semantic false alarms (confusing similar objects)
	
	Round 3: Delayed Recall & Fatigue Awareness - Normal objects (delayed recall handled separately)
	Research: Tests longer-delay episodic memory, memory consolidation across rounds
	
	This structured approach aligns with Gallery Game research and episodic memory vulnerability findings.
	"""
	var n := _desired_object_count()
	# Debug: Print desired count for verification
	print("_pick_objects_for_round: Round ", round_number, ", difficulty=", difficulty, ", desired_count=", n)
	objects.clear()
	current_round_has_delayed_recall = false
	delayed_recall_objects = []
	round3_delayed_recall_index = -1
	
	if round_number == 1:
		# Round 1: Baseline Episodic Memory (Confidence & Orientation)
		# Objects are highly distinct from different semantic categories
		# Research: Episodic memory is vulnerable early; starting easy reduces anxiety
		# Example: Apple (food), Key (tool), Hat (clothing)
		# Implementation: Pick one object from each semantic group to ensure distinct categories
		objects.clear()
		var used_groups := []  # Track which groups we've used to avoid duplicates
		var available_groups := object_groups.keys()
		available_groups.shuffle()
		
		# Pick one object from each distinct semantic category
		for group_name in available_groups:
			if objects.size() >= n:
				break
			var group_objects: Array = object_groups[group_name]
			if group_objects.size() > 0:
				group_objects.shuffle()
				objects.append(group_objects[0])
				used_groups.append(group_name)
		
		# If we need more objects than available groups, fill from remaining pool
		if objects.size() < n:
			var remaining := objects_pool.duplicate()
			for obj in objects:
				remaining.erase(obj)
			remaining.shuffle()
			objects.append_array(remaining.slice(0, min(n - objects.size(), remaining.size())))
		
		# Round 1 objects will be stored in _finish() for Round 3 delayed recall
		
	elif round_number == 2:
		# Round 2: Semantic Similarity & Recognition Errors
		# Objects come from the same semantic category (e.g., Apple, Banana - both fruits)
		# Research: Tests perirhinal cortex function, susceptibility to semantic false alarms
		# This round directly aligns with Gallery Game findings
		# CRITICAL: ALL objects must be from the SAME semantic category for valid testing
		objects.clear()
		
		if object_groups.size() > 0:
			# Find semantic groups that have enough objects for the desired count
			var group_keys := object_groups.keys()
			group_keys.shuffle()
			
			var selected_group: String = ""
			var selected_objects: Array = []
			
			# Try to find a group with enough objects (prefer groups with exactly n or more)
			for group_name in group_keys:
				var group_objects: Array = object_groups[group_name]
				if group_objects.size() >= n:
					selected_group = group_name
					selected_objects = group_objects.duplicate()
					selected_objects.shuffle()
					# Use exactly n objects from this group
					objects = selected_objects.slice(0, n)
					print("Round 2: Using ", n, " objects from semantic group '", group_name, "' (difficulty-based count)")
					break
			
			# If no group has enough objects, use the largest available group
			if objects.size() == 0:
				var largest_group: String = ""
				var largest_size: int = 0
				for group_name in group_keys:
					var group_objects: Array = object_groups[group_name]
					if group_objects.size() > largest_size:
						largest_size = group_objects.size()
						largest_group = group_name
				
				if largest_group != "":
					selected_group = largest_group
					selected_objects = object_groups[largest_group].duplicate()
					selected_objects.shuffle()
					# Use all objects from this group (may be less than n, but ensures semantic similarity)
					# Note: If difficulty increases and n > group size, we'll use the group size
					# This is acceptable for Round 2 as semantic similarity testing is prioritized
					var actual_count: int = min(n, selected_objects.size())
					objects = selected_objects.slice(0, actual_count)
					print("Round 2: Using ", actual_count, " objects from semantic group '", largest_group, "' (desired was ", n, ")")
			
			# Ensure we have at least 3 objects (minimum for valid testing)
			if objects.size() < 3:
				push_warning("Round 2: Selected semantic group has fewer than 3 objects. Using all available: " + str(objects))
		else:
			# Fallback: if no groups defined, create a temporary similar group
			# This should not happen if object_groups is properly defined
			push_error("Round 2: No semantic groups defined! Cannot test semantic similarity.")
			var temp := objects_pool.duplicate()
			temp.shuffle()
			objects = temp.slice(0, n)
			
	else:
		# Round 3+: Normal recall with current objects
		# Round 3 Part A (delayed recall) is handled separately in quiz flow
		# Round 3 Part B uses normal objects from current round
		# Research: Tests delayed recall from Round 1, then continues with normal recall
		var temp := objects_pool.duplicate()
		temp.shuffle()
		objects = temp.slice(0, n)
		
		# Round 3: Set up delayed recall from Round 1 (Part A)
		# This will be asked as the FIRST question in Round 3
		if round_number == 3 and round1_objects.size() > 0:
			var round1_object_keys := round1_objects.keys()
			round1_object_keys.shuffle()
			if round1_object_keys.size() > 0:
				var delayed_obj: String = round1_object_keys[0]
				delayed_recall_objects = [delayed_obj]
				round3_delayed_recall_index = 0  # First question is delayed recall
				current_round_has_delayed_recall = true

func _update_session_tracking():
	"""Track frequency of play for adaptive difficulty"""
	var current_date := Time.get_date_string_from_system()
	
	if last_session_date != current_date:
		# New day - reset daily counter
		sessions_today = 1
		last_session_date = current_date
	else:
		# Same day - increment counter
		sessions_today += 1
	
	total_sessions += 1

func _update_difficulty_from_round():
	"""
	Update adaptive difficulty based on THREE factors (per RFC):
	1. Accuracy - primary driver
	2. Response time - faster responses suggest easier difficulty
	3. Frequency of play - more sessions = gradual increase
	
	Called after each round completes. Adjusts difficulty smoothly.
	"""
	var total: int = objects.size()
	if total < 1:
		total = 1  # Prevent division by zero

	# Factor 1: Calculate accuracy as percentage
	var acc: float = float(score) / float(total)
	last_accuracy = acc

	# Factor 2: Calculate average response time
	var avg_time := 0.0
	if response_times.size() > 0:
		var total_time := 0.0
		for time in response_times:
			total_time += time
		avg_time = total_time / float(response_times.size())
		last_avg_time = avg_time
	
	# Normalize response time (0-10 seconds range, faster = higher value)
	# Slower than 10s = easier, faster than 3s = harder
	var time_factor := 0.0
	if avg_time > 0.0:
		var normalized_time: float = clamp(avg_time / 10.0, 0.0, 1.0)
		time_factor = (1.0 - normalized_time) * 0.3  # Up to 0.3 influence

	# Factor 3: Frequency of play (more sessions = slight difficulty increase)
	# Multiple sessions per day suggests engagement, can handle slightly more challenge
	var frequency_factor := 0.0
	if sessions_today >= 3:
		frequency_factor = 0.05  # Slight boost for frequent players
	elif sessions_today >= 2:
		frequency_factor = 0.02
	
	# Combined adaptive difficulty algorithm with dynamic level dropping
	# If user performs poorly (< 40%), difficulty drops to level below after 2 consecutive poor rounds
	# Once they perform well again (>= 60%), difficulty increases back up after 2 consecutive good rounds
	# This provides a more responsive and supportive difficulty adjustment
	# Research: Supports user-centered design - difficulty adapts to current performance state
	
	var accuracy_adjustment := 0.0
	
	# Determine performance level and track consecutive rounds
	if acc >= 0.60:  # Good performance (60% or higher)
		consecutive_good_performance += 1
		consecutive_poor_performance = 0  # Reset poor performance counter
		
		# After 2 consecutive good rounds, raise difficulty by one level
		if consecutive_good_performance >= 2:
			accuracy_adjustment = 0.20  # Increase by one object level (3→4→5→...→9)
			consecutive_good_performance = 0  # Reset after raising
			print("Difficulty: Raising level after 2 consecutive good rounds (accuracy >= 60%)")
	elif acc < 0.40:  # Poor performance (below 40%)
		consecutive_poor_performance += 1
		consecutive_good_performance = 0  # Reset good performance counter
		
		# After 2 consecutive poor rounds, drop difficulty by one level
		if consecutive_poor_performance >= 2:
			accuracy_adjustment = -0.20  # Decrease by one object level
			consecutive_poor_performance = 0  # Reset after dropping
			print("Difficulty: Dropping level after 2 consecutive poor rounds (accuracy < 40%)")
	else:  # Moderate performance (40-60%)
		# Reset both counters - moderate performance doesn't trigger changes
		consecutive_poor_performance = 0
		consecutive_good_performance = 0
		accuracy_adjustment = 0.0  # Keep difficulty the same
	
	# Research Enhancement: Caregiver Assist Bias (user-centered design research)
	# Research foundation: One-size-fits-all does not work; dementia severity varies widely
	# Internal variable allows subtle difficulty adjustment without exposing to user
	# Bias ranges from -0.2 (easier) to +0.2 (more challenging), defaults to 0.0
	var clamped_bias: float = clamp(caregiver_assist_bias, -0.2, 0.2)
	var bias_adjustment: float = clamped_bias
	
	# Apply all factors (including caregiver bias)
	var old_difficulty := difficulty
	difficulty += accuracy_adjustment + time_factor + frequency_factor + bias_adjustment
	
	# Clamp difficulty to valid range
	difficulty = _clamp01(difficulty)
	
	# Debug: Print difficulty update for verification
	print("Difficulty update - Round ", round_number, ": accuracy=", acc, " old_diff=", old_difficulty, " new_diff=", difficulty, " obj_count=", _desired_object_count())

	# Optional: Adjust study time based on difficulty (reserved for future use)
	study_seconds = lerp(4.0, 2.0, difficulty)
	
	# Clear response times for next round
	response_times.clear()








# ============================================================================
# UI GENERATION
# ============================================================================

func _build_grid_buttons():
	"""
	Dynamically generate the 3x3 grid of buttons with visual styling.
	Each button is created programmatically and connected to the cell press handler.
	Large button size (160x160) ensures accessibility for all users.
	Enhanced with colors for visual engagement (calm, accessible palette).
	"""
	# Clear any existing buttons (important for reinitialization)
	for c in grid.get_children():
		c.queue_free()

	# Calm, accessible color palette - darker pastels for better visibility
	var button_colors := [
		Color(0.65, 0.72, 0.75),  # Darker muted blue
		Color(0.70, 0.65, 0.70),  # Darker muted purple
		Color(0.72, 0.70, 0.65),  # Darker muted beige
		Color(0.68, 0.72, 0.68),  # Darker muted green
		Color(0.75, 0.68, 0.68),  # Darker muted pink
		Color(0.70, 0.70, 0.72),  # Darker muted gray
		Color(0.73, 0.73, 0.65),  # Darker muted yellow
		Color(0.68, 0.68, 0.73),  # Darker muted lavender
		Color(0.72, 0.68, 0.72)   # Darker muted rose
	]

	# Create buttons for each grid cell
	for i in range(GRID_SIZE):
		var b := Button.new()
		b.name = "Cell_%d" % i
		
		# Accessibility: Large buttons for easy tapping (slightly smaller)
		b.custom_minimum_size = Vector2(140, 140)
		b.add_theme_font_size_override("font_size", 22)
		
		# Visual styling: Apply calm colors for visual engagement
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = button_colors[i % button_colors.size()]
		style_box.border_color = Color(0.3, 0.3, 0.35)
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		
		b.add_theme_stylebox_override("normal", style_box)
		
		# Hover/pressed states
		var hover_style := style_box.duplicate()
		hover_style.bg_color = hover_style.bg_color.lightened(0.1)
		b.add_theme_stylebox_override("hover", hover_style)
		
		var pressed_style := style_box.duplicate()
		pressed_style.bg_color = pressed_style.bg_color.darkened(0.1)
		b.add_theme_stylebox_override("pressed", pressed_style)
		
		b.text = ""  # Text will be set via child labels, not button.text
		
		# Create a VBoxContainer inside the button for emoji and text
		var vbox := VBoxContainer.new()
		vbox.name = "Content"
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)
		b.add_child(vbox)
		
		# Create label for emoji (large) - will be populated during study phase
		var emoji_label := Label.new()
		emoji_label.name = "EmojiLabel"
		emoji_label.text = ""
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_label.add_theme_font_size_override("font_size", 64)  # Large emoji
		emoji_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(emoji_label)
		
		# Create label for text (smaller) - will be populated during study phase
		var text_label := Label.new()
		text_label.name = "TextLabel"
		text_label.text = ""
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		text_label.add_theme_font_size_override("font_size", 20)  # Smaller text
		text_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))  # Dark text
		text_label.size_flags_vertical = Control.SIZE_SHRINK_END
		vbox.add_child(text_label)
		
		# Connect signal using lambda to capture cell index
		b.pressed.connect(func(): _on_cell_pressed(i))
		grid.add_child(b)



# ============================================================================
# GAME FLOW CONTROL
# ============================================================================

func _start_round_prep():
	"""Show grid with objects and instructions, ready for Start Quiz"""
	round_number += 1
	_update_session_tracking()  # Track play frequency
	_pick_objects_for_round()  # Select objects based on adaptive difficulty
	_assign_positions()
	
	# Reset feedback label styling (restore horizontal layout)
	feedback_label.visible = false
	feedback_label.text = ""
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Expand horizontally to prevent vertical stacking
	feedback_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	feedback_label.add_theme_font_size_override("font_size", 32)
	feedback_label.custom_minimum_size = Vector2(0, 0)
	
	# Reset instruction label to match first round styling (exact same as initial setup)
	instruction_label.visible = true
	instruction_label.text = "Remember where each object is placed"
	instruction_label.add_theme_font_size_override("font_size", 36)  # Reset to normal size
	instruction_label.custom_minimum_size = Vector2(0, 100)  # Same spacing as first round
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Don't modify size flags - keep default to maintain exact same position
	
	# Reset VBoxContainer separation to normal (for study/quiz phase)
	if vbox:
		vbox.add_theme_constant_override("separation", 20)  # Normal spacing for study/quiz phase
	
	# Show grid with objects
	grid.visible = true
	_show_study_board()
	
	phase = "study"
	quiz_index = 0
	score = 0
	response_times.clear()  # Reset response time tracking
	next_button.visible = true
	next_button.text = "Start Quiz"

func _start_round():
	"""Initialize a new round: called after Move On (shows grid directly)"""
	_start_round_prep()

func _assign_positions():
	"""
	Randomly assign objects to grid positions.
	Uses shuffled array to ensure unique, random placement.
	"""
	positions.clear()
	var available := []
	for i in range(GRID_SIZE):
		available.append(i)

	available.shuffle()  # Randomize position order
	for j in range(objects.size()):
		positions[objects[j]] = available[j]

func _show_study_board():
	"""
	Display objects on the grid for the study phase.
	All buttons are disabled to prevent interaction during study.
	Restores pastel colors for consistent visual design.
	"""
	# Restore pastel colors for study phase (ensures consistency)
	_restore_pastel_colors()
	
	# Clear all buttons first
	for i in range(GRID_SIZE):
		var b: Button = grid.get_child(i)
		b.disabled = true  # Prevent clicking during study
		b.text = ""
		# Clear child labels if they exist
		var vbox = b.get_node_or_null("Content")
		if vbox:
			var emoji_label = vbox.get_node_or_null("EmojiLabel")
			var text_label = vbox.get_node_or_null("TextLabel")
			if emoji_label:
				emoji_label.text = ""
			if text_label:
				text_label.text = ""

	# Place objects on their assigned cells with emoji and text
	# Research: Visual memory is often more robust than verbal memory, especially for dementia patients
	# Colorful emojis provide visual cues that are easier to remember than text alone
	for obj in objects:
		var idx = positions[obj]
		var btn: Button = grid.get_child(idx)
		var emoji = _get_object_emoji(obj)
		
		# Get the child labels (created in _build_grid_buttons)
		var vbox = btn.get_node_or_null("Content")
		if vbox:
			var emoji_label = vbox.get_node_or_null("EmojiLabel")
			var text_label = vbox.get_node_or_null("TextLabel")
			
			if emoji != "":
				# Set emoji in large label and text in smaller label
				if emoji_label:
					emoji_label.text = emoji
				if text_label:
					text_label.text = obj
			else:
				# Fallback: show text in emoji label if no emoji
				if emoji_label:
					emoji_label.text = obj
					emoji_label.add_theme_font_size_override("font_size", 32)  # Medium size for text-only
				if text_label:
					text_label.text = ""
		else:
			# Fallback if structure doesn't exist
			btn.text = obj if emoji == "" else emoji + "\n" + obj

func _restore_pastel_colors():
	"""
	Restore grid button styles to pastel colors for study phase.
	Ensures consistent color scheme throughout the game.
	"""
	# Calm, accessible color palette - darker pastels for better visibility
	var button_colors := [
		Color(0.65, 0.72, 0.75),  # Darker muted blue
		Color(0.70, 0.65, 0.70),  # Darker muted purple
		Color(0.72, 0.70, 0.65),  # Darker muted beige
		Color(0.68, 0.72, 0.68),  # Darker muted green
		Color(0.75, 0.68, 0.68),  # Darker muted pink
		Color(0.70, 0.70, 0.72),  # Darker muted gray
		Color(0.73, 0.73, 0.65),  # Darker muted yellow
		Color(0.68, 0.68, 0.73),  # Darker muted lavender
		Color(0.72, 0.68, 0.72)   # Darker muted rose
	]
	
	for i in range(GRID_SIZE):
		var b: Button = grid.get_child(i)
		
		# Restore pastel colors
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = button_colors[i % button_colors.size()]
		style_box.border_color = Color(0.3, 0.3, 0.35)
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		b.add_theme_stylebox_override("normal", style_box)
		
		var hover_style := style_box.duplicate()
		hover_style.bg_color = hover_style.bg_color.lightened(0.1)
		b.add_theme_stylebox_override("hover", hover_style)
		
		var pressed_style := style_box.duplicate()
		pressed_style.bg_color = pressed_style.bg_color.darkened(0.1)
		b.add_theme_stylebox_override("pressed", pressed_style)

func _reset_grid_styles():
	"""
	Reset grid button styles to dark gray/black for quiz phase.
	"""
	for i in range(GRID_SIZE):
		var b: Button = grid.get_child(i)
		
		# Dark gray/black style for quiz phase (same as study board)
		var quiz_style := StyleBoxFlat.new()
		quiz_style.bg_color = Color(0.3, 0.3, 0.35)  # Dark gray
		quiz_style.border_color = Color(0.4, 0.4, 0.45)
		quiz_style.border_width_left = 2
		quiz_style.border_width_right = 2
		quiz_style.border_width_top = 2
		quiz_style.border_width_bottom = 2
		quiz_style.corner_radius_top_left = 8
		quiz_style.corner_radius_top_right = 8
		quiz_style.corner_radius_bottom_left = 8
		quiz_style.corner_radius_bottom_right = 8
		b.add_theme_stylebox_override("normal", quiz_style)
		
		var hover_style := quiz_style.duplicate()
		hover_style.bg_color = hover_style.bg_color.lightened(0.1)
		b.add_theme_stylebox_override("hover", hover_style)
		
		var pressed_style := quiz_style.duplicate()
		pressed_style.bg_color = pressed_style.bg_color.darkened(0.1)
		b.add_theme_stylebox_override("pressed", pressed_style)
		
		# Reset text color to white for visibility on dark background
		b.add_theme_color_override("font_color", Color.WHITE)

func _hide_board():
	"""
	Clear the grid for quiz phase - objects are hidden, buttons become interactive.
	"""
	_reset_grid_styles()  # Reset styles before quiz
	
	# Clear all object names - grid should be empty during quiz
	for i in range(GRID_SIZE):
		var b: Button = grid.get_child(i)
		b.text = ""  # Clear object names
		# Clear child labels if they exist
		var vbox = b.get_node_or_null("Content")
		if vbox:
			var emoji_label = vbox.get_node_or_null("EmojiLabel")
			var text_label = vbox.get_node_or_null("TextLabel")
			if emoji_label:
				emoji_label.text = ""
			if text_label:
				text_label.text = ""
		b.disabled = false  # Enable clicking for quiz

func _start_quiz():
	"""
	Transition from study phase to quiz phase.
	Hides objects, enables grid interaction, starts first question.
	"""
	phase = "quiz"
	feedback_label.text = ""
	next_button.visible = false  # Hide until answer is selected
	_hide_board()
	_ask_current_question()

func _ask_current_question():
	"""
	Display the current quiz question asking player to locate an object.
	Round 3 Part A: Uses delayed recall question from Round 1 with special phrasing.
	Round 3 Part B: Uses normal questions from current round objects.
	Starts response time tracking for adaptive difficulty.
	"""
	# Round 3 Part A: First question is delayed recall from Round 1
	# Research: Tests longer-delay episodic memory, memory consolidation across rounds
	if round_number == 3 and quiz_index == 0 and delayed_recall_objects.size() > 0:
		var delayed_obj: String = delayed_recall_objects[0]
		# Research: Delayed recall phrasing - "Do you remember where the [object] was earlier?"
		# This tests episodic memory consolidation across rounds (Round 1 → Round 3)
		instruction_label.text = "Do you remember where the " + delayed_obj.to_lower() + " was earlier?"
	else:
		# Normal question: Use current round objects
		# Round 3 Part B: After delayed recall (quiz_index 0), continue with normal questions
		# Adjust index: if Round 3 with delayed recall, quiz_index 1+ maps to objects[quiz_index-1]
		var obj_index := quiz_index
		if round_number == 3 and delayed_recall_objects.size() > 0:
			# Round 3: quiz_index 0 was delayed recall, so quiz_index 1+ maps to objects[0+]
			obj_index = quiz_index - 1
		
		if obj_index >= 0 and obj_index < objects.size():
			var obj = objects[obj_index]
			instruction_label.text = "Where was the " + obj.to_lower() + "?"
		else:
			# Fallback (shouldn't happen)
			instruction_label.text = "Where was the object?"
	
	# Start tracking response time for this question
	question_start_time = Time.get_ticks_msec() / 1000.0

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _on_cell_pressed(cell_index: int):
	"""
	Handle player's grid cell selection during quiz phase.
	Compares selection to correct answer, tracks response time, provides feedback.
	Includes research-aligned enhancements: delayed recall handling and recognition error support.
	"""
	if is_paused:
		return  # Ignore input when paused
	if phase != "quiz":
		return  # Only process input during quiz phase

	# Research Enhancement: Delayed Recall Handling (episodic memory research)
	# Round 3 Part A: Use Round 1 location for delayed recall question
	# Round 3 Part B: Use current round location for normal questions
	var obj: String
	var correct_index: int
	
	if round_number == 3 and quiz_index == 0 and delayed_recall_objects.size() > 0:
		# Round 3 Part A: Delayed recall from Round 1
		# Research: Tests longer-delay episodic memory, memory consolidation
		obj = delayed_recall_objects[0]
		if obj in round1_objects:
			correct_index = round1_objects[obj]  # Use location from Round 1 (baseline)
		else:
			correct_index = positions.get(obj, 0)  # Fallback
	else:
		# Normal question: Use current round objects
		# Round 3 Part B: After delayed recall, use normal objects
		# Adjust index: if Round 3 with delayed recall, quiz_index 1+ maps to objects[quiz_index-1]
		var obj_index := quiz_index
		if round_number == 3 and delayed_recall_objects.size() > 0:
			# Round 3: quiz_index 0 was delayed recall, so quiz_index 1+ maps to objects[0+]
			obj_index = quiz_index - 1
		
		if obj_index >= 0 and obj_index < objects.size():
			obj = objects[obj_index]
			correct_index = positions[obj]  # Use current round location
		else:
			# Fallback (shouldn't happen)
			obj = objects[0] if objects.size() > 0 else ""
			correct_index = positions.get(obj, 0)
	
	# Calculate and store response time for adaptive difficulty
	var response_time := (Time.get_ticks_msec() / 1000.0) - question_start_time
	response_times.append(response_time)

	# Lock all buttons to prevent multiple selections
	for i in range(GRID_SIZE):
		grid.get_child(i).disabled = true

	# Show correct answer location visually (gentle feedback)
	# Highlight correct cell with visual indicator and display the object
	var correct_btn: Button = grid.get_child(correct_index)
	var style_box := correct_btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if style_box:
		style_box.border_color = Color(0.2, 0.7, 0.3)  # Green border for correct
		style_box.border_width_left = 4
		style_box.border_width_right = 4
		style_box.border_width_top = 4
		style_box.border_width_bottom = 4
		correct_btn.add_theme_stylebox_override("normal", style_box)
	
	# Display the correct object on the correct cell
	var emoji = _get_object_emoji(obj)
	var vbox = correct_btn.get_node_or_null("Content")
	if vbox:
		var emoji_label = vbox.get_node_or_null("EmojiLabel")
		var text_label = vbox.get_node_or_null("TextLabel")
		
		if emoji != "":
			# Set emoji in large label and text in smaller label
			if emoji_label:
				emoji_label.text = emoji
			if text_label:
				text_label.text = obj
		else:
			# Fallback: show text in emoji label if no emoji
			if emoji_label:
				emoji_label.text = obj
				emoji_label.add_theme_font_size_override("font_size", 32)  # Medium size for text-only
			if text_label:
				text_label.text = ""

	# Research Enhancement: Recognition Error Handling (semantic false alarms research)
	# Check if player selected location of a semantically similar object (same semantic group)
	# Research: Perirhinal cortex research - semantic false alarms indicate recognition errors
	var is_semantic_similar_selection := false
	# Semantic similarity check applies to Round 2 (all objects from same category)
	# Round 3 Part B questions can also benefit from this check if they use similar objects
	if cell_index != correct_index and (round_number == 2 or (round_number == 3 and quiz_index > 0)):
		# Round 2 or Round 3 Part B: Check if selected location contains an object from same semantic group as target
		var target_obj: String = obj
		var selected_obj_in_position := ""
		
		# Find which object (if any) was at the selected position in study phase
		for obj_name in positions:
			if positions[obj_name] == cell_index:
				selected_obj_in_position = obj_name
				break
		
		# Special case: In Round 2, ALL objects are from the same semantic category
		# So any wrong answer selecting another object's location is by definition a semantic similarity error
		if round_number == 2 and selected_obj_in_position != "":
			is_semantic_similar_selection = true
		elif selected_obj_in_position != "" and selected_obj_in_position != target_obj:
			# Round 3 Part B: Check if selected object shares a semantic group with target
			# Find semantic groups for both objects (an object can be in multiple groups)
			var target_groups := []
			var selected_groups := []
			
			for group_name in object_groups:
				if target_obj in object_groups[group_name]:
					target_groups.append(group_name)
				if selected_obj_in_position in object_groups[group_name]:
					selected_groups.append(group_name)
			
			# If both objects share ANY semantic group, it's a semantic similarity error
			for group_name in target_groups:
				if group_name in selected_groups:
					is_semantic_similar_selection = true
					break  # Found a match, no need to check further
	
	# Provide encouraging feedback based on correctness
	# Research foundation: Low-pressure engagement, no penalties, gentle encouragement
	# Show feedback in instruction_label at top to prevent screen bouncing
	if cell_index == correct_index:
		score += 1
		if round_number == 3 and quiz_index == 0 and delayed_recall_objects.size() > 0:
			instruction_label.text = "That's wonderful! You remembered."
		else:
			instruction_label.text = "That's right! Well done."
	elif is_semantic_similar_selection:
		# Research Enhancement: Recognition Error Handling (semantic false alarms research)
		# Selected location of semantically similar object - provide specific gentle feedback
		# Research: Perirhinal cortex - semantic false alarms (confusing similar objects) are informative
		instruction_label.text = "You're close! Those were very similar."
	else:
		# Gentle, encouraging feedback - no penalty tone
		# Research Enhancement: Recognition Error Handling (semantic false alarms research)
		# Even incorrect answers receive neutral/encouraging feedback (perirhinal object recognition research)
		instruction_label.text = "That's okay. Let's try the next one."
	
	# Keep instruction label visible and feedback label hidden to prevent layout shifts
	instruction_label.visible = true
	feedback_label.visible = false
	feedback_label.text = ""
	
	# Show Next button to continue (keep consistent position, move up)
	next_button.visible = true
	next_button.text = "Next"
	# Ensure button stays in same position (don't let it expand or change size flags)
	next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Reduce spacing before button to move it up so it's clearly visible
	if vbox:
		vbox.add_theme_constant_override("separation", 10)  # Reduced spacing to move button up

func _on_next_pressed():
	"""
	Main state machine handler for the Next button.
	Routes to appropriate function based on current game phase.
	"""
	if is_paused:
		return  # Ignore input when paused (pause button handles unpause)
	# Intro phase removed - menu now handles intro screen
	
	if phase == "study":
		# "Start Quiz" clicked - study phase complete, start quiz
		_start_quiz()
		return

	if phase == "quiz":
		# Current question answered - advance to next or finish
		quiz_index += 1
		feedback_label.text = ""

		# Round 3: Has two parts - Part A (delayed recall) + Part B (normal questions)
		# Total questions = 1 (delayed recall) + objects.size() (normal questions)
		var total_questions: int = objects.size()
		if round_number == 3 and delayed_recall_objects.size() > 0:
			# Round 3 includes delayed recall question as first question
			total_questions = objects.size() + 1

		# Check if all questions answered
		if quiz_index >= total_questions:
			_finish()
			return
		
		# Round 3: After delayed recall (Part A, quiz_index 0), continue with normal questions (Part B)
		# The delayed recall question is index 0, so quiz_index 1+ uses normal objects

		# Reset button styles for next question
		_reset_grid_styles()

		# Clear all displayed objects from previous question to prevent repetition
		for i in range(GRID_SIZE):
			var b: Button = grid.get_child(i)
			b.text = ""  # Clear button text
			# Clear child labels if they exist
			var vbox = b.get_node_or_null("Content")
			if vbox:
				var emoji_label = vbox.get_node_or_null("EmojiLabel")
				var text_label = vbox.get_node_or_null("TextLabel")
				if emoji_label:
					emoji_label.text = ""
				if text_label:
					text_label.text = ""
			b.disabled = false  # Re-enable grid for next question

		next_button.visible = false
		_ask_current_question()
		return

	if phase == "done":
		# Round complete - start new round
		_start_round()
		return

func _finish():
	"""
	Complete the current round: update difficulty, show score and encouraging results.
	Includes research-aligned enhancements: delayed recall storage and fatigue-aware session ending.
	"""
	_update_difficulty_from_round()
	
	# Research Enhancement: Store objects for delayed recall (episodic memory research)
	# Round 1: Save specifically to round1_objects for guaranteed Round 3 delayed recall
	# Research: Episodic memory research - Round 1 baseline pairs are tested in Round 3
	if round_number == 1:
		for obj in objects:
			if obj in positions:
				round1_objects[obj] = positions[obj]
	
	# Also save to general previous_round_objects for broader tracking
	for obj in objects:
		if obj in positions:
			previous_round_objects[obj] = positions[obj]
	
	# Research Enhancement: Fatigue-Aware Session Ending (low-pressure daily engagement research)
	# Research foundation: Performance varies with context (fatigue, time of day, environment)
	# Track accuracy history and end session early if significant drop indicates fatigue
	var accuracy := float(score) / float(objects.size()) if objects.size() > 0 else 0.0
	accuracy_history.append(accuracy)
	
	# If accuracy drops significantly (fatigue detection), end session early
	# Compare current accuracy to average of previous rounds
	var should_end_early := false
	if accuracy_history.size() >= 2:
		var previous_avg := 0.0
		for i in range(accuracy_history.size() - 1):
			previous_avg += accuracy_history[i]
		previous_avg /= float(accuracy_history.size() - 1)
		
		# Significant drop (40% or more decrease) suggests fatigue
		if accuracy < previous_avg - 0.4 and accuracy < 0.3:
			should_end_early = true
	
	phase = "done"
	
	# Hide grid
	grid.visible = false
	
	# Show score at top
	var score_text := "Score: " + str(score) + " / " + str(objects.size())
	
	# Check if session should end (after 3 rounds OR fatigue detected)
	if round_number >= 3 or should_end_early:
		# Show score and friendly message in instruction_label to prevent screen bouncing
		instruction_label.visible = true
		feedback_label.visible = false
		# Context-aware message based on performance (using existing accuracy variable)
		var end_message := ""
		if accuracy >= 0.8:
			end_message = "You did wonderfully today!"
		elif accuracy >= 0.5:
			end_message = "You're doing great! Keep it up."
		else:
			end_message = "Thank you for playing with us today."
		instruction_label.text = score_text + "\n\n" + end_message
		# Make feedback label big, centered, positioned higher up
		feedback_label.add_theme_font_size_override("font_size", 52)  # Large text that fits on screen
		feedback_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))  # Dark text
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP  # Top alignment to move it up
		feedback_label.custom_minimum_size = Vector2(0, 0)  # Minimal spacing to position it higher
		feedback_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Don't expand vertically
		feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Expand horizontally
		# Hide the regular next button
		next_button.visible = false
		# Create Return to Menu and Continue buttons
		_create_end_session_buttons()
		# Increase spacing before buttons to move them lower
		if vbox:
			vbox.add_theme_constant_override("separation", 50)  # More spacing to move buttons lower
		return
	
	# Show feedback in instruction_label (top) to prevent screen bouncing
	instruction_label.visible = true
	feedback_label.visible = false
	# Context-aware message based on performance for mid-session rounds (using existing accuracy variable)
	var round_message := ""
	if accuracy >= 0.8:
		round_message = "Wonderful! You're doing really well."
	elif accuracy >= 0.5:
		round_message = "You're doing good! Keep going."
	else:
		round_message = "You're trying your best. That's what matters."
	instruction_label.text = score_text + "\n\n" + round_message
	# Make feedback label big, centered, positioned higher up
	feedback_label.add_theme_font_size_override("font_size", 52)  # Large text that fits on screen
	feedback_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))  # Dark text
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP  # Top alignment to move it up
	feedback_label.custom_minimum_size = Vector2(0, 0)  # Minimal spacing to position it higher
	feedback_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Don't expand vertically
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Expand horizontally
	# Move next_button to be after feedback_label (below text)
	if vbox and next_button.get_parent() == vbox:
		var feedback_index = feedback_label.get_index()
		var next_index = next_button.get_index()
		if next_index < feedback_index:
			vbox.move_child(next_button, feedback_index + 1)
	# Reduce spacing before button to move it higher
	if vbox:
		vbox.add_theme_constant_override("separation", 5)  # Reduce spacing between elements
	next_button.visible = true
	next_button.text = "Move On"

# ============================================================================
# SAVE/LOAD SYSTEM
# ============================================================================

func _save_progress():
	"""Save game progress to a config file (difficulty and round_number not saved - always start fresh)"""
	var config = ConfigFile.new()
	# Don't save difficulty or round_number - always start fresh with 3 objects (difficulty 0.0, round_number 0)
	# round_number is per-session, so it should reset to 0 at the start of each new session
	config.set_value("progress", "last_accuracy", last_accuracy)
	config.set_value("progress", "last_avg_time", last_avg_time)
	config.set_value("progress", "sessions_today", sessions_today)
	config.set_value("progress", "last_session_date", last_session_date)
	config.set_value("progress", "total_sessions", total_sessions)
	# round_number is NOT saved - it resets to 0 at the start of each new session
	
	var err = config.save("user://game_progress.cfg")
	if err != OK:
		push_error("Failed to save progress: " + str(err))
	else:
		print("Progress saved successfully")

func _load_progress():
	"""Load game progress from config file (difficulty always starts at 0.0 for 3 objects)"""
	var config = ConfigFile.new()
	var err = config.load("user://game_progress.cfg")
	
	# Always start with 3 objects (difficulty 0.0) - difficulty increases during session only
	# round_number also resets to 0 at start of each session (rounds are per-session, not cumulative)
	difficulty = 0.0
	round_number = 0  # Reset round number at start of each new session
	
	if err != OK:
		# No saved file exists, start fresh
		print("No saved progress found, starting fresh with 3 objects")
		return
	
	# Load saved values (except difficulty and round_number - always start at 0.0 and 0)
	last_accuracy = config.get_value("progress", "last_accuracy", 0.0)
	last_avg_time = config.get_value("progress", "last_avg_time", 0.0)
	sessions_today = config.get_value("progress", "sessions_today", 0)
	last_session_date = config.get_value("progress", "last_session_date", "")
	total_sessions = config.get_value("progress", "total_sessions", 0)
	# round_number is NOT loaded - it resets to 0 at the start of each new session
	
	print("Progress loaded - starting with 3 objects (difficulty and round_number reset each session)")

# ============================================================================
# UI STYLING AND BUTTONS
# ============================================================================

func _setup_pastel_background():
	"""Setup sky blue background color for the UI"""
	if ui_container:
		var panel := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.6, 0.8, 0.95)  # Sky blue background (darker than pastel)
		panel.add_theme_stylebox_override("panel", style)
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui_container.add_child(panel)
		ui_container.move_child(panel, 0)  # Move to back

func _create_top_buttons():
	"""Create small square pause and quit buttons in top right corner"""
	if not canvas_layer:
		return
	
	# Get viewport size for positioning
	var viewport_size := get_viewport().get_visible_rect().size
	
	# Create quit button (rightmost)
	quit_button = Button.new()
	quit_button.text = "🏠"  # House emoji
	quit_button.custom_minimum_size = Vector2(50, 50)
	quit_button.position = Vector2(viewport_size.x - 110, 10)
	
	var quit_style := StyleBoxFlat.new()
	quit_style.bg_color = Color(0.75, 0.5, 0.5)  # Darker muted pastel red
	quit_style.border_color = Color(0.6, 0.35, 0.35)
	quit_style.border_width_left = 2
	quit_style.border_width_right = 2
	quit_style.border_width_top = 2
	quit_style.border_width_bottom = 2
	quit_style.corner_radius_top_left = 8
	quit_style.corner_radius_top_right = 8
	quit_style.corner_radius_bottom_left = 8
	quit_style.corner_radius_bottom_right = 8
	quit_button.add_theme_stylebox_override("normal", quit_style)
	
	var quit_hover := quit_style.duplicate()
	quit_hover.bg_color = quit_hover.bg_color.lightened(0.1)
	quit_button.add_theme_stylebox_override("hover", quit_hover)
	
	quit_button.add_theme_font_size_override("font_size", 24)
	quit_button.pressed.connect(_on_quit_pressed)
	canvas_layer.add_child(quit_button)
	
	# Create pause button (leftmost)
	pause_button = Button.new()
	pause_button.text = "⏸"
	pause_button.custom_minimum_size = Vector2(50, 50)
	pause_button.position = Vector2(viewport_size.x - 230, 10)
	
	var pause_style := StyleBoxFlat.new()
	pause_style.bg_color = Color(0.5, 0.65, 0.75)  # Darker muted pastel blue
	pause_style.border_color = Color(0.35, 0.55, 0.65)
	pause_style.border_width_left = 2
	pause_style.border_width_right = 2
	pause_style.border_width_top = 2
	pause_style.border_width_bottom = 2
	pause_style.corner_radius_top_left = 8
	pause_style.corner_radius_top_right = 8
	pause_style.corner_radius_bottom_left = 8
	pause_style.corner_radius_bottom_right = 8
	pause_button.add_theme_stylebox_override("normal", pause_style)
	
	var pause_hover := pause_style.duplicate()
	pause_hover.bg_color = pause_hover.bg_color.lightened(0.1)
	pause_button.add_theme_stylebox_override("hover", pause_hover)
	
	pause_button.add_theme_font_size_override("font_size", 20)
	pause_button.pressed.connect(_on_pause_pressed)
	canvas_layer.add_child(pause_button)
	
	# Create reset button (between pause and quit)
	reset_button = Button.new()
	reset_button.text = "↻"  # Looped arrow symbol
	reset_button.custom_minimum_size = Vector2(50, 50)
	reset_button.position = Vector2(viewport_size.x - 170, 10)
	
	var reset_style := StyleBoxFlat.new()
	reset_style.bg_color = Color(0.75, 0.65, 0.5)  # Muted pastel orange
	reset_style.border_color = Color(0.65, 0.55, 0.4)
	reset_style.border_width_left = 2
	reset_style.border_width_right = 2
	reset_style.border_width_top = 2
	reset_style.border_width_bottom = 2
	reset_style.corner_radius_top_left = 8
	reset_style.corner_radius_top_right = 8
	reset_style.corner_radius_bottom_left = 8
	reset_style.corner_radius_bottom_right = 8
	reset_button.add_theme_stylebox_override("normal", reset_style)
	
	var reset_hover := reset_style.duplicate()
	reset_hover.bg_color = reset_hover.bg_color.lightened(0.1)
	reset_button.add_theme_stylebox_override("hover", reset_hover)
	
	reset_button.add_theme_font_size_override("font_size", 24)
	reset_button.pressed.connect(_on_reset_pressed)
	canvas_layer.add_child(reset_button)

func _create_end_session_buttons():
	"""Create Return to Menu and Continue buttons for end of session screen"""
	# Remove existing buttons if they exist
	if return_to_menu_button:
		return_to_menu_button.queue_free()
		return_to_menu_button = null
	if continue_button:
		continue_button.queue_free()
		continue_button = null
	
	if not vbox:
		return
	
	# Create HBoxContainer for the two buttons
	var button_container := HBoxContainer.new()
	button_container.name = "EndSessionButtons"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)  # Space between buttons
	
	# Create Return to Menu button
	return_to_menu_button = Button.new()
	return_to_menu_button.text = "Return to Main Menu"
	return_to_menu_button.custom_minimum_size = Vector2(180, 50)
	
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.75, 0.5, 0.5)  # Pastel red
	menu_style.border_color = Color(0.6, 0.35, 0.35)
	menu_style.border_width_left = 2
	menu_style.border_width_right = 2
	menu_style.border_width_top = 2
	menu_style.border_width_bottom = 2
	menu_style.corner_radius_top_left = 10
	menu_style.corner_radius_top_right = 10
	menu_style.corner_radius_bottom_left = 10
	menu_style.corner_radius_bottom_right = 10
	return_to_menu_button.add_theme_stylebox_override("normal", menu_style)
	
	var menu_hover := menu_style.duplicate()
	menu_hover.bg_color = menu_hover.bg_color.lightened(0.1)
	return_to_menu_button.add_theme_stylebox_override("hover", menu_hover)
	
	return_to_menu_button.add_theme_font_size_override("font_size", 18)
	return_to_menu_button.pressed.connect(_on_return_to_menu_pressed)
	button_container.add_child(return_to_menu_button)
	
	# Create Continue button
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(150, 50)
	
	var continue_style := StyleBoxFlat.new()
	continue_style.bg_color = Color(0.65, 0.55, 0.75)  # Pastel purple (same as next button)
	continue_style.border_color = Color(0.55, 0.45, 0.65)
	continue_style.border_width_left = 2
	continue_style.border_width_right = 2
	continue_style.border_width_top = 2
	continue_style.border_width_bottom = 2
	continue_style.corner_radius_top_left = 10
	continue_style.corner_radius_top_right = 10
	continue_style.corner_radius_bottom_left = 10
	continue_style.corner_radius_bottom_right = 10
	continue_button.add_theme_stylebox_override("normal", continue_style)
	
	var continue_hover := continue_style.duplicate()
	continue_hover.bg_color = continue_hover.bg_color.lightened(0.1)
	continue_button.add_theme_stylebox_override("hover", continue_hover)
	
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.pressed.connect(_on_continue_pressed)
	button_container.add_child(continue_button)
	
	# Add button container to vbox after feedback_label
	var feedback_index = feedback_label.get_index()
	vbox.add_child(button_container)
	vbox.move_child(button_container, feedback_index + 1)

func _on_return_to_menu_pressed():
	"""Handle Return to Main Menu button - save progress and return to menu"""
	_save_progress()
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_continue_pressed():
	"""Handle Continue button - continue playing with current difficulty (Round 4, 5, etc.)"""
	# Remove the end session buttons
	if return_to_menu_button:
		var button_container = return_to_menu_button.get_parent()
		if button_container and button_container.name == "EndSessionButtons":
			button_container.queue_free()
		return_to_menu_button = null
		continue_button = null
	
	# Continue with current difficulty - do NOT reset round_number or round1_objects
	# This allows players to continue playing Round 4, 5, etc. with same difficulty
	# round1_objects stays preserved for potential future delayed recall
	# accuracy_history stays preserved for continued fatigue tracking
	current_round_has_delayed_recall = false
	# Reset consecutive performance tracking for fresh start after session end
	consecutive_poor_performance = 0
	consecutive_good_performance = 0
	# Start next round (will be Round 4, 5, etc. based on current round_number)
	_start_round()

func _style_next_button():
	"""Style the next button to be smaller and pastel colored (not full width)"""
	if next_button:
		next_button.custom_minimum_size = Vector2(150, 50)  # Smaller, not full width
		next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.65, 0.55, 0.75)  # Darker muted pastel purple
		style.border_color = Color(0.55, 0.45, 0.65)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		next_button.add_theme_stylebox_override("normal", style)
		
		var hover_style := style.duplicate()
		hover_style.bg_color = hover_style.bg_color.lightened(0.1)
		next_button.add_theme_stylebox_override("hover", hover_style)
		
		next_button.add_theme_font_size_override("font_size", 20)

func _create_pause_overlay():
	"""Create pause screen overlay"""
	if pause_overlay:
		return
	
	if not canvas_layer:
		return
	
	# Create pause overlay panel (clickable to unpause)
	pause_overlay = Panel.new()
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.9, 0.88, 0.86, 0.95)  # Semi-transparent muted background
	pause_overlay.add_theme_stylebox_override("panel", overlay_style)
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	# Make pause overlay clickable to unpause
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Enable mouse input
	pause_overlay.gui_input.connect(_on_pause_overlay_clicked)
	canvas_layer.add_child(pause_overlay)
	
	# Create pause symbol label (⏸)
	var pause_label := Label.new()
	pause_label.text = "⏸"
	pause_label.add_theme_font_size_override("font_size", 120)  # Very large pause symbol
	pause_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))  # Much darker text for better visibility
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(pause_label)

func _on_pause_pressed():
	"""Toggle pause state (shows pause screen overlay)"""
	_toggle_pause()

func _on_pause_overlay_clicked(event: InputEvent):
	"""Handle click on pause overlay to unpause"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_pause()

func _toggle_pause():
	"""Toggle pause state (shows/hides pause screen overlay)"""
	is_paused = !is_paused
	
	# Create overlay if it doesn't exist
	if not pause_overlay:
		_create_pause_overlay()
	
	if is_paused:
		pause_button.text = "▶"
		if pause_overlay:
			pause_overlay.visible = true
	else:
		pause_button.text = "⏸"
		if pause_overlay:
			pause_overlay.visible = false

func _on_reset_pressed():
	"""Handle reset button - reset progress and go back to first round"""
	# Reset all progress
	difficulty = 0.0
	round_number = 0
	score = 0
	quiz_index = 0
	last_accuracy = 0.0
	last_avg_time = 0.0
	sessions_today = 0
	last_session_date = ""
	# Reset research-aligned enhancement variables
	previous_round_objects.clear()
	round1_objects.clear()  # Reset Round 1 objects for delayed recall
	accuracy_history.clear()
	current_round_has_delayed_recall = false
	total_sessions = 0
	response_times.clear()
	objects.clear()
	positions.clear()
	# Reset consecutive performance tracking
	consecutive_poor_performance = 0
	consecutive_good_performance = 0
	
	# Save the reset state
	_save_progress()
	
	# Go directly to first round (menu now handles intro)
	_start_round_prep()

func _on_quit_pressed():
	"""Handle quit button - save progress and return to menu screen"""
	_save_progress()
	# Return to menu screen
	get_tree().change_scene_to_file("res://menu.tscn")

