extends Node2D

# Nodes
var button_container: GridContainer
var result_label: Label

# Game data
var combinations = []  # Load this from your singleton or JSON
var current_combination = {}  # To store the correct combination
var all_elements = []  # List of all elements for wrong answers
var selected_buttons = []  # To keep track of selected buttons

func _ready():
    # Reference the container and label nodes
    button_container = $ButtonCont  # Make sure this node exists in your scene
    result_label = $Label4          # Make sure this label exists in your scene

    # Load the combinations (replace this with your GameState call or JSON loading)
    if GameState.combinations.size() == 0:
        GameState.load_combinations()
    combinations = GameState.combinations
    all_elements = get_all_elements(combinations)

    # Pick a random combination
    current_combination = combinations[randi() % combinations.size()]

    # Generate the buttons
    generate_buttons()

    # Display the result for reference
    result_label.text = "Result: " + current_combination["result"]

# Function to get a list of all unique elements from the combinations
func get_all_elements(all_combinations):
    var elements = []
    for combination in all_combinations:
        elements.append_array(combination["elements"])  # Assuming each combination has "elements"
    return elements  # This ensures uniqueness is preserved

func clear_container(container):
    for child in container.get_children():
        child.queue_free()


func generate_buttons():
    
    # Clear existing buttons
    clear_container(button_container)

    # Get the two correct elements
    var correct_elements = current_combination["elements"]  # Assuming "elements" is a list

    # Generate 8 wrong elements (excluding the correct ones)
    var wrong_elements = all_elements.filter(func(e):
        return not correct_elements.has(e)
    )
    wrong_elements.shuffle()
    wrong_elements = wrong_elements.slice(0, 8)

    # Combine correct and wrong elements and shuffle
    var button_elements = correct_elements + wrong_elements
    button_elements.shuffle()

    # Create buttons dynamically
    for element in button_elements:
        var button = Button.new()
        button.text = element
        button.toggle_mode = true  # Enable toggle mode

        # Store the associated element as metadata
        button.set_meta("element", element)

        # Connect the button's signal
        button.connect("pressed", Callable(self, "_on_button_pressed").bind(button))
        button_container.add_child(button)

# Function to check result
func check_result():
    var a = selected_buttons.duplicate()
    var b = current_combination["elements"].duplicate()
    a.sort()
    b.sort()
    
    if a == b:
        result_label.text = "Correct!"
    else:
        result_label.text = "Incorrect!"
    # Reset the selected buttons
    selected_buttons.clear()

# Function called when a button is pressed
func _on_button_pressed(button):
    var selected_element = button.get_meta("element") # Retrieve the associated element

    if button.pressed:
        selected_buttons.append(selected_element)
    else:
        selected_buttons.erase(selected_element)
    # Check if two buttons are selected
    if selected_buttons.size() == 2:
        check_result()
