extends RefCounted
class_name EnemyAI

func plan_movement(enemy_units: Array[Node2D], player_units: Array[Node2D], hex_map: TileMapLayer, occupied_cells: Dictionary) -> Array[Dictionary]:
	var planned_moves: Array[Dictionary] = []
	if enemy_units.is_empty() or player_units.is_empty():
		return planned_moves

	var simulated_occupied := occupied_cells.duplicate()

	for enemy in enemy_units:
		if not is_instance_valid(enemy):
			continue

		var start_cell: Vector2i = enemy.grid_cell
		var movement_points = max(int(enemy.moves_left), 0)
		if movement_points <= 0:
			continue

		var reachable_cells := _get_reachable_cells(start_cell, movement_points, hex_map, simulated_occupied)
		var target_cell := _choose_best_cell(start_cell, reachable_cells, player_units, hex_map)
		if target_cell == start_cell:
			continue

		var move_cost := int(reachable_cells[target_cell])
		simulated_occupied.erase(start_cell)
		simulated_occupied[target_cell] = enemy

		planned_moves.append({
			"unit": enemy,
			"to_cell": target_cell,
			"cost": move_cost,
		})

	return planned_moves

func _get_reachable_cells(start_cell: Vector2i, movement_points: int, hex_map: TileMapLayer, occupied_cells: Dictionary) -> Dictionary:
	var visited_distance := {start_cell: 0} # Dictionary[Vector2i, int]
	var frontier: Array[Vector2i] = [start_cell]

	while not frontier.is_empty():
		var current_cell = frontier.pop_front()
		var current_distance: int = int(visited_distance[current_cell])
		if current_distance >= movement_points:
			continue

		for neighbor in hex_map.get_surrounding_cells(current_cell):
			if visited_distance.has(neighbor):
				continue
			if not _can_move_through_cell(neighbor, start_cell, hex_map, occupied_cells):
				continue

			visited_distance[neighbor] = current_distance + 1
			frontier.append(neighbor)

	return visited_distance

func _can_move_through_cell(cell: Vector2i, start_cell: Vector2i, hex_map: TileMapLayer, occupied_cells: Dictionary) -> bool:
	if not _has_walkable_terrain(hex_map, cell):
		return false
	if cell != start_cell and occupied_cells.has(cell):
		return false
	return true

func _has_walkable_terrain(hex_map: TileMapLayer, cell: Vector2i) -> bool:
	if hex_map.get_cell_source_id(cell) == -1:
		return false

	var tile_data := hex_map.get_cell_tile_data(cell)
	if tile_data == null:
		return false

	return bool(tile_data.get_custom_data("Walkable"))

func _choose_best_cell(start_cell: Vector2i, reachable_cells: Dictionary, player_units: Array[Node2D], hex_map: TileMapLayer) -> Vector2i:
	var best_cell := start_cell
	var best_distance := INF
	var best_move_cost := -1

	for key in reachable_cells.keys():
		var candidate_cell: Vector2i = key
		if candidate_cell == start_cell:
			continue

		var candidate_distance := _distance_to_nearest_player(candidate_cell, player_units, hex_map)
		var move_cost := int(reachable_cells[candidate_cell])

		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_move_cost = move_cost
			best_cell = candidate_cell
		elif is_equal_approx(candidate_distance, best_distance) and move_cost > best_move_cost:
			best_move_cost = move_cost
			best_cell = candidate_cell

	return best_cell

func _distance_to_nearest_player(cell: Vector2i, player_units: Array[Node2D], hex_map: TileMapLayer) -> float:
	var nearest := INF
	var cell_local := hex_map.map_to_local(cell)

	for player_unit in player_units:
		if not is_instance_valid(player_unit):
			continue
		var target_local := hex_map.map_to_local(player_unit.grid_cell)
		var distance := cell_local.distance_squared_to(target_local)
		if distance < nearest:
			nearest = distance

	return nearest
