extends Node

var checks: int = 0
var failures: int = 0

func check(ok: bool, description: String) -> void:
 checks += 1
 if ok: print("PASS: "+description)
 else:
  failures += 1
  push_error("FAIL: "+description)

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 await get_tree().process_frame
 await run()
 print("LAUNCHER_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures == 0 else 1)

func frames(count: int = 3) -> void:
 for n: int in range(count): await get_tree().process_frame

func run() -> void:
 GameSettings.storage_path = "user://launcher-test-settings.cfg"
 if "--persist-read" in OS.get_cmdline_user_args():
  GameSettings.load_settings()
  check(GameSettings.values["font_scale"] == 1.3 and GameSettings.values["camera_speed"] == 1.7 and GameSettings.values["reduced_motion"],"独立进程启动恢复上一进程设置")
  return
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 check(GameSettings.values["resolution"] == Vector2i(1440,810),"首次设置保持原默认窗口")
 check(not GameSettings.valid_value("font_scale",4) and not GameSettings.valid_value("reduced_motion","yes") and not GameSettings.valid_value("glow",NAN),"设置拒绝非法类型、字号与非有限值")
 GameSettings.set_value("font_scale",1.3)
 GameSettings.set_value("camera_speed",1.7)
 GameSettings.set_value("reduced_motion",true)
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 GameSettings.load_settings()
 check(GameSettings.values["font_scale"] == 1.3 and GameSettings.values["camera_speed"] == 1.7 and GameSettings.values["reduced_motion"],"ConfigFile 保存与重新读取")
 var config: ConfigFile = ConfigFile.new()
 config.set_value("meta","version",1)
 config.set_value("settings","font_scale",9.0)
 config.set_value("settings","glow",0.5)
 config.save(GameSettings.storage_path)
 GameSettings.load_settings()
 check(GameSettings.values["font_scale"] == 1.0 and GameSettings.values["glow"] == 0.5,"非法字段只恢复对应默认值，合法字段保留")
 config.set_value("meta","version",99)
 config.save(GameSettings.storage_path)
 GameSettings.load_settings()
 check(GameSettings.values == GameSettings.DEFAULTS and GameSettings.status.contains("原文件已保留"),"损坏配置恢复默认且保留原文件")
 var backup_exists: bool = false
 for name: String in DirAccess.get_files_at("user://"):
  if name.begins_with("launcher-test-settings.cfg.invalid-"): backup_exists = true
 check(backup_exists,"损坏配置确有备份文件")
 GameSettings.storage_path = "user://missing-launcher-directory/settings.cfg"
 check(not GameSettings.set_value("camera_speed",1.2) and GameSettings.values["camera_speed"] == 1.2 and GameSettings.dirty and GameSettings.status.contains("未保存"),"写盘失败保留运行内设置并明确提示")
 GameSettings.storage_path = "user://launcher-test-settings.cfg"
 check(GameSettings.save_settings() and not GameSettings.dirty,"保存失败可以重试恢复")
 GameSettings.values = GameSettings.DEFAULTS.duplicate()
 var menu: MainMenu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
 add_child(menu)
 check(menu.pages.size() == 3 and menu.page == "home","首页包含单人、多人和设置入口")
 check(get_tree().get_nodes_in_group("geo_units").is_empty(),"首页不创建战斗或演武单位")
 menu.show_page("multiplayer")
 var disabled: int = 0
 for node: Node in menu.pages["multiplayer"].find_children("*","Button",true,false):
  if (node as Button).disabled: disabled += 1
 check(disabled == 2,"多人创建与加入菜单明确禁用")
 menu.show_page("single")
 menu.select_map("refraction")
 check(menu.map_preview.map_id == "refraction" and menu.map_title.text == "折光阵列","选择地图同步真实定义与预览")
 check(MatchSession.selected_map_id == "refraction","地图选择保留在运行会话")
 menu.open_settings()
 check(get_tree().paused and menu.settings.opened,"菜单可打开共享设置面板")
 menu.settings.select_category("界面")
 GameSettings.set_value("font_scale",1.3)
 check(menu.map_title.get_theme_font_size("font_size") == 31,"字号变更刷新已存在的页面文字")
 menu.settings.close_panel()
 await frames()
 check(not get_tree().paused,"关闭菜单设置恢复暂停状态")
 menu.queue_free()
 await frames()
 for id: String in MapCatalog.IDS:
  var data: Dictionary = MapCatalog.definition(id)
  var arena: MainArena = (load("res://scenes/main_arena.tscn") as PackedScene).instantiate() as MainArena
  arena.map_id = id
  add_child(arena)
  check(arena.navigation.walls.size() == data["walls"].size() and arena.navigation.crystals.size() == data["crystals"].size(),"地图实体数量与预览定义一致："+id)
  var symmetrical: bool = true
  for crystal: Vector2 in data["crystals"]: symmetrical = symmetrical and (data["crystals"] as Array).has(Vector2(2400,1350)-crystal)
  var vertices: Array[Vector2] = []
  for spec: Dictionary in data["walls"]:
   for vertex: Vector2 in Transform2D(spec["angle"],spec["position"])*(spec["polygon"] as PackedVector2Array): vertices.append(vertex)
  for vertex: Vector2 in vertices:
   var mirrored: bool = false
   for other: Vector2 in vertices:
    if other.distance_to(Vector2(2400,1350)-vertex) < 0.1: mirrored = true
   symmetrical = symmetrical and mirrored
  check(symmetrical,"地图地形180度对称："+id)
  var safe: bool = true
  for wall: TerrainWall in arena.navigation.walls: safe = safe and not arena.spawn_clear(wall.to_global(wall.polygon[0]),18)
  for crystal: NeutralCrystal in arena.navigation.crystals: safe = safe and not arena.spawn_clear(crystal.position,18)
  check(safe,"掩体与晶簇拒绝部署落点："+id)
  check(arena.units_for(0).size() == 9 and arena.units_for(1).size() == 9 and arena.flux[0] == 180 and arena.match_left == 600,"地图沿用统一初始规则："+id)
  await frames()
  arena.start_match()
  arena.ai_enabled = false
  var before_deploy: float = arena.flux[0]
  var deployed: bool = arena.deploy("triangle")
  var recruit: BaseGeoUnit = arena.units_for(0).back()
  check(deployed and arena.units_for(0).size() == 10 and is_equal_approx(arena.flux[0],before_deploy-30) and terrain_clear(arena,recruit),"正式部署扣费且落点无地形碰撞："+id)
  var target: Vector2 = arena.navigation.crystals[0].global_position
  arena.spawn_unit("square",1,target+Vector2(100,0),false)
  var before_swap: float = arena.flux[0]
  var swapped: bool = arena.cast_skill("TOPOLOGY_SWAP",target)
  var safe_transfer: bool = true
  var transferred: int = 0
  for unit: BaseGeoUnit in arena.units_for(0):
   if unit.position.distance_to(target) < 300:
    transferred += 1
    safe_transfer = safe_transfer and terrain_clear(arena,unit)
  check(swapped and transferred > 0 and safe_transfer and is_equal_approx(arena.flux[0],before_swap-45),"真实拓扑转移避开晶簇及掩体并正确扣费："+id)
  arena.hud.call("open_matrix")
  var draft: TextEdit = arena.hud.get("matrix_prompt") as TextEdit
  draft.text = "分推，晶簇折射"
  arena.hud.call("open_settings")
  var settings: SettingsPanel = arena.hud.get("settings") as SettingsPanel
  var remaining: float = arena.match_left
  var money: float = arena.flux[0]
  var positions: Array[Vector2] = []
  for unit: BaseGeoUnit in arena.local_units: positions.append(unit.position)
  await frames(8)
  var frozen: bool = true
  for n: int in range(positions.size()): frozen = frozen and positions[n] == arena.local_units[n].position
  check(get_tree().paused and arena.match_left == remaining and arena.flux[0] == money and frozen,"战中设置暂停单位、计时与经济："+id)
  GameSettings.set_value("font_scale",1.15)
  check(draft.text == "分推，晶簇折射" and bool(arena.hud.get("matrix_open")),"调整字号保留矩阵草稿与开启状态："+id)
  settings.preview_display(1,Vector2i(1440,810))
  settings.revert_display()
  check(GameSettings.values["window_mode"] == 0 and not settings.display_pending,"显示设置取消回退："+id)
  settings.preview_display(1,Vector2i(1440,810))
  settings.display_left = 0.001
  settings._process(0.1)
  check(GameSettings.values["window_mode"] == 0 and not settings.display_pending,"显示设置倒计时回退："+id)
  settings.preview_display(1,Vector2i(1440,810))
  settings.confirm_display()
  settings.display_dialog.hide()
  check(GameSettings.values["window_mode"] == 1 and not settings.display_pending,"显示设置确认并保存："+id)
  settings.restore_defaults()
  if settings.display_pending: settings.confirm_display()
  settings.display_dialog.hide()
  check(GameSettings.values == GameSettings.DEFAULTS and arena.phase == MainArena.Phase.PLAYING,"恢复默认不重置当前战局："+id)
  settings.close_panel()
  await frames()
  check(not get_tree().paused and draft.text == "分推，晶簇折射","关闭设置恢复战斗并保留草稿："+id)
  get_tree().paused = true
  arena.hud.call("open_settings")
  settings = arena.hud.get("settings") as SettingsPanel
  settings.close_panel()
  check(get_tree().paused,"设置关闭保留此前已有的暂停："+id)
  get_tree().paused = false
  arena.queue_free()
  await frames()
 MatchSession.pending_map_id = ""
 var direct: MainArena = (load("res://scenes/main_arena.tscn") as PackedScene).instantiate() as MainArena
 add_child(direct)
 check(direct.map_id == "balanced","直接启动战场不受菜单选图污染")
 direct.queue_free()
 await frames()
 MatchSession.request_match("flanks")
 check(MatchSession.consume_map() == "flanks" and MatchSession.consume_map() == "balanced","开局地图请求只消费一次")
 GameSettings.set_value("font_scale",1.3)
 GameSettings.set_value("camera_speed",1.7)
 GameSettings.set_value("reduced_motion",true)

func terrain_clear(arena: MainArena, unit: BaseGeoUnit) -> bool:
 var shape: CircleShape2D = CircleShape2D.new()
 shape.radius = unit.unit_radius+2
 var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
 query.shape = shape
 query.transform = Transform2D(0,unit.global_position)
 query.collision_mask = 4 | 16
 return arena.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
