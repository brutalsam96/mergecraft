extends Node2D

@onready var button_container: Node2D      = $ButtonsGroup
@onready var display_label: Label         = $Label
@onready var result_label: Label          = $Label4
@onready var score_label: Label           = $ScoreLabel
@onready var attempts_label: Label        = $AttemptsLabel
@onready var correct_cue: AudioStreamPlayer2D = $"correct"
@onready var wrong_cue: AudioStreamPlayer2D   = $"incorrect"

# Keep track of everything needed for combos, dragging, score, etc.
var combinations: Array               = []
var current_combination: Dictionary   = {}
var all_elements: Array               = []
var drop_spots: Array                 = []
var is_dragging: bool                 = false
var current_dragged_button: Button    = null
var original_position_map: Dictionary = {}
var element_1: Button                 = null
var original_pos_element_1: Vector2   = Vector2.ZERO
var score: int                        = 0
var attempts: int                     = 3

const MERGE_POSITION: Vector2         = Vector2(300, -300)
const MOVE_DURATION: float            = 0.3
const FADE_DURATION: float            = 0.3
const RESULT_DISPLAY_DURATION: float  = 2.5

var SCALE_UP = Vector2(1.1, 1.1) # Subtle scale-up value
var SCALE_DOWN = Vector2(0.9, 0.9) # Subtle scale-down value
var ANIMATION_DURATION = 1.0 # Slow down the animation

func _ready():
    drop_spots = get_tree().get_nodes_in_group("drop_spot_group")
    print(correct_cue, wrong_cue) 
    # Load combos once
    if GameState.combinations.is_empty():
        GameState.load_combinations()
    combinations = GameState.combinations
    all_elements = get_all_unique_elements(combinations)

    # Capture original button positions
    for child in button_container.get_children():
        if child is Button:
            original_position_map[child] = Vector2(child.global_position.x, -child.global_position.y)

    style_result_label()
    initialize_score_attempts()
    style_score_and_attempts_labels()

    # Start first round
    start_new_round()


func initialize_score_attempts() -> void:
    score = 0
    attempts = 3
    update_score_label()
    update_attempts_label()

func update_score_label() -> void:
    if score_label:
        score_label.text = "SCORE:%d" % score

func update_attempts_label() -> void:
    if attempts_label:
        attempts_label.text = "ATTEMPTS:%d" % attempts

func style_score_and_attempts_labels() -> void:
    var custom_font = load("res://fonts/NotoEmoji-VariableFont_wght.ttf")
    if custom_font:
        custom_font.fixed_size = 42

        var label_settings = LabelSettings.new()
        label_settings.font = custom_font
        label_settings.font_color = Color(1, 1, 1)

        if score_label:
            score_label.label_settings = label_settings
        if attempts_label:
            attempts_label.label_settings = label_settings.duplicate()

func style_result_label() -> void:
    var label_settings = LabelSettings.new()
    label_settings.font_color = Color.WHITE
    label_settings.font = load("res://fonts/NotoEmoji-VariableFont_wght.ttf")
    if label_settings.font:
        result_label.custom_minimum_size = Vector2(300, 50)
        result_label.label_settings = label_settings
        result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        result_label.global_position = MERGE_POSITION
        result_label.visible = false
        result_label.modulate.a = 0

func start_new_round() -> void:
    if combinations.is_empty():
        return
    current_combination = combinations[randi() % combinations.size()]
    if display_label:
        display_label.text = str(current_combination.get("result", "???"))

    element_1 = null
    original_pos_element_1 = Vector2.ZERO
    reset_and_assign_buttons()

func reset_and_assign_buttons() -> void:
    var buttons = button_container.get_children()
    for btn in buttons:
        if btn is Button and original_position_map.has(btn):
            var orig_pos = original_position_map[btn]
            btn.global_position = Vector2(orig_pos.x, -orig_pos.y)
            btn.scale = Vector2.ONE
            btn.modulate.a = 1
            btn.visible = true

    # Choose 2 correct + 8 wrong
    var correct_elements = current_combination.get("elements", []).duplicate()
    correct_elements.shuffle()
    correct_elements = correct_elements.slice(0, 2)

    var wrong_elements = all_elements.filter(func(e): return not correct_elements.has(e))
    wrong_elements.shuffle()
    wrong_elements = wrong_elements.slice(0, 8)

    var button_elements = correct_elements + wrong_elements
    button_elements.shuffle()

    for i in range(buttons.size()):
        if i < button_elements.size():
            var b = buttons[i]
            if b is Button:
                b.set_meta("element", button_elements[i])
                b.text = button_elements[i]

