extends Node

var checks: int = 0
var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.values = GameSettings.DEFAULTS.duplicate(true)
	var arena: MainArena = MainArena.new()
	arena.ai_enabled = false
	add_child(arena)
	await settle()
	arena.hud.close_matrix()
	var preview_proposals: Array[Dictionary] = [
		{"slot":0,"recommend_score":79,"title":"侧翼绕后与高机动突击","reason":"优先沿上路推进，避开已识别的过载预警。"},
		{"slot":1,"recommend_score":76,"title":"分路运营与能源压制","reason":"分配上下路并保持可感知目标的压力。"},
		{"slot":2,"recommend_score":67,"title":"折光阵地与核心保护","reason":"方形保护前线，菱形利用可用反射面。"}
	]
	arena.hud.call("_copilot_proposals_updated",preview_proposals,"本地启发式建议",1)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
		get_window().size = dimensions
		for factor: float in [1.0,1.3,1.8]:
			GameSettings.set_value("font_scale",factor,false)
			await settle()
			var hud: Variant = arena.hud
			var adviser_rect: Rect2 = hud.copilot_panel.get_global_rect()
			var bounds: Rect2 = get_viewport().get_visible_rect()
			check(bounds.encloses(adviser_rect),"adviser fits viewport %s %.1f" % [dimensions,factor])
			check(adviser_rect.position.x >= bounds.size.x*0.6,"adviser stays on right %s %.1f" % [dimensions,factor])
			check(not adviser_rect.intersects(hud.actions_layout.get_global_rect()),"adviser avoids top actions %s %.1f" % [dimensions,factor])
			check(not adviser_rect.intersects(hud.status_layout.get_global_rect()),"adviser avoids status row %s %.1f" % [dimensions,factor])
			check(not adviser_rect.intersects(hud.squad_skill_row.get_global_rect()),"adviser avoids skill row %s %.1f" % [dimensions,factor])
			var tools_rect: Rect2 = hud.tool_tabs.get_global_rect() if hud.tool_tabs.visible else hud.bottom_layout.get_global_rect()
			check(not adviser_rect.intersects(tools_rect),"adviser avoids bottom tool panels %s %.1f" % [dimensions,factor])
			check(hud.copilot_cards.size()==3,"three proposal cards exist")
			if hud.copilot_cards.size()==3:
				check(hud.copilot_cards[0].get_global_rect().position.y < hud.copilot_cards[1].get_global_rect().position.y and hud.copilot_cards[1].get_global_rect().position.y < hud.copilot_cards[2].get_global_rect().position.y,"proposal cards are vertically ordered")
			check(hud.copilot_panel.mouse_filter==Control.MOUSE_FILTER_STOP and not hud.copilot_cards_scroll.mouse_force_pass_scroll_events,"adviser blocks click and scroll-through")
			check(hud.copilot_cards_scroll.size.y >= 32.0,"proposal list has a usable scroll area %s %.1f" % [dimensions,factor])
			if DisplayServer.get_name() != "headless" and dimensions == Vector2i(1440,900) and is_equal_approx(factor,1.3):
				await RenderingServer.frame_post_draw
				var frame: Image = get_viewport().get_texture().get_image()
				var capture_error: Error = frame.save_png("res://artifacts/copilot-right-1440x900.png")
				check(capture_error == OK,"native Metal layout screenshot saved")
	arena.queue_free()
	await settle()
	print("COPILOT_LAYOUT_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for failure: String in failures: push_error("COPILOT_LAYOUT_FAIL "+failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func settle() -> void:
	for index: int in range(6): await get_tree().process_frame

func check(result: bool, reason: String) -> void:
	checks += 1
	if not result: failures.append(reason)
