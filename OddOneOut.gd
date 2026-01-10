extends Node2D

# UI Element References - matching main.tscn structure exactly
@onready var canvas_layer = $CanvasLayer
@onready var ui_container = $CanvasLayer/UI
@onready var vbox = $CanvasLayer/UI/MarginContainer/VBoxContainer
@onready var instruction_label: Label = $CanvasLayer/UI/MarginContainer/VBoxContainer/InstructionLabel
@onready var feedback_label: Label = $CanvasLayer/UI/MarginContainer/VBoxContainer/FeedbackLabel
@onready var next_button: Button = $CanvasLayer/UI/MarginContainer/NextButton
@onready var grid: GridContainer = $CanvasLayer/UI/MarginContainer/VBoxContainer/CenterContainer/Grid

# Pause, Reset, and Quit buttons (created dynamically)
var pause_button: Button = null
var reset_button: Button = null
var quit_button: Button = null
var is_paused := false
var pause_overlay: Panel = null  # Pause screen overlay

# Game Configuration
const GRID_SIZE := 9  # 3x3 grid
const ROUNDS := 3
const MIN_OBJECTS := 4  # Minimum objects (easy)
const MAX_OBJECTS := 9  # Maximum objects (hard - uses full 3x3 grid)

# Active cells for different difficulty levels
var easy_cells := [0, 1, 3, 4]  # 2x2 top-left (4 objects)
var medium_cells := [0, 1, 2, 3, 4, 5]  # 2x3 top (6 objects)
var hard_cells := [0, 1, 2, 3, 4, 5, 6, 7, 8]  # Full 3x3 (9 objects)

# Game State
var round_number := 0
var score := 0
var current_round_score := 0  # Score for current round (resets each round)
var current_question: Dictionary = {}
var shuffled_options: Array = []  # Will contain [obj1, obj2, obj3, obj4] in shuffled order
var correct_index: int = -1  # Which of the 4 active cells has the odd one out
var used_question_indices := []  # Track which questions have been used

# Adaptive Difficulty System (matching memory game)
var difficulty := 0.0  # Range 0.0 (easy) to 1.0 (hard)
var last_accuracy := 0.0
var last_avg_time := 0.0
var consecutive_poor_performance := 0
var consecutive_good_performance := 0
var response_times := []  # Track response times for adaptive difficulty
var question_start_time := 0.0
var accuracy_history := []  # Track accuracy for fatigue detection
var return_to_menu_button: Button = null
var continue_button: Button = null

# Emoji mapping - using same as memory game
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

func _get_object_emoji(object_name: String) -> String:
	"""Get emoji for an object, returns empty string if not found"""
	return object_emojis.get(object_name, "")

# Question database - organized by difficulty (using only words that have emojis)
# Rules: All related items must be from the SAME category, odd one out must be from a COMPLETELY DIFFERENT category
# Easy (0.0-0.33): Very distinct categories, clear separation
# Medium (0.34-0.66): Distinct categories, more items to choose from
# Hard (0.67-1.0): Still distinct categories, maximum items to choose from

