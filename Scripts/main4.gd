extends Node2D

# ------------------------------------------------------------------
# Nodes
# ------------------------------------------------------------------
@onready var button_container: Node2D = $ButtonsGroup
@onready var display_label: Label = $Label
@onready var result_label: Label = $Label4
@onready var score_label: Label = $ScoreLabel         # Score Label
@onready var attempts_label: Label = $AttemptsLabel   # Attempts Label
@onready var game_over_ui: Control = $GameOverUI     # Game Over UI
@onready var game_over_label: Label = $GameOverUI/Panel/GameOverLabel
@onready var play_again_button: Button = $GameOverUI/Panel/PlayAgainButton
@onready var return_to_menu_button: Button = $GameOverUI/Panel/ReturnToMenuButton

# ------------------------------------------------------------------
# Constants for Animation
# ------------------------------------------------------------------
const MERGE_POSITION: Vector2 = Vector2(300, -200)  # Adjust to your desired central position
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

# ------------------------------------------------------------------
# Score and Attempts
# ------------------------------------------------------------------
var score: int = 0
var attempts: int  # Set your desired starting number of attempts

# ------------------------------------------------------------------
# Ready Function
# ------------------------------------------------------------------
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
            original_position_map[child] = Vector2(child.global_position.x, -child.global_position.y)
    
    # (4) Style the result label
    style_result_label()
    
    # (5) Initialize score and attempts
    initialize_score_attempts()
    
    # (6) Style Score and Attempts Labels
    style_score_and_attempts_labels()
    
    # Ensure the Attempts Label is visible
    if attempts_label:
        attempts_label.visible = true
    else:
        print("Attempts Label not found! Check the node path.")
    
    # (7) Connect Game Over Buttons
    connect_game_over_buttons()
    
    # (8) Start the first round
    start_new_round()
    
    # Ensure the Game Over UI is hidden initially
    if game_over_ui:
        game_over_ui.visible = false
    else:
        print("GameOverUI not found! Check the node path.")

# ------------------------------------------------------------------
# Initialization for Score and Attempts
# ------------------------------------------------------------------

func initialize_score_attempts() -> void:
    score = 0
    attempts = 3  # Set your desired starting number of attempts
    update_score_label()
    update_attempts_label()
    print("Initialized attempts to:", attempts)  # Debugging

func update_score_label() -> void:
    if score_label:
        score_label.text = "Score: " + str(score)
        print("Updated Score Label:", score_label.text)  # Debugging
    else:
        print("Score Label is null!")

func update_attempts_label() -> void:
    if attempts_label:
        attempts_label.text = "Attempts: " + str(attempts)
        print("Updated Attempts Label:", attempts_label.text)  # Debugging
    else:
        print("Attempts Label is null!")

# ------------------------------------------------------------------
# Styling Labels with Custom Fonts and Sizes
# ------------------------------------------------------------------

func style_score_and_attempts_labels() -> void:
    # Load the custom font
    var custom_font = load("res://fonts/Roboto-Bold.ttf")
    if not custom_font:
        print("Failed to load custom font for Score and Attempts Labels")
        return
    custom_font.fixed_size = 36  # Set desired text size

    # Apply the font to Score and Attempts Labels
    var label_settings = LabelSettings.new()
    label_settings.font = custom_font
    label_settings.font_color = Color(1, 1, 1)  # White color
    
    if score_label:
        score_label.label_settings = label_settings
    else:
        print("Score Label is null!")
        
    if attempts_label:
        attempts_label.label_settings = label_settings.duplicate()
    else:
        print("Attempts Label is null!")

    # Ensure labels are visible
    if score_label:
        score_label.visible = true
    if attempts_label:
        attempts_label.visible = true

    # Style Game Over Label
    style_game_over_label(custom_font)

func style_game_over_label(custom_font: FontFile = null) -> void:
    # Load a larger custom font for Game Over
    var game_over_font: FontFile = custom_font if custom_font else load("res://fonts/Roboto-Bold.ttf")
    if not game_over_font:
        print("Failed to load custom font for Game Over Label")
        return
    game_over_font.fixed_size = 48  # Larger text size for emphasis

    # Apply the font to the Game Over Label
    var label_settings = LabelSettings.new()
    label_settings.font = game_over_font
    label_settings.font_color = Color(1, 0, 0)  # Red color for visibility
    game_over_label.label_settings = label_settings
    game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    game_over_label.visible = false  # Hidden initially

