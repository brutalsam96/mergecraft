extends Node2D

# Nodes
var result_label: Label
var category_label: Label
var diff_label: Label
var level_label: Label

# Resettable game state
var level = 1
var filtered_combinations = []

func _ready():
	# Reference the nodes
	result_label = $Label
	category_label = $Label2
	diff_label = $Label3
	level_label = $Label4

	# Initialize the level counter
	reset_game()

	# Connect the Button signal to the randomize function
	$Button.connect("pressed", Callable(self, "_on_button_pressed"))

func reset_game():
	# Reset game state
	level = 1
	level_label.text = "Level: " + str(level)

	# Load combinations only once
	if GameState.combinations.size() == 0:
		GameState.load_combinations()

	# Get filtered combinations for the starting level
	filtered_combinations = GameState.get_filtered_combinations(level)

# Function to pick a random combination and update the labels
func _on_button_pressed():
	if filtered_combinations.size() > 0:
		var random_index = randi() % filtered_combinations.size()
		var random_combination = filtered_combinations[random_index]

		# Update the labels with the result, category, and difficulty
		result_label.text = "Result: " + random_combination["result"]
		category_label.text = "Category: " + random_combination["category"]
		diff_label.text = "Diff: " + str(random_combination["difficulty"])

		# Increment the level counter
		level += 1
		level_label.text = "Level: " + str(level)

		# Update the filtered combinations for the new level
		filtered_combinations = GameState.get_filtered_combinations(level)
	else:
		result_label.text = "No combinations available"
		category_label.text = ""

func _on_restart_game_pressed():
	reset_game()