var questions := [
	# Easy questions (0.0-0.33) - Very distinct categories
	{"difficulty": 0.0, "category": "Fruit", "related": ["Apple", "Banana"], "odd": "Key"},  # Fruit vs Key
	{"difficulty": 0.0, "category": "Clothing", "related": ["Hat", "Shoe", "Sock"], "odd": "Pen"},  # Clothing vs Writing tool
	{"difficulty": 0.0, "category": "Food", "related": ["Bread", "Egg", "Milk"], "odd": "Book"},  # Food vs Book
	{"difficulty": 0.1, "category": "Personal Accessories", "related": ["Phone", "Watch", "Ring"], "odd": "Apple"},  # Accessories vs Food
	{"difficulty": 0.1, "category": "Kitchen Utensils", "related": ["Spoon", "Plate", "Bowl"], "odd": "Key"},  # Kitchen vs Key
	{"difficulty": 0.2, "category": "Drink Containers", "related": ["Cup", "Glass"], "odd": "Phone"},  # Containers vs Electronics
	{"difficulty": 0.2, "category": "Food Items", "related": ["Apple", "Bread", "Egg"], "odd": "Watch"},  # Food vs Accessory
	{"difficulty": 0.3, "category": "Clothing", "related": ["Hat", "Shoe", "Sock"], "odd": "Milk"},  # Clothing vs Food
	
	# Medium questions (0.34-0.66) - Distinct categories, more items
	{"difficulty": 0.4, "category": "Food Items", "related": ["Apple", "Banana", "Bread"], "odd": "Spoon"},  # Food vs Utensil
	{"difficulty": 0.4, "category": "Clothing", "related": ["Hat", "Shoe", "Sock"], "odd": "Book"},  # Clothing vs Book
	{"difficulty": 0.4, "category": "Containers", "related": ["Cup", "Glass", "Bowl"], "odd": "Phone"},  # Containers vs Electronics
	{"difficulty": 0.4, "category": "Food", "related": ["Bread", "Egg", "Milk"], "odd": "Key"},  # Food vs Key
	{"difficulty": 0.5, "category": "Clothing", "related": ["Hat", "Shoe", "Sock"], "odd": "Ring"},  # Clothing vs Jewelry
	{"difficulty": 0.5, "category": "Personal Accessories", "related": ["Phone", "Watch", "Ring"], "odd": "Apple"},  # Accessories vs Food
	{"difficulty": 0.5, "category": "Kitchen Items", "related": ["Spoon", "Plate", "Bowl"], "odd": "Phone"},  # Kitchen vs Electronics
	{"difficulty": 0.6, "category": "Food", "related": ["Bread", "Egg", "Milk"], "odd": "Hat"},  # Food vs Clothing
	{"difficulty": 0.6, "category": "Containers", "related": ["Cup", "Glass", "Bowl"], "odd": "Key"},  # Containers vs Key
	{"difficulty": 0.6, "category": "Clothing", "related": ["Hat", "Shoe", "Sock", "Bag"], "odd": "Book"},  # Clothing vs Book
	
	# Hard questions (0.67-1.0) - Still distinct categories, maximum items (4-6 related items)
	{"difficulty": 0.7, "category": "Food", "related": ["Apple", "Banana", "Bread"], "odd": "Key"},  # Food vs Key
	{"difficulty": 0.7, "category": "Clothing", "related": ["Hat", "Shoe", "Sock", "Bag"], "odd": "Book"},  # Clothing vs Book
	{"difficulty": 0.7, "category": "Food", "related": ["Bread", "Egg", "Milk"], "odd": "Phone"},  # Food vs Electronics
	{"difficulty": 0.8, "category": "Containers", "related": ["Cup", "Glass", "Bowl"], "odd": "Phone"},  # Containers vs Electronics
	{"difficulty": 0.8, "category": "Personal Accessories", "related": ["Phone", "Watch", "Ring"], "odd": "Bread"},  # Accessories vs Food
	{"difficulty": 0.8, "category": "Kitchen Items", "related": ["Spoon", "Plate", "Bowl"], "odd": "Key"},  # Kitchen vs Key
	{"difficulty": 0.8, "category": "Food", "related": ["Bread", "Egg", "Milk", "Apple"], "odd": "Hat"},  # Food vs Clothing
	{"difficulty": 0.9, "category": "Food", "related": ["Bread", "Egg", "Milk", "Apple", "Banana"], "odd": "Key"},  # Food vs Key
	{"difficulty": 0.9, "category": "Clothing", "related": ["Hat", "Shoe", "Sock", "Bag"], "odd": "Pen"},  # Clothing vs Writing tool
	{"difficulty": 0.9, "category": "Food", "related": ["Apple", "Banana", "Bread", "Egg", "Milk"], "odd": "Phone"}  # Food vs Electronics
]

