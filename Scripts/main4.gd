extends Node2D

# Nodes
@onready var button_container: Node2D = $ButtonsGroup
@onready var result_label: Label = $Label4



# Game data
var combinations: Array = []           # Loaded combinations
var current_combination: Dictionary = {}    # Stores the current correct combination
var all_elements: Array = []           # List of all elements for wrong answers
var selected_buttons: Array = []       # Tracks selected buttons during drag
var dragged_elements: Dictionary = {}  # Prevents multiple selections of the same button during a drag
var is_dragging: bool = false          # Tracks drag state
var current_dragged_button: Button = null   # Tracks the button being dragged
var element_1: Button = null           # Tracks the first element snapped to the center
var drop_spots

func _ready():
    drop_spots = get_tree().get_nodes_in_group("drop_spot_group")
    print(drop_spots)
    # Load combinations from GameState
    if GameState.combinations.size() == 0:
        GameState.load_combinations()
    combinations = GameState.combinations
    all_elements = get_all_unique_elements(combinations)

    # Start the first round
    start_new_round()

# Get a list of all unique elements from the combinations
func get_all_unique_elements(all_combinations: Array) -> Array:
    var elements: Array = []
    for combination in all_combinations:
        for element in combination["elements"]:
            if not elements.has(element):
                elements.append(element)
    return elements

# Start a new round by assigning elements and resetting the result label
func start_new_round() -> void:
    current_combination = combinations[randi() % combinations.size()]
    if result_label:
        result_label.text = "Find: " + str(current_combination.get("result", "Unknown"))
    selected_buttons.clear()
    element_1 = null

    assign_elements_to_buttons()

# Assign 2 correct and 8 wrong elements to premade buttons
func assign_elements_to_buttons() -> void:
    var buttons = button_container.get_children()

    # Select 2 correct elements
    var correct_elements: Array = current_combination.get("elements", []).duplicate()
    correct_elements.shuffle()
    correct_elements = correct_elements.slice(0, 2)

    # Select 8 wrong elements
    var wrong_elements: Array = all_elements.filter(func(e):
        return not correct_elements.has(e)
    )
    wrong_elements.shuffle()
    wrong_elements = wrong_elements.slice(0, 8)

    # Combine and shuffle all elements
    var button_elements: Array = correct_elements + wrong_elements
    button_elements.shuffle()

    # Assign elements to buttons
    for i in range(min(buttons.size(), button_elements.size())):
        var button = buttons[i]
        if button is Button:
            button.set_meta("element", button_elements[i])
            button.text = button_elements[i]

# Handle drag-and-drop input
func _input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            var button = get_button_under_mouse()
            var area2d = null
            if button:
                area2d = button.get_node("Area2D")
            if event.pressed:
                if button:
                    current_dragged_button = button
                    is_dragging = true
            else:
                if is_dragging and current_dragged_button:
                    current_dragged_button = null
                    is_dragging = false
                    for drop_spot in drop_spots:
                        if area2d and drop_spot.get_overlapping_areas() and drop_spot.get_overlapping_areas().has(area2d) and current_dragged_button != null:
                            var snap_position = drop_spot.global_position
                            current_dragged_button.global_position = snap_position
                            var tween = create_tween()
                            tween.set_trans(Tween.TRANS_LINEAR)
                            tween.tween_property(current_dragged_button, "global_position", snap_position, 0.2)
                            await tween.finished
                            if element_1 == null:
                                element_1 = current_dragged_button
                            else:
                                combine_elements(element_1, current_dragged_button)
    elif event is InputEventMouseMotion and is_dragging and current_dragged_button:
        var new_position = current_dragged_button.position + event.relative
        # Add bounds checking
        new_position.x = clamp(new_position.x, 0, get_viewport_rect().size.x)
        new_position.y = clamp(new_position.y, 0, get_viewport_rect().size.y)
        current_dragged_button.position = new_position

# Get the button under the mouse cursor
func get_button_under_mouse() -> Button:
    for child in button_container.get_children():
        if child is Button and child.get_global_rect().has_point(get_global_mouse_position()):
            return child
    return null


# Combine elements and check the result
func combine_elements(element_one: Button, element_two: Button):
    var combined = [element_one.get_meta("element"), element_two.get_meta("element")]
    combined.sort()
    var correct_combination = current_combination.get("elements", []).duplicate()
    correct_combination.sort()

    if combined == correct_combination:
        if result_label:
            result_label.text = "Correct!"
    else:
        if result_label:
            result_label.text = "Incorrect! The correct answer was: " + str(current_combination.get("elements", []))

    # Reset elements
    element_1 = null
    selected_buttons.clear()
    await get_tree().create_timer(2.0).timeout
    start_new_round()


func _process(_delta):
    queue_redraw()