func _input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            var btn = get_button_under_mouse()
            if btn:
                is_dragging = true
                current_dragged_button = btn
                current_dragged_button.scale = Vector2(1.1, 1.1)
        else:
            if is_dragging and current_dragged_button:
                is_dragging = false
                handle_snap(current_dragged_button)
                current_dragged_button.scale = Vector2(1, 1)
                current_dragged_button = null
    elif event is InputEventMouseMotion and is_dragging and current_dragged_button:
        var b = current_dragged_button
        b.position += event.relative
        var vp_size = get_viewport_rect().size
        b.position.x = clamp(b.position.x, -vp_size.x / 2, vp_size.x / 2 - b.size.x)
        b.position.y = clamp(b.position.y, -vp_size.y, -b.size.y)

func get_button_under_mouse() -> Button:
    var mp = get_global_mouse_position()
    for child in button_container.get_children():
        if child is Button and child.get_global_rect().has_point(mp):
            return child
    return null

func handle_snap(btn: Button) -> void:
    var area2d = btn.get_node("Area2D") if btn.has_node("Area2D") else null
    var snapped_spot: Node = null

    if area2d:
        for ds in drop_spots:
            if ds.get_overlapping_areas().has(area2d):
                snapped_spot = ds
                break

    if snapped_spot:
        snap_button_to_spot(btn, snapped_spot)
    else:
        animate_back(btn, original_position_map[btn])
        if btn == element_1:
            element_1 = null
            original_pos_element_1 = Vector2.ZERO

