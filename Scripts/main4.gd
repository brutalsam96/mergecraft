extends Node2D

# ------------------------------------------------------------------
# Nodes
# ------------------------------------------------------------------
@onready var button_container: Node2D = $ButtonsGroup
@onready var result_label: Label = $Label4

# ------------------------------------------------------------------
# Constants for Animation
# ------------------------------------------------------------------
const MERGE_POSITION: Vector2 = Vector2(300, 200)  # Adjust to your desired central position
const MOVE_DURATION: float = 0.2
const FADE_DURATION: float = 0.2
const RESULT_DISPLAY_DURATION: float = 1.0

# ------------------------------------------------------------------
# Game Data
# ------------------------------------------------------------------
var combinations: Array = []                  # All loaded combos
var current_combination: Dictionary = {}      # The current correct combo
var all_elements: Array = []                  # All possible elements
var drop_spots: Array = []                    # Areas to snap onto

# ------------------------------------------------------------------
# Drag Tracking
# ------------------------------------------------------------------
var is_dragging: bool = false
var current_dragged_button: Button = null
var original_position_map: Dictionary = {}    # Maps button -> original_position

# ------------------------------------------------------------------
# Snap Tracking: we only need two items
# ------------------------------------------------------------------
var element_1: Button = null
var original_pos_element_1: Vector2 = Vector2.ZERO

func _ready():
    # (1) Fetch drop spots from group
    drop_spots = get_tree().get_nodes_in_group("drop_spot_group")

    # (2) Load combinations from GameState if needed
    if GameState.combinations.size() == 0:
        GameState.load_combinations()
    combinations = GameState.combinations
    all_elements = get_all_unique_elements(combinations)

    # (3) Capture each button’s original position
    for child in button_container.get_children():
        if child is Button:
            original_position_map[child] = child.global_position

    # (4) Style the result label
    style_result_label()

    # (5) Start the first round
    start_new_round()

# ------------------------------------------------------------------
# Utility
# ------------------------------------------------------------------

func get_all_unique_elements(all_combos: Array) -> Array:
    var elements := []
    for combo in all_combos:
        for el in combo["elements"]:
            if not elements.has(el):
                elements.append(el)
    return elements

func start_new_round() -> void:
    # Pick a random combination
    current_combination = combinations[randi() % combinations.size()]

    if result_label:
        result_label.text = "Find: " + str(current_combination.get("result", "???"))

    # Reset any leftover states
    element_1 = null
    original_pos_element_1 = Vector2.ZERO

    # Also reset all buttons (positions, text, meta, etc.)
    reset_and_assign_buttons()

func reset_and_assign_buttons() -> void:
    # Gather references
    var buttons = button_container.get_children()

    # Return each button to its original position & clear any tween leftovers
    for btn in buttons:
        if btn is Button:
            if original_position_map.has(btn):
                btn.global_position = original_position_map[btn]
            # Reset scale, rotation, etc.
            btn.set_scale(Vector2.ONE)
            btn.modulate.a = 1
            btn.visible = true
            # Optionally reset any other properties if modified during animations

    # Determine 2 correct
    var correct_elements = current_combination.get("elements", []).duplicate()
    correct_elements.shuffle()
    correct_elements = correct_elements.slice(0, 2)

    # Determine 8 wrong
    var wrong_elements = all_elements.filter(func(e):
        return not correct_elements.has(e)
    )
    wrong_elements.shuffle()
    wrong_elements = wrong_elements.slice(0, 8)

    # Combine & shuffle
    var button_elements = correct_elements + wrong_elements
    button_elements.shuffle()

    # Assign to each button
    for i in range(buttons.size()):
        if i < button_elements.size():
            var b = buttons[i]
            if b is Button:
                b.set_meta("element", button_elements[i])
                b.text = button_elements[i]

# ------------------------------------------------------------------
# Input Handling
# ------------------------------------------------------------------

func _input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            # Mouse down
            var btn = get_button_under_mouse()
            if btn:
                is_dragging = true
                current_dragged_button = btn
                # Add visual feedback
                current_dragged_button.scale = Vector2(1.1, 1.1)
        else:
            # Mouse released
            if is_dragging and current_dragged_button:
                is_dragging = false
                handle_snap(current_dragged_button)
                # Reset visual feedback
                current_dragged_button.scale = Vector2(1, 1)
                current_dragged_button = null
    elif event is InputEventMouseMotion and is_dragging and current_dragged_button:
        # Drag the button
        var b = current_dragged_button
        b.position += event.relative

        # Optionally clamp inside viewport
        var vp_size = get_viewport_rect().size
        b.position.x = clamp(b.position.x, 0, vp_size.x - b.size.x)
        b.position.y = clamp(b.position.y, 0, vp_size.y - b.size.y)

func get_button_under_mouse() -> Button:
    var mp = get_global_mouse_position()
    for child in button_container.get_children():
        if child is Button:
            if child.get_global_rect().has_point(mp):
                return child
    return null

# ------------------------------------------------------------------
# Snapping Logic
# ------------------------------------------------------------------

func handle_snap(btn: Button) -> void:
    # Check if the button overlaps any drop_spot
    var area2d = btn.get_node("Area2D") if btn.has_node("Area2D") else null

    var snapped_spot: Node = null
    if area2d:
        for ds in drop_spots:
            # If the spot's overlapping_areas includes our button's area
            if ds.get_overlapping_areas().has(area2d):
                snapped_spot = ds
                break

    if snapped_spot:
        # Snap the button to the drop_spot
        snap_button_to_spot(btn, snapped_spot)
    else:
        # No snap -> animate back to original position
        animate_back(btn, original_position_map[btn])
        # Reset element_1 if this was the stored button
        if btn == element_1:
            element_1 = null
            original_pos_element_1 = Vector2.ZERO

