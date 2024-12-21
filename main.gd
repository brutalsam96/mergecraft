extends Node2D

# Nodes
var result_label: Label
var category_label: Label
var diff_label: Label
var level_label: Label
var combinations = []
var filtered_combinations = []
var level = 1

func _ready():
	# Reference the nodes
	result_label = $Label
	category_label = $Label2
	diff_label = $Label3
	level_label = $Label4

	# Initialize the level counter
	level_label.text = "Level: " + str(level)

	# Load combinations from JSON file
	var file_instance = FileAccess.open("res://elements.json", FileAccess.READ)
	if file_instance:
		var json_data = file_instance.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_data)
		if parse_result == OK:
			combinations = json.data["combinations"]
			update_filtered_combinations()
		else:
			print("Failed to parse JSON")
		file_instance.close()
	else:
		print("elements.json not found")

	# Connect the Button signal to the randomize function
	$Button.connect("pressed", Callable(self, "_on_button_pressed"))

# Function to update the filtered combinations based on difficulty tiers
func update_filtered_combinations():
	if level <= 5:
		filtered_combinations = combinations.filter(func(c):
			return c["difficulty"] >= 1 and c["difficulty"] <= 3
		)
	elif level <= 11:
		filtered_combinations = combinations.filter(func(c):
			return c["difficulty"] >= 3 and c["difficulty"] <= 6
		)
	else:
		filtered_combinations = combinations.filter(func(c):
			return c["difficulty"] >= 6 and c["difficulty"] <= 10
		)

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
		update_filtered_combinations()
	else:
		result_label.text = "No combinations available"
		category_label.text = ""