# ============================================================================
# ADAPTIVE DIFFICULTY SYSTEM
# ============================================================================

func _clamp01(x: float) -> float:
	"""Utility function to clamp values between 0.0 and 1.0"""
	return max(0.0, min(1.0, x))

func _desired_object_count() -> int:
	"""
	Calculate how many objects to show.
	For Odd One Out, always use 4 objects (constant difficulty).
	"""
	return MIN_OBJECTS  # Always 4 objects, don't increase with difficulty

func _get_active_cells_for_difficulty() -> Array:
	"""Get the active cells to use based on current difficulty"""
	var object_count = _desired_object_count()
	
	if object_count <= 4:
		return easy_cells.duplicate()
	elif object_count <= 6:
		return medium_cells.duplicate()
	else:
		return hard_cells.duplicate()

func _get_questions_for_difficulty() -> Array:
	"""Get questions that match the current difficulty level"""
	var difficulty_range: float = 0.2  # Allow questions within 0.2 of current difficulty
	var min_diff: float = max(0.0, difficulty - difficulty_range)
	var max_diff: float = min(1.0, difficulty + difficulty_range)
	
	var matching_questions := []
	for q in questions:
		var q_diff = q.get("difficulty", 0.5)
		if q_diff >= min_diff and q_diff <= max_diff:
			matching_questions.append(q)
	
	# If no questions match, use closest ones
	if matching_questions.size() == 0:
		for q in questions:
			matching_questions.append(q)
	
	return matching_questions

func _update_difficulty_from_round():
	"""
	Update adaptive difficulty based on performance (matching memory game algorithm).
	Called after each round completes.
	"""
	var total: int = 4  # Always 4 options
	if total < 1:
		total = 1  # Prevent division by zero

	# Factor 1: Calculate accuracy as percentage (use current_round_score)
	var acc: float = float(current_round_score) / float(total)
	last_accuracy = acc
	
	# Track accuracy history for fatigue detection
	accuracy_history.append(acc)

	# Factor 2: Calculate average response time
	var avg_time := 0.0
	if response_times.size() > 0:
		var total_time := 0.0
		for time in response_times:
			total_time += time
		avg_time = total_time / float(response_times.size())
		last_avg_time = avg_time
	
	# Normalize response time (0-10 seconds range, faster = higher value)
	var time_factor := 0.0
	if avg_time > 0.0:
		var normalized_time: float = clamp(avg_time / 10.0, 0.0, 1.0)
		time_factor = (1.0 - normalized_time) * 0.3  # Up to 0.3 influence

	# Combined adaptive difficulty algorithm (matching memory game)
	var accuracy_adjustment := 0.0
	
	# Determine performance level and track consecutive rounds
	if acc >= 0.60:  # Good performance (60% or higher)
		consecutive_good_performance += 1
		consecutive_poor_performance = 0
		
		# After 2 consecutive good rounds, raise difficulty
		if consecutive_good_performance >= 2:
			accuracy_adjustment = 0.20
			consecutive_good_performance = 0
			print("Difficulty: Raising level after 2 consecutive good rounds (accuracy >= 60%)")
	elif acc < 0.40:  # Poor performance (below 40%)
		consecutive_poor_performance += 1
		consecutive_good_performance = 0
		
		# After 2 consecutive poor rounds, drop difficulty
		if consecutive_poor_performance >= 2:
			accuracy_adjustment = -0.20
			consecutive_poor_performance = 0
			print("Difficulty: Dropping level after 2 consecutive poor rounds (accuracy < 40%)")
	else:  # Moderate performance (40-60%)
		consecutive_poor_performance = 0
		consecutive_good_performance = 0
		accuracy_adjustment = 0.0
	
	# Apply all factors
	var old_difficulty := difficulty
	difficulty += accuracy_adjustment + time_factor
	difficulty = _clamp01(difficulty)
	
	# Debug: Print difficulty update
	print("Odd One Out - Round ", round_number, ": accuracy=", acc, " old_diff=", old_difficulty, " new_diff=", difficulty)
	
	# Clear response times for next round
	response_times.clear()