# Snap button to drop_spot
func snap_button_to_spot(btn: Button, ds: Node) -> void:
    var collision_shape = ds.get_node("CollisionShape2D")
    var ds_size = Vector2.ZERO
    if collision_shape:
        if collision_shape.shape is RectangleShape2D:
            ds_size = collision_shape.shape.extents * 2
        elif collision_shape.shape is CircleShape2D:
            ds_size = Vector2(collision_shape.shape.radius * 2, collision_shape.shape.radius * 2)
    var target_pos = ds.global_position + ds_size / 2 - btn.size / 2
    target_pos.y -= 60  # Adjust offset as needed
    target_pos.x -= 50  # Adjust offset as needed

    # Animate to drop spot using code-based Tween
    var tween = create_tween()
    tween.tween_property(btn, "global_position", target_pos, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await tween.finished

    # If we didn't have an element_1 yet, store this as element_1
    if element_1 == null:
        element_1 = btn
        original_pos_element_1 = original_position_map[btn]
    else:
        # We have a second element
        var element_2 = btn
        var original_pos_element_2 = original_position_map[element_2]

        # Start the merge animation
        merge_elements(element_1, element_2, original_pos_element_1, original_pos_element_2)

# ------------------------------------------------------------------
# Merge Animation Logic
# ------------------------------------------------------------------

func merge_elements(elem1: Button, elem2: Button, _orig_pos1: Vector2, _orig_pos2: Vector2) -> void:
    # Disable further input during animation
    set_process_input(false)

    # Create a Tween instance
    var tween = create_tween()

    # Animate both buttons moving to the MERGE_POSITION
    tween.parallel()
    tween.tween_property(elem1, "global_position", MERGE_POSITION, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    var opposite_position = MERGE_POSITION + Vector2(elem1.size.x + 50, 0)  # 50 pixels extra spacing
    tween.tween_property(elem2, "global_position", opposite_position, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    # After movement, fade out both buttons
    tween.parallel()
    tween.tween_property(elem1, "modulate:a", 0, FADE_DURATION).set_delay(MOVE_DURATION)
    tween.tween_property(elem2, "modulate:a", 0, FADE_DURATION).set_delay(MOVE_DURATION)

    # After fading out, display the result label
    await tween.finished

    display_result_label(elem1, elem2)

func display_result_label(elem1: Button, elem2: Button) -> void:
    # Check combination correctness
    var is_correct = check_combination_correctness(elem1, elem2)

    # Update the result label
    if is_correct:
        result_label.text = "Correct!"
        result_label.label_settings.font_color = Color.GREEN
    else:
        var correct_elements = current_combination.get("elements", [])
        result_label.text = "Incorrect! Correct: " + str(correct_elements)
        result_label.label_settings.font_color = Color.RED

    # Hide the merged buttons
    elem1.visible = false
    elem2.visible = false

    # Animate the result label fade-in
    var result_tween = create_tween()
    result_label.modulate.a = 0
    result_label.visible = true
    result_tween.tween_property(result_label, "modulate:a", 1, FADE_DURATION).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

    # Wait for the result display duration
    await result_tween.finished
    await get_tree().create_timer(RESULT_DISPLAY_DURATION).timeout

    # Animate the result label fade-out
    var hide_tween = create_tween()
    hide_tween.tween_property(result_label, "modulate:a", 0, FADE_DURATION).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
    await hide_tween.finished

    # Hide the result label
    result_label.visible = false

    # Reset buttons' visibility and positions
    elem1.visible = true
    elem2.visible = true
    elem1.modulate.a = 1
    elem2.modulate.a = 1
    elem1.global_position = original_position_map[elem1]
    elem2.global_position = original_position_map[elem2]

    # Start a new round
    start_new_round()

    # Re-enable input
    set_process_input(true)

func check_combination_correctness(elem1: Button, elem2: Button) -> bool:
    var combined = [elem1.get_meta("element"), elem2.get_meta("element")]
    combined.sort()

    var correct_combo = current_combination.get("elements", []).duplicate()
    correct_combo.sort()

    return combined == correct_combo

# ------------------------------------------------------------------
# Animation Helper
# ------------------------------------------------------------------

func animate_back(button: Button, target_pos: Vector2) -> void:
    var tween = create_tween()
    tween.tween_property(button, "global_position", target_pos, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await tween.finished

# ------------------------------------------------------------------
# Result Label Styling
# ------------------------------------------------------------------

func style_result_label() -> void:
    # Style the result label to match Material Design
    var label_settings = LabelSettings.new()
    label_settings.font_color = Color.WHITE
    label_settings.font = load("res://fonts/Roboto-Bold.ttf")  # Ensure the font exists
    result_label.label_settings = label_settings
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_label.custom_minimum_size = Vector2(300, 50)
    result_label.global_position = MERGE_POSITION  # Position it at the merge point
    result_label.visible = false
    result_label.modulate.a = 0  # Start invisible

# ------------------------------------------------------------------
# Process Function
# ------------------------------------------------------------------

func _process(_delta):
    # Optional: Any per-frame updates or debug drawing
    pass