func snap_button_to_spot(btn: Button, ds: Node) -> void:
    var collision_shape = ds.get_node("CollisionShape2D")
    var target_pos = ds.global_position
    target_pos += Vector2(-btn.size.x / 2, -btn.size.y / 2)

    var tween = create_tween()
    tween.tween_property(btn, "global_position", target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await tween.finished

    if element_1 == null:
        element_1 = btn
        original_pos_element_1 = original_position_map[btn]
    else:
        var element_2 = btn
        var original_pos_element_2 = original_position_map[element_2]
        merge_elements(element_1, element_2, original_pos_element_1, original_pos_element_2)

func merge_elements(elem1: Button, elem2: Button, _orig_pos1: Vector2, _orig_pos2: Vector2) -> void:
    set_process_input(false)
    var corrected_merge_position = Vector2(MERGE_POSITION.x, -MERGE_POSITION.y)
    var element1_target_pos = corrected_merge_position
    var element2_target_pos = corrected_merge_position + Vector2(elem1.size.x + 50, 0)

    var tween = create_tween()
    tween.parallel()
    tween.tween_property(elem1, "global_position", element1_target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(elem2, "global_position", element2_target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    tween.parallel()
    tween.tween_property(elem1, "modulate:a", 0, FADE_DURATION).set_delay(MOVE_DURATION)
    tween.tween_property(elem2, "modulate:a", 0, FADE_DURATION).set_delay(MOVE_DURATION)

    await tween.finished
    display_result_label(elem1, elem2)

func display_result_label(elem1: Button, elem2: Button, font_size: int = 36) -> void:
    var is_correct = check_combination_correctness(elem1, elem2)
    if is_correct:
        if correct_cue:
            correct_cue.play()
        result_label.text = "Correct! %s + %s = %s" % [elem1.text, elem2.text, current_combination.get("result", "")]
        result_label.modulate = Color(0, 1, 0)
        var difficulty = current_combination.get("difficulty", 1)
        score += 10 * difficulty
        update_score_label()
    else:
        if wrong_cue:
            wrong_cue.play()
        var correct_elems = current_combination.get("elements", [])
        result_label.text = "Incorrect! %s" % str(correct_elems)
        result_label.modulate = Color(1, 0, 0)
        attempts -= 1
        update_attempts_label()
        if attempts <= 0:
            handle_game_over()

    var label_settings = LabelSettings.new()
    label_settings.font = load("res://fonts/NotoEmoji-VariableFont_wght.ttf")
    label_settings.font_size = font_size
    result_label.label_settings = label_settings

    var corrected_pos = Vector2(MERGE_POSITION.x, -MERGE_POSITION.y)
    result_label.pivot_offset = result_label.size / 2
    result_label.global_position = corrected_pos
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_label.visible = true

    var tween = create_tween()
    tween.tween_property(result_label, "scale", SCALE_UP, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(result_label, "scale", SCALE_DOWN, ANIMATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(result_label, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

    await get_tree().create_timer(RESULT_DISPLAY_DURATION).timeout
    result_label.visible = false

    elem1.visible = true
    elem2.visible = true
    elem1.global_position = Vector2(original_position_map[elem1].x, -original_position_map[elem1].y)
    elem2.global_position = Vector2(original_position_map[elem2].x, -original_position_map[elem2].y)

    start_new_round()
    set_process_input(true)

func handle_game_over() -> void:
    print("Game Over triggered")

    # Pause the game
    get_tree().paused = true

    # Semi-transparent overlay that fills the screen
    var overlay = ColorRect.new()
    overlay.name = "GameOverOverlay"
    overlay.process_mode = Node.PROCESS_MODE_ALWAYS   # Keep UI active during pause
    overlay.anchor_left = 0.0
    overlay.anchor_top = 0.0
    overlay.anchor_right = 1.0
    overlay.anchor_bottom = 1.0
    overlay.color = Color(0, 0, 0, 0.5)
    add_child(overlay)

    # Centered container
    var container = VBoxContainer.new()
    container.process_mode = Node.PROCESS_MODE_ALWAYS    # Keep UI active during pause
    container.anchor_left = 0.0
    container.anchor_top = 0.0
    container.anchor_right = 1.0
    container.anchor_bottom = 1.0
    container.position.y -= 1100
    container.position.x = -100
    container.alignment = BoxContainer.ALIGNMENT_CENTER
    overlay.add_child(container)

    # "Game Over!" label
    var lbl_game_over = Label.new()
    lbl_game_over.text = "Game Over!"
    lbl_game_over.add_theme_font_size_override("font_size", 48)
    lbl_game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    container.add_child(lbl_game_over)

    # Final score label
    var lbl_score = Label.new()
    lbl_score.text = "Final Score: %d" % score
    lbl_score.add_theme_font_size_override("font_size", 32)
    lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    container.add_child(lbl_score)

    # Restart button
    var restart_btn = Button.new()
    restart_btn.text = "Restart"
    restart_btn.process_mode = Node.PROCESS_MODE_ALWAYS
    restart_btn.add_theme_font_size_override("font_size", 36)
    restart_btn.custom_minimum_size = Vector2(200, 80)  # Set custom button size
    restart_btn.pressed.connect(self._on_restart_pressed)
    container.add_child(restart_btn)

    # Disable existing main buttons
    for btn in button_container.get_children():
        if btn is Button:
            btn.disabled = true


func check_combination_correctness(elem1: Button, elem2: Button) -> bool:
    var combined = [elem1.get_meta("element"), elem2.get_meta("element")]
    combined.sort()
    var correct_combo = current_combination.get("elements", []).duplicate()
    correct_combo.sort()
    return combined == correct_combo

func animate_back(button: Button, target_pos: Vector2) -> void:
    var adjusted_pos = Vector2(target_pos.x, -target_pos.y)
    var tween = create_tween()
    tween.tween_property(button, "global_position", adjusted_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await tween.finished

func get_all_unique_elements(all_combos: Array) -> Array:
    var elements = []
    for combo in all_combos:
        for el in combo["elements"]:
            if not elements.has(el):
                elements.append(el)
    return elements

func _process(_delta):
    pass

func _on_restart_pressed() -> void:
    get_tree().paused = false
    get_node("GameOverOverlay").queue_free()
    for btn in button_container.get_children():
        if btn is Button:
            btn.disabled = false
    initialize_score_attempts()
    start_new_round()


func _on_button_pressed() -> void:
    var next_scene = load("res://Scenes/main_menu_entry_simple.tscn")
    get_tree().change_scene_to_packed(next_scene)
