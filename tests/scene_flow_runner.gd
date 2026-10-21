extends Node

var checks: int = 0
var failures: int = 0

func _ready() -> void:
 run.call_deferred()

func check(ok: bool, description: String) -> void:
 checks += 1
 if ok: print("PASS: "+description)
 else:
  failures += 1
  push_error("FAIL: "+description)

func run() -> void:
 var academy: UnitAcademy = (load("res://scenes/unit_academy.tscn") as PackedScene).instantiate() as UnitAcademy
 get_tree().root.add_child(academy)
 get_tree().current_scene = academy
 await get_tree().process_frame
 academy.select_unit("diamond")
 academy.save_opening()
 var opening: String = TacticalBrain.opening_prompt
 check(opening == UnitDossier.DATA["diamond"]["prompt"],"菜单保存兵种推荐指令")
 academy.select_unit("triangle")
 check(TacticalBrain.opening_prompt == opening,"仅切换名册不覆盖开局指令")
 academy.launch_battle()
 await get_tree().scene_changed
 var menu: MainMenu = get_tree().current_scene as MainMenu
 menu.select_map("flanks")
 menu.launch_battle()
 await get_tree().scene_changed
 var arena: MainArena = get_tree().current_scene as MainArena
 check(is_instance_valid(arena) and arena.phase == MainArena.Phase.PREPARING,"真实场景切换进入战前准备")
 check(TacticalBrain.last_prompts[0] == opening,"场景切换后开局指令未被初始化清除")
 check(get_window().content_scale_size == Vector2i(1920,1080),"进入战场恢复原有逻辑画布尺寸")
 arena.start_match()
 arena.hud.call("request_menu_exit")
 var dialog: ConfirmationDialog = arena.hud.get("return_dialog") as ConfirmationDialog
 check(get_tree().paused and dialog.visible,"放弃确认期间暂停战斗")
 dialog.canceled.emit()
 dialog.hide()
 check(not get_tree().paused and arena.phase == MainArena.Phase.PLAYING,"取消确认恢复对局")
 arena.hud.call("request_menu_exit")
 dialog.confirmed.emit()
 await get_tree().scene_changed
 menu = get_tree().current_scene as MainMenu
 check(is_instance_valid(menu) and not get_tree().paused,"确认后返回可运行主菜单并清除暂停")
 check(TacticalBrain.opening_prompt == opening,"返回菜单保留默认开局指令")
 menu.launch_battle()
 await get_tree().scene_changed
 arena = get_tree().current_scene as MainArena
 check(TacticalBrain.last_prompts[0] == opening and arena.flux[0] == 180.0,"再次进入重置对局且保留开局设置")
 arena.restart()
 await get_tree().scene_changed
 check(TacticalBrain.last_prompts[0] == opening,"重开保留本次运行内默认开局")
 check((get_tree().current_scene as MainArena).map_id == "flanks","真实返回再进入及重开保留选定地图")
 print("FLOW_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures == 0 else 1)
