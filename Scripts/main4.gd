extends Node2D

# ------------------------------------------------------------------
# Nodes
# ------------------------------------------------------------------
@onready var button_container: Node2D = $ButtonsGroup
@onready var result_label: Label = $Label4

# ------------------------------------------------------------------
# Game data
# ------------------------------------------------------------------
var combinations: Array = []                  # All loaded combos
var current_combination: Dictionary = {}      # The current correct combo
var all_elements: Array = []                  # All possible elements
var drop_spots: Array = []                    # Areas to snap onto

# ------------------------------------------------------------------
# Drag tracking
# ------------------------------------------------------------------
var is_dragging: bool = false
var current_dragged_button: Button = null
var original_position_map: Dictionary = {}  # Maps button -> original_position

# ------------------------------------------------------------------
# Snap tracking: we only need two items
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

    # (4) Start the first round
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


# Assign 2 correct + 8 random wrong
func reset_and_assign_buttons() -> void:
    # Gather references
    var buttons = button_container.get_children()

    # Return each button to its original position & clear any tween leftovers
    # (In case a tween was half-finished or a button was left snapped)
    for btn in buttons:
        if btn is Button:
            if original_position_map.has(btn):
                btn.global_position = original_position_map[btn]
            # Also reset scale, rotation, or anything else if needed
            btn.set_scale(Vector2.ONE)
            # If you want to kill any leftover tweens on the button:
            for tween in btn.get_tree().get_nodes_in_group("tween"):
                # This might be overkill, but ensures no leftover animations
                if tween.is_a_parent_of(btn):
                    tween.kill()

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
        else:
            # Mouse released
            if is_dragging and current_dragged_button:
                is_dragging = false
                handle_snap(current_dragged_button)
                current_dragged_button = null

    elif event is InputEventMouseMotion and is_dragging and current_dragged_button:
        # Drag the button
        var b = current_dragged_button
        b.position += event.relative

        # Optionally clamp inside viewport
        var vp_size = get_viewport_rect().size
        b.position.x = clamp(b.position.x, 0, vp_size.x)
        b.position.y = clamp(b.position.y, 0, vp_size.y)


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


# Snap button to drop_spot
func snap_button_to_spot(btn: Button, ds: Node) -> void:
    var target_pos = ds.global_position
    
    # Animate to drop spot
    var tween = create_tween()
    tween.tween_property(btn, "global_position", target_pos, 0.2)
    await tween.finished

    # If we didn't have an element_1 yet, store this as element_1
    if element_1 == null:
        element_1 = btn
        original_pos_element_1 = original_position_map[btn]

    else:
        # We have a second element
        var element_2 = btn
        var original_pos_element_2 = original_position_map[element_2]

        # 1) Check correctness
        var _is_correct = check_combination_correctness(element_1, element_2)

        # 2) Animate both back
        await animate_back(element_1, original_pos_element_1)
        await animate_back(element_2, original_pos_element_2)

        # 3) Clear out for next usage
        element_1 = null

        # 4) Show result label for a bit
        await get_tree().create_timer(1.0).timeout

        # 5) Start new round
        start_new_round()


func check_combination_correctness(elem1: Button, elem2: Button) -> bool:
    var combined = [elem1.get_meta("element"), elem2.get_meta("element")]
    combined.sort()

    var correct_combo = current_combination.get("elements", []).duplicate()
    correct_combo.sort()

    if combined == correct_combo:
        if result_label:
            result_label.text = "Correct!"
        return true
    else:
        if result_label:
            result_label.text = "Incorrect! The correct was: %s" % str(current_combination["elements"])
        return false


# ------------------------------------------------------------------
# Animation Helper
# ------------------------------------------------------------------
func animate_back(button: Button, target_pos: Vector2) -> void:
    var tween = create_tween()
    tween.tween_property(button, "global_position", target_pos, 0.2)
    await tween.finished


func _process(_delta):
    # Optional drawing or debug
    queue_redraw()