func _ready():
	_setup_background()
	_build_grid_buttons()
	_create_top_buttons()
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
	
	# Setup instruction label styling (matching memory game)
	if instruction_label:
		instruction_label.add_theme_font_size_override("font_size", 36)
		instruction_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))
		instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		instruction_label.custom_minimum_size = Vector2(0, 120)  # Fixed size to prevent layout shifts
	
	# Add spacing to VBoxContainer to push everything down (matching memory game)
	if vbox:
		vbox.add_theme_constant_override("separation", 20)  # Add spacing between elements
	
	# Setup feedback label styling
	if feedback_label:
		feedback_label.add_theme_font_size_override("font_size", 32)
		feedback_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
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
	
	# Connect Next button signal
	if next_button:
		if next_button.pressed.is_connected(_on_next_pressed):
			next_button.pressed.disconnect(_on_next_pressed)
		next_button.pressed.connect(_on_next_pressed)
	
	_start_round()

func _setup_background():
	"""Setup sky blue background color matching the memory game"""
	if ui_container:
		var panel := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.6, 0.8, 0.95)  # Sky blue background
		panel.add_theme_stylebox_override("panel", style)
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui_container.add_child(panel)
		ui_container.move_child(panel, 0)  # Move to back

func _build_grid_buttons():
	"""Build 3x3 grid of buttons - EXACTLY matching memory game structure"""
	# Clear any existing buttons
	for c in grid.get_children():
		c.queue_free()
	
	# Calm, accessible color palette - darker pastels for better visibility (matching memory game)
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
	
	# Create 9 buttons for 3x3 grid
	for i in range(GRID_SIZE):
		var b := Button.new()
		b.name = "Cell_%d" % i
		
		# Accessibility: Large buttons for easy tapping (matching memory game)
		b.custom_minimum_size = Vector2(140, 140)
		b.add_theme_font_size_override("font_size", 22)
		
		# Visual styling: Apply calm colors for visual engagement (matching memory game)
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
		
		# Create a VBoxContainer inside the button for emoji and text (matching memory game)
		var vbox := VBoxContainer.new()
		vbox.name = "Content"
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)
		b.add_child(vbox)
		
		# Create label for emoji (large) - matching memory game
		var emoji_label := Label.new()
		emoji_label.name = "EmojiLabel"
		emoji_label.text = ""
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji_label.add_theme_font_size_override("font_size", 64)  # Large emoji
		emoji_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(emoji_label)
		
		# Create label for text (smaller) - matching memory game
		var text_label := Label.new()
		text_label.name = "TextLabel"
		text_label.text = ""
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		text_label.add_theme_font_size_override("font_size", 20)  # Smaller text
		text_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))  # Dark text
		text_label.size_flags_vertical = Control.SIZE_SHRINK_END
		vbox.add_child(text_label)
		
		b.disabled = true  # Start disabled
		
		# Connect signal using lambda to capture cell index
		b.pressed.connect(func(): _on_cell_pressed(i))
		grid.add_child(b)

