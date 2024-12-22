extends Control


func _ready():
	pass



# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
#     pass


func _on_button_pressed() -> void:
	var next_scene = load("res://Scenes/main.tscn")
	get_tree().change_scene_to_packed(next_scene)


func _on_button_3_pressed() -> void:
	var next_scene = load("res://Scenes/help.tscn")
	get_tree().change_scene_to_packed(next_scene)
