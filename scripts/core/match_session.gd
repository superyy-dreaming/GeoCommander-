extends Node

var selected_map_id: String = "balanced"
var menu_page: String = "home"
var pending_map_id: String = ""

func request_match(id: String) -> void:
 assert(id in MapCatalog.IDS)
 selected_map_id = id
 pending_map_id = id

func consume_map() -> String:
 var id: String = pending_map_id if not pending_map_id.is_empty() else "balanced"
 pending_map_id = ""
 return id
