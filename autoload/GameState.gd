extends Node

# Persistnent data
var combinations = []
var filtered_combinations = []

# Load combinations from the JSON file
func load_combinations():
	var file_instance = FileAccess.open("res://elements.json", FileAccess.READ)
	if file_instance:
		var json_data = file_instance.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_data)
		if parse_result == OK:
			combinations = json.data["combinations"]
		else:
			print("Failed to parse JSON")
		file_instance.close()
	else:
		print("elements.json not found")

# Filter combinations based on level and difficulty
func get_filtered_combinations(level):
	if level <= 5:
		return combinations.filter(func(c):
			return c["difficulty"] >= 1 and c["difficulty"] <= 3
		)
	elif level <= 11:
		return combinations.filter(func(c):
			return c["difficulty"] >= 3 and c["difficulty"] <= 6
		)
	else:
		return combinations.filter(func(c):
			return c["difficulty"] >= 6 and c["difficulty"] <= 10
	)