func _start_round():
	"""Start a new round"""
	if round_number >= ROUNDS:
		_show_final_results()
		return
	
	# Update difficulty from previous round (skip on first round)
	if round_number > 0:
		_update_difficulty_from_round()
	
	round_number += 1
	current_round_score = 0  # Reset score for new round
	
	# Calculate how many objects to show based on difficulty
	var desired_count = _desired_object_count()
	print("Odd One Out - Round ", round_number, ": difficulty=", difficulty, ", showing ", desired_count, " objects")
	
	# Pick a question based on current difficulty (and ensure no repeats)
	var available_questions = _get_questions_for_difficulty()
	
	# Remove already used questions
	var unused_questions = []
	for q in available_questions:
		var q_index = questions.find(q)
		if q_index not in used_question_indices:
			unused_questions.append(q)
	
	# If we've used all questions, reset the used list
	if unused_questions.size() == 0:
		used_question_indices.clear()
		unused_questions = available_questions
	
	# Pick random question from available
	unused_questions.shuffle()
	current_question = unused_questions[0]
	
	# Track that we've used this question
	var q_index = questions.find(current_question)
	if q_index >= 0:
		used_question_indices.append(q_index)
	
	# Calculate how many related items we need (desired_count already calculated above)
	var num_related_needed = desired_count - 1  # One slot for the odd item
	
	# Get related items and ensure they're unique
	var related_items = current_question.related.duplicate()
	var unique_related = []
	for item in related_items:
		if item not in unique_related:
			unique_related.append(item)
	related_items = unique_related
	
	# Remove the odd item from related_items if it appears there (safeguard)
	related_items.erase(current_question.odd)
	
	# If we have more related items than needed, pick the right amount
	if related_items.size() > num_related_needed:
		related_items.shuffle()
		related_items = related_items.slice(0, num_related_needed)
	
	# If we have less than needed, fill from available pool (excluding odd item)
	if related_items.size() < num_related_needed:
		# Get all available objects from emoji mapping
		var all_objects = object_emojis.keys()
		all_objects.shuffle()
		
		# Add unique objects from the pool until we have enough, excluding the odd item
		for obj in all_objects:
			if obj != current_question.odd and obj not in related_items:
				related_items.append(obj)
				if related_items.size() >= num_related_needed:
					break
	
	# Final safeguard: ensure we have enough unique related items
	if related_items.size() < num_related_needed:
		push_warning("Odd One Out: Could not get " + str(num_related_needed) + " unique related items, using " + str(related_items.size()))
	
	# Create final shuffled array: related items + 1 odd (guaranteed unique)
	shuffled_options = related_items.duplicate()
	
	# Add the odd item (guaranteed not in related_items due to erase above)
	if current_question.odd not in shuffled_options:
		shuffled_options.append(current_question.odd)
	else:
		# This shouldn't happen, but if it does, find a replacement
		push_error("Odd One Out: Odd item '" + current_question.odd + "' found in related items! Replacing...")
		var all_objects = object_emojis.keys()
		all_objects.shuffle()
		var replacement_found = false
		for obj in all_objects:
			if obj not in shuffled_options:
				shuffled_options.append(obj)
				current_question.odd = obj  # Update the odd item
				replacement_found = true
				break
		if not replacement_found:
			push_error("Odd One Out: Could not find replacement for odd item!")
	
	# Final verification: ensure we have the right number of items
	if shuffled_options.size() != desired_count:
		push_error("Odd One Out: Expected " + str(desired_count) + " items, got " + str(shuffled_options.size()))
	
	# Double-check for duplicates (shouldn't happen, but safety check)
	var seen = {}
	for item in shuffled_options:
		if item in seen:
			push_error("Odd One Out: Duplicate item found: " + item)
		else:
			seen[item] = true
	
	shuffled_options.shuffle()
	
	# Find which position has the odd one out
	correct_index = shuffled_options.find(current_question.odd)
	
	# Start response time tracking
	question_start_time = Time.get_ticks_msec() / 1000.0
	
	# Display the round
	_display_round()

