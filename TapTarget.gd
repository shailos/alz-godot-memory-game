extends Area2D

@onready var sprite: Sprite2D = get_parent()


func _ready():
	print("Game started")

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		print("Sprite tapped!")
		flash_feedback()

func flash_feedback():
	if sprite == null:
		push_error("TargetSprite not found. Check node name/path.")
		return

	sprite.modulate = Color(0, 1, 0) # green
	await get_tree().create_timer(0.3).timeout
	sprite.modulate = Color(1, 1, 1) # back to normal
	
	
	
	
