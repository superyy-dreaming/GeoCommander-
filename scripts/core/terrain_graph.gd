class_name TerrainGraph
extends AStar2D

var portal_edges: Dictionary = {}

func _estimate_cost(_from_id: int, _end_id: int) -> float:
 return 0.0

func _compute_cost(from_id: int, to_id: int) -> float:
 if portal_edges.has(Vector2i(from_id,to_id)): return 1.0
 return get_point_position(from_id).distance_to(get_point_position(to_id))