func _display_round():
	"""Display the current round on the grid"""
	# Get active cells based on current difficulty
	var active_cells = _get_active_cells_for_difficulty()
	
	# Clear all buttons first
	for i in range(GRID_SIZE):
		var b: Button = grid.get_child(i)
		b.text = ""
		b.disabled = true
		
		# Clear child labels if they exist
		var vbox = b.get_node_or_null("Content")
		if vbox:
			var emoji_label = vbox.get_node_or_null("EmojiLabel")
			var text_label = vbox.get_node_or_null("TextLabel")
			if emoji_label:
				emoji_label.text = ""
			if text_label:
				text_label.text = ""
	
	# Display the options in the active cells
	for i in range(shuffled_options.size()):
		if i >= active_cells.size():
			push_warning("Odd One Out: More options than active cells!")
			break
		
		var cell_idx = active_cells[i]
		var btn: Button = grid.get_child(cell_idx)
		var obj = shuffled_options[i]
		
		# Get the VBoxContainer structure (already created in _build_grid_buttons)
		var vbox = btn.get_node("Content")
		var emoji_label = vbox.get_node("EmojiLabel")
		var text_label = vbox.get_node("TextLabel")
		
		# Set emoji and text (matching memory game display)
		var emoji = _get_object_emoji(obj)
		if emoji != "":
			emoji_label.text = emoji
			text_label.text = obj
		else:
			# Fallback: show text only if no emoji
			emoji_label.text = ""
			text_label.text = obj
			text_label.add_theme_font_size_override("font_size", 28)  # Larger if no emoji
		
		# Enable only the active buttons
		btn.disabled = false
	
	# Set instruction
	instruction_label.text = "Tap the one that does NOT belong."
	instruction_label.visible = true
	feedback_label.text = ""
	feedback_label.visible = false
	next_button.visible = false

func _on_cell_pressed(cell_index: int):
	"""Handle button press"""
	if is_paused:
		return  # Ignore input when paused
	
	# Get active cells based on current difficulty
	var active_cells = _get_active_cells_for_difficulty()
	
	# Only process if it's one of the active cells
	if not cell_index in active_cells:
		return
	
	# Calculate and store response time for adaptive difficulty
	var response_time := (Time.get_ticks_msec() / 1000.0) - question_start_time
	response_times.append(response_time)
	
	# Find which of the options was selected
	var selected_option_idx = active_cells.find(cell_index)
	var is_correct = (selected_option_idx == correct_index)
	var selected_obj = shuffled_options[selected_option_idx]
	
	# Clear all objects from the grid first
	for idx in active_cells:
		var b: Button = grid.get_child(idx)
		b.disabled = true
		b.text = ""
		
		# Clear child labels
		var vbox = b.get_node_or_null("Content")
		if vbox:
			var emoji_label = vbox.get_node_or_null("EmojiLabel")
			var text_label = vbox.get_node_or_null("TextLabel")
			if emoji_label:
				emoji_label.text = ""
			if text_label:
				text_label.text = ""
	
	# Show only the selected object on the selected cell
	var selected_btn: Button = grid.get_child(cell_index)
	var selected_vbox = selected_btn.get_node("Content")
	var emoji_label = selected_vbox.get_node("EmojiLabel")
	var text_label = selected_vbox.get_node("TextLabel")
	
	# Display the selected object
	var emoji = _get_object_emoji(selected_obj)
	if emoji != "":
		emoji_label.text = emoji
		text_label.text = selected_obj
	else:
		# Fallback: show text only if no emoji
		emoji_label.text = ""
		text_label.text = selected_obj
		text_label.add_theme_font_size_override("font_size", 28)
	
	# Highlight the selected cell (green for correct, different style for incorrect)
	var style_box := selected_btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if style_box:
		if is_correct:
			style_box.border_color = Color(0.2, 0.7, 0.3)  # Green border for correct
		else:
			style_box.border_color = Color(0.7, 0.5, 0.3)  # Orange border for incorrect
		style_box.border_width_left = 4
		style_box.border_width_right = 4
		style_box.border_width_top = 4
		style_box.border_width_bottom = 4
		selected_btn.add_theme_stylebox_override("normal", style_box)
	
	# Provide feedback
	if is_correct:
		score += 1
		current_round_score = 1  # 1 out of 1 question in round
		instruction_label.text = "That's right! Well done."
	else:
		current_round_score = 0  # 0 out of 1 question in round
		var odd_one = current_question.odd
		instruction_label.text = "Not quite — the odd one was " + odd_one + "."
	
	# Ensure instruction label maintains fixed size to prevent screen movement
	instruction_label.custom_minimum_size = Vector2(0, 120)
	instruction_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Don't expand
	instruction_label.visible = true
	feedback_label.visible = false
	
	# Always show feedback and Next button, even on final round
	# The Next button will handle showing final results when appropriate
	next_button.visible = true
	if round_number >= ROUNDS:
		# Final round - Next button will say "Done" and show final results
		next_button.text = "Done"
	else:
		# Intermediate round - show "Next" button
		next_button.text = "Next"
	
	# Ensure VBoxContainer spacing is consistent to prevent layout shifts
	if vbox:
		vbox.add_theme_constant_override("separation", 20)  # Consistent spacing

