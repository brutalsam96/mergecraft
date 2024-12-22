extends Node2D

# Nodes
@onready var button_container: Control = $ButtonCont  # Change GridContainer to Control node in the scene
@onready var result_label: Label = $Label4                  # Ensure this label exists in your scene

# Game data
var combinations: Array = []           # Load this from your singleton or JSON
var current_combination: Dictionary = {}    # To store the correct combination
var all_elements: Array = []           # List of all elements for wrong answers
var selected_buttons: Array = []       # To keep track of selected buttons
var is_dragging: bool = false         # Flag to track if the user is dragging
var dragged_elements: Dictionary = {}       # To prevent multiple selections of the same button during a drag

func _ready():
    # Load the combinations (replace this with your GameState call or JSON loading)
    if GameState.combinations.size() == 0:
        GameState.load_combinations()
    combinations = GameState.combinations
    all_elements = get_all_unique_elements(combinations)
    
    # Start the first round
    start_new_round()
    
    # Enable input processing
    set_process_input(true)

# Function to get a list of all unique elements from the combinations
func get_all_unique_elements(all_combinations: Array) -> Array:
    var elements: Array = []
    for combination in all_combinations:
        for element in combination["elements"]:
            if not elements.has(element):
                elements.append(element)
    return elements  # Ensures uniqueness

func clear_container(container: Control) -> void:
    for child in container.get_children():
        child.queue_free()

func start_new_round() -> void:
    # Pick a random combination
    current_combination = combinations[randi() % combinations.size()]
    
    # Generate the buttons
    generate_buttons()
    
    # Display the target result for reference (you can remove or modify this in the actual game)
    result_label.text = "Find: " + str(current_combination["result"])
    
    # Reset selected buttons
    selected_buttons.clear()

func generate_buttons() -> void:
    # Clear existing buttons
    clear_container(button_container)

    # Get the correct elements
    var correct_elements: Array = current_combination["elements"]  # Assuming "elements" is a list

    # Generate wrong elements (excluding the correct ones)
    var wrong_elements: Array = all_elements.filter(func(e):
        return not current_combination["elements"].has(e)
    )
    wrong_elements.shuffle()

    # Ensure there are enough wrong elements
    var num_wrong: int = 10  # Updating to include 12 total items
    if wrong_elements.size() < num_wrong:
        num_wrong = wrong_elements.size()

    wrong_elements = wrong_elements.slice(0, num_wrong)

    # Combine correct and wrong elements and shuffle
    var button_elements: Array = correct_elements + wrong_elements
    button_elements.shuffle()

    # Ensure we have exactly 12 items
    button_elements = button_elements.slice(0, 12)

    var example_button_scene = preload("res://Scenes/button.tscn")
    var button_size = Vector2(80, 40)  # Fixed button size
    var cols = 3  # Number of columns
    var rows = ceil(float(button_elements.size()) / cols)  # Calculate number of rows

    # Get container size
    var container_size = button_container.size

    # Calculate spacing between buttons
    var total_button_width = cols * button_size.x
    var total_button_height = rows * button_size.y
    var col_spacing = (container_size.x - total_button_width) / (cols) if cols > 1 else 0
    var row_spacing = (container_size.y - total_button_height) / (rows) if rows > 1 else 0

    # Calculate the starting offset to center the grid
    var start_x = (container_size.x - total_button_width - col_spacing * (cols - 1)) / 2
    var start_y = (container_size.y - total_button_height - row_spacing * (rows - 1)) / 2

    # Create and position buttons
    for i in range(button_elements.size()):
        var col = i % cols  # Column index
        var row = floori(float(i) / cols)  # Row index

        # Calculate the position of the button
        var pos_x = start_x + col * (button_size.x + col_spacing)
        var pos_y = start_y + row * (button_size.y + row_spacing)

        # Instance the button
        var button: Button = example_button_scene.instantiate()
        button.text = button_elements[i]
        button.name = "ElementButton"  # Assign a name for identification

        # Store the associated element as metadata
        button.set_meta("element", button_elements[i])

        # Connect the button's "pressed" signal to the handler with parameters
        button.pressed.connect(self._on_button_pressed.bind(button))

        # Add button to container and set its position
        button_container.add_child(button)
        button.set_anchors_preset(Control.PRESET_CENTER)
        button.position = Vector2(pos_x, pos_y)


# Function to handle input events for drag selection
func _input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                is_dragging = true
                dragged_elements.clear()
            else:
                is_dragging = false
                # After drag ends, check the result if two elements are selected
                if selected_buttons.size() == 2:
                    check_result()
    elif event is InputEventMouseMotion and is_dragging:
        var mouse_pos: Vector2 = get_local_mouse_position()
        var control: Control = get_child_at_position(button_container, mouse_pos)
        if control and control is Button:
            var element: String = control.get_meta("element")
            if not dragged_elements.has(element):
                dragged_elements[element] = true
                selected_buttons.append(element)
                if selected_buttons.size() == 2:
                    is_dragging = false
                    check_result()

# Utility function to get the child Control at a given position
func get_child_at_position(container: Control, pos: Vector2) -> Control:
    var global_pos: Vector2 = container.get_global_transform().basis_xform(pos)
    for child in container.get_children():
        if child is Control:
            var child_rect: Rect2 = child.get_global_rect()
            if child_rect.has_point(global_pos):
                return child
    return null

# Function to check the result
func check_result() -> void:
    var selected: Array = selected_buttons.duplicate()
    var correct: Array = current_combination["elements"].duplicate()
    selected.sort()
    correct.sort()
    
    if selected == correct:
        result_label.text = "Correct!"
    else:
        result_label.text = "Incorrect! The correct answer was: " + str(current_combination["elements"])
    
    # Reset selections and prepare for the next round after a delay
    selected_buttons.clear()
    # Reset button colors
    #reset_button_colors()
    # Start a timer to proceed to the next round
    await get_tree().create_timer(2.0).timeout  # 2-second delay
    start_new_round()

# Function to reset button visual states
#func reset_button_colors() -> void:
    #for button in button_container.get_children():
        #if button is Button:
            #button.clear_color_override("font_color")

# Function called when a button is pressed (click fallback)
func _on_button_pressed(button: Button) -> void:
    var selected_element: String = button.get_meta("element")  # Retrieve the associated element
    
    if selected_buttons.has(selected_element):
        selected_buttons.erase(selected_element)
        #button.add_color_override("font_color", Color(1, 1, 1))  # Reset color to white
    else:
        selected_buttons.append(selected_element)
        #button.add_color_override("font_color", Color(1, 0, 0))  # Highlight selection in red
    
    # Check if two buttons are selected
    if selected_buttons.size() == 2:
        check_result()