# ------------------------------------------------------------------
# Connecting Game Over Buttons
# ------------------------------------------------------------------

func connect_game_over_buttons() -> void:
    play_again_button.pressed.connect(_on_PlayAgainButton_pressed)
    return_to_menu_button.pressed.connect(_on_ReturnToMenuButton_pressed)

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
    print("Starting a new round")  # Debugging
    # Pick a random combination
    if combinations.size() == 0:
        print("No combinations available!")
        return
    current_combination = combinations[randi() % combinations.size()]
    
    if display_label:
        display_label.text = str(current_combination.get("result", "???"))
    else:
        print("Display Label is null!")
    
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
                var orig_pos = original_position_map[btn]
                btn.global_position = Vector2(orig_pos.x, -orig_pos.y)  # Adjust for bottom-center
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
        else:
            print("Not enough elements to assign to buttons.")

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
        b.position.x = clamp(b.position.x, -vp_size.x / 2, vp_size.x / 2 - b.size.x)
        b.position.y = clamp(b.position.y, -vp_size.y, -b.size.y)  # Clamp above bottom-center

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
    var _ds_size = Vector2.ZERO
    if collision_shape:
        if collision_shape.shape is RectangleShape2D:
            _ds_size = collision_shape.shape.extents * 2
        elif collision_shape.shape is CircleShape2D:
            _ds_size = Vector2(collision_shape.shape.radius * 2, collision_shape.shape.radius * 2)
    var target_pos = Vector2(ds.global_position.x, ds.global_position.y)  # Adjust for bottom-center
    target_pos += Vector2(-btn.size.x / 2, -btn.size.y / 2)  # Center button on drop spot

    var tween = create_tween()
    tween.tween_property(btn, "global_position", target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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

    # Correct the merge position for the bottom-center coordinate system
    var corrected_merge_position = Vector2(MERGE_POSITION.x, -MERGE_POSITION.y)

    # Calculate positions for the animation
    var element1_target_pos = corrected_merge_position
    var element2_target_pos = corrected_merge_position + Vector2(elem1.size.x + 50, 0)  # Offset to the side

    # Debugging positions
    print("Merge Position:", corrected_merge_position)
    print("Element 1 Target Position:", element1_target_pos)
    print("Element 2 Target Position:", element2_target_pos)

    # Create a Tween instance for animation
    var tween = create_tween()

    # Animate both buttons moving to their respective target positions
    tween.parallel()
    tween.tween_property(elem1, "global_position", element1_target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(elem2, "global_position", element2_target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    # After moving, fade out both buttons
    tween.parallel()
    tween.tween_property(elem1, "modulate:a", 0, FADE_DURATION).set_delay(MOVE_DURATION)
    tween.tween_property(elem2, "modulate:a", 0, FADE_DURATION).set_delay(MOVE_DURATION)

    # Wait for the animation to finish
    await tween.finished

    # Handle the result display
    display_result_label(elem1, elem2)

# ------------------------------------------------------------------
# Merge Result and Score/Attempts Update
# ------------------------------------------------------------------

func display_result_label(elem1: Button, elem2: Button, font_size: int = 36) -> void:
    # Check combination correctness
    var is_correct = check_combination_correctness(elem1, elem2)

    # Update the result label text and color based on correctness
    if is_correct:
        result_label.text = "Correct! " + elem1.text + " + " + elem2.text + " = " + current_combination.get("result", "")
        result_label.modulate = Color(0, 1, 0)  # Green color

        # Update score based on difficulty
        var difficulty = current_combination.get("difficulty", 1)  # Assume each combination has a 'difficulty' key
        score += 10 * difficulty  # Example scoring: 10 points per difficulty level
        update_score_label()
    else:
        var correct_elements = current_combination.get("elements", [])
        result_label.text = "Incorrect! Correct: " + str(correct_elements)
        result_label.modulate = Color(1, 0, 0)  # Red color

        # Deduct an attempt
        attempts -= 1
        update_attempts_label()

        if attempts <= 0:
            handle_game_over()

    # Set the font size and style
    var label_settings = LabelSettings.new()
    label_settings.font = load("res://fonts/Roboto-Bold.ttf")
    if not label_settings.font:
        print("Failed to load font for Result Label")
    label_settings.font_size = font_size
    result_label.label_settings = label_settings

    # Position the result label at the merge position
    var corrected_merge_position = Vector2(MERGE_POSITION.x, -MERGE_POSITION.y)
    result_label.pivot_offset = result_label.size / 2
    result_label.global_position = corrected_merge_position

    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    # Make the label visible and animate it
    result_label.visible = true

    # Create a tween for the flashy effect
    var tween = create_tween()
    tween.tween_property(result_label, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(result_label, "scale", Vector2(0.7, 0.7), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(result_label, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

    # Wait for the result display duration
    await get_tree().create_timer(RESULT_DISPLAY_DURATION).timeout

    # Hide the result label
    result_label.visible = false

    # Reset buttons' visibility and positions
    elem1.visible = true
    elem2.visible = true
    elem1.global_position = Vector2(original_position_map[elem1].x, -original_position_map[elem1].y)
    elem2.global_position = Vector2(original_position_map[elem2].x, -original_position_map[elem2].y)

    # Start a new round
    start_new_round()

    # Re-enable input
    set_process_input(true)

# ------------------------------------------------------------------
# Handle Game Over
# ------------------------------------------------------------------

func handle_game_over() -> void:
    print("Game Over triggered")  # Debugging
    # Update Game Over Label with final score
    game_over_label.text = "Game Over!\nFinal Score: " + str(score)
    game_over_label.visible = true

    # Show the Game Over UI
    game_over_ui.visible = true

    # Disable all buttons to prevent further interactions
    for btn in button_container.get_children():
        if btn is Button:
            btn.disabled = true

    # Pause the game
    get_tree().paused = true

# ------------------------------------------------------------------
# Game Over Button Callbacks
# ------------------------------------------------------------------

func _on_PlayAgainButton_pressed() -> void:
    print("Play Again button pressed")  # Debugging
    # Reset score and attempts
    initialize_score_attempts()

    # Hide Game Over UI
    game_over_ui.visible = false

    # Re-enable all buttons
    for btn in button_container.get_children():
        if btn is Button:
            btn.disabled = false

    # Reset Game Over Label
    game_over_label.visible = false

    # Resume the game
    get_tree().paused = false

    # Start a new round
    start_new_round()

func _on_ReturnToMenuButton_pressed() -> void:
    print("Return to Menu button pressed")  # Debugging
    # Optionally, save the score or perform other cleanup tasks here

    # Load the main menu scene
    # Ensure you have a main menu scene at 'res://MainMenu.tscn'
    get_tree().paused = false  # Unpause before changing scenes
    get_tree().change_scene("res://MainMenu.tscn")

# ------------------------------------------------------------------
# Check Combination Correctness
# ------------------------------------------------------------------

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
    var adjusted_target_pos = Vector2(target_pos.x, -target_pos.y)  # Correct for bottom-center
    var tween = create_tween()
    tween.tween_property(button, "global_position", adjusted_target_pos, MOVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    await tween.finished

# ------------------------------------------------------------------
# Result Label Styling
# ------------------------------------------------------------------

func style_result_label() -> void:
    # Style the result label to match Material Design
    var label_settings = LabelSettings.new()
    label_settings.font_color = Color.WHITE
    label_settings.font = load("res://fonts/Roboto-Bold.ttf")  # Ensure the font exists
    if not label_settings.font:
        print("Failed to load font for Result Label")
    result_label.custom_minimum_size = Vector2(300, 50)
    result_label.label_settings = label_settings
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_label.global_position = MERGE_POSITION  # Position it at the merge point
    result_label.visible = false
    result_label.modulate.a = 0  # Start invisible

# ------------------------------------------------------------------
# Process Function
# ------------------------------------------------------------------

func _process(_delta):
    # Optional: Any per-frame updates or debug drawing
    pass