func _show_round_score():
	"""Show intermediate round score (after rounds 1 and 2) - grid stays visible"""
	var score_text := "Score: " + str(score) + " / " + str(round_number)
	var accuracy := float(current_round_score) / float(1.0)  # 1 question per round
	
	# Context-aware message based on performance (matching memory game)
	var round_message := ""
	if accuracy >= 0.8:
		round_message = "Wonderful! You're doing really well."
	elif accuracy >= 0.5:
		round_message = "You're doing good! Keep going."
	else:
		round_message = "You're trying your best. That's what matters."
	
	instruction_label.text = score_text + "\n\n" + round_message
	
	# Show Next button with same layout as memory game
	next_button.visible = true
	next_button.text = "Move On"
	next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Move next_button to be after feedback_label (below text)
	if vbox and next_button.get_parent() == vbox:
		var feedback_index = feedback_label.get_index()
		var next_index = next_button.get_index()
		if next_index < feedback_index:
			vbox.move_child(next_button, feedback_index + 1)
	
	# Reduce spacing before button
	if vbox:
		vbox.add_theme_constant_override("separation", 5)  # Reduced spacing between elements

func _on_next_pressed():
	"""Handle Next button press"""
	if is_paused:
		return  # Ignore input when paused
	
	# Check if this was the final round
	if round_number >= ROUNDS:
		# Final round completed - show final results
		_show_final_results()
		return
	
	# Reset grid visibility for next round (in case it was hidden)
	grid.visible = true
	
	# Reset instruction label styling
	instruction_label.add_theme_font_size_override("font_size", 36)  # Reset to normal size
	instruction_label.custom_minimum_size = Vector2(0, 120)
	
	# Remove end session buttons if they exist
	if return_to_menu_button:
		var button_container = return_to_menu_button.get_parent()
		if button_container and button_container.name == "EndSessionButtons":
			button_container.queue_free()
		return_to_menu_button = null
		continue_button = null
	
	# Move to next round
	_start_round()

func _show_final_results():
	"""Show final score and play again option - matching memory game style"""
	# Hide grid (matching memory game)
	grid.visible = false
	
	# Show score
	var score_text := "Score: " + str(score) + " / " + str(ROUNDS)
	
	# Fatigue detection (matching memory game)
	var accuracy := float(score) / float(ROUNDS) if ROUNDS > 0 else 0.0
	var should_end_early := false
	
	# If accuracy drops significantly (fatigue detection), end session early
	if accuracy_history.size() >= 2:
		var previous_avg := 0.0
		for i in range(accuracy_history.size() - 1):
			previous_avg += accuracy_history[i]
		previous_avg /= float(accuracy_history.size() - 1)
		
		# Significant drop (40% or more decrease) suggests fatigue
		if accuracy < previous_avg - 0.4 and accuracy < 0.3:
			should_end_early = true
	
	# Show score and friendly message in instruction_label (matching memory game)
	instruction_label.visible = true
	feedback_label.visible = false
	
	# Context-aware message based on performance (matching memory game)
	var end_message := ""
	if accuracy >= 0.8:
		end_message = "You did wonderfully today!"
	elif accuracy >= 0.5:
		end_message = "You're doing great! Keep it up."
	else:
		end_message = "Thank you for playing with us today."
	
	instruction_label.text = score_text + "\n\n" + end_message
	
	# Style instruction label for final screen (matching memory game)
	instruction_label.add_theme_font_size_override("font_size", 52)  # Large text
	instruction_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2))  # Dark text
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	instruction_label.custom_minimum_size = Vector2(0, 0)
	instruction_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	instruction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Hide the regular next button
	next_button.visible = false
	
	# Create Return to Menu and Continue buttons (matching memory game)
	_create_end_session_buttons()
	
	# Increase spacing before buttons to move them lower
	if vbox:
		vbox.add_theme_constant_override("separation", 50)  # More spacing to move buttons lower

func _create_end_session_buttons():
	"""Create Return to Menu and Continue buttons for end of session screen (matching memory game)"""
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
	
	# Add button container to vbox after instruction_label
	var instruction_index = instruction_label.get_index()
	vbox.add_child(button_container)
	vbox.move_child(button_container, instruction_index + 1)

func _on_return_to_menu_pressed():
	"""Handle Return to Main Menu button - return to menu"""
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_continue_pressed():
	"""Handle Continue button - continue playing (reset and start new session)"""
	# Remove the end session buttons
	if return_to_menu_button:
		var button_container = return_to_menu_button.get_parent()
		if button_container and button_container.name == "EndSessionButtons":
			button_container.queue_free()
		return_to_menu_button = null
		continue_button = null
	
	# Reset game state for new session
	round_number = 0
	score = 0
	current_round_score = 0
	used_question_indices.clear()
	difficulty = 0.0
	last_accuracy = 0.0
	last_avg_time = 0.0
	consecutive_poor_performance = 0
	consecutive_good_performance = 0
	response_times.clear()
	accuracy_history.clear()
	
	# Make sure grid is visible
	grid.visible = true
	
	# Reset instruction label styling
	instruction_label.add_theme_font_size_override("font_size", 36)
	instruction_label.custom_minimum_size = Vector2(0, 120)
	
	# Start first round
	_start_round()

# ============================================================================
# TOP BUTTONS (Pause, Reset, Quit) - Matching memory game
# ============================================================================

func _create_top_buttons():
	"""Create small square pause, reset, and quit buttons in top right corner"""
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
	"""Handle reset button - reset game and go back to first round"""
	if is_paused:
		_toggle_pause()  # Unpause first
	
	# Remove end session buttons if they exist
	if return_to_menu_button:
		var button_container = return_to_menu_button.get_parent()
		if button_container and button_container.name == "EndSessionButtons":
			button_container.queue_free()
		return_to_menu_button = null
		continue_button = null
	
	# Reset all game state
	round_number = 0
	score = 0
	current_round_score = 0
	current_question = {}
	shuffled_options.clear()
	correct_index = -1
	used_question_indices.clear()
	
	# Reset adaptive difficulty
	difficulty = 0.0
	last_accuracy = 0.0
	last_avg_time = 0.0
	consecutive_poor_performance = 0
	consecutive_good_performance = 0
	response_times.clear()
	accuracy_history.clear()
	
	# Hide the regular next button if it was visible
	if next_button:
		next_button.visible = false
	
	# Make sure grid is visible
	grid.visible = true
	
	# Start first round
	_start_round()

func _on_quit_pressed():
	"""Handle quit button - return to menu screen"""
	get_tree().change_scene_to_file("res://menu.tscn")

func _style_next_button():
	"""Style the next button to be smaller and pastel colored (matching memory game)"""
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
