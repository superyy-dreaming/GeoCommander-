extends Node

var arena: MainArena
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS: "+label)
 else:
  failures += 1
  push_error("FAIL: "+label)

func _ready() -> void:
 await get_tree().process_frame
 await run_tests()
 print("HYBRID_COMMAND_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures == 0 else 1)

func fresh_arena() -> void:
 var scene: PackedScene = load("res://scenes/main_arena.tscn")
 arena = scene.instantiate() as MainArena
 arena.terrain_enabled = false
 arena.ai_enabled = false
 get_tree().root.add_child(arena)
 get_tree().current_scene = arena
 await get_tree().physics_frame
 for unit: BaseGeoUnit in arena.local_units: unit.set_physics_process(false)

func test_copilot_validator() -> void:
 var first_patch: Dictionary = {"stance":"aggressive","unit_rules":{"triangle":{"movement":"flank_sides"}}}
 var second_patch: Dictionary = {"stance":"defensive","unit_rules":{"square":{"movement":"protect_hexagon"}}}
 var valid_response: Dictionary = {"proposals":[
  {"slot":0,"recommend_score":90,"title":"侧翼推进","reason":"利用侧翼接近可见目标。","profile_patch":first_patch},
  {"slot":1,"recommend_score":70,"title":"核心防守","reason":"保护后排并保持阵线。","profile_patch":second_patch}
 ]}
 var parsed: Dictionary = AICopilotAnalyst.parse_response(JSON.stringify(valid_response),"balanced")
 check(bool(parsed.get("ok",false)) and parsed["proposals"][0]["profile_patch"]["unit_rules"].has("hexagon"),"参谋接受部分补丁并合并到完整默认配置")
 var wrong_score: Dictionary = valid_response.duplicate(true)
 wrong_score["proposals"][1]["recommend_score"] = 91
 check(not bool(AICopilotAnalyst.parse_response(JSON.stringify(wrong_score),"balanced").get("ok",false)),"参谋推荐度必须严格递减")
 var fractional: Dictionary = valid_response.duplicate(true)
 fractional["proposals"][0]["recommend_score"] = 90.5
 check(not bool(AICopilotAnalyst.parse_response(JSON.stringify(fractional),"balanced").get("ok",false)),"参谋分数拒绝小数")
 var duplicate_slot: Dictionary = valid_response.duplicate(true)
 duplicate_slot["proposals"][1]["slot"] = 0
 check(not bool(AICopilotAnalyst.parse_response(JSON.stringify(duplicate_slot),"balanced").get("ok",false)),"参谋槽位必须唯一")
 var unsupported: Dictionary = {"proposals":[{"slot":0,"recommend_score":90,"title":"无效","reason":"未知字段","profile_patch":{"unit_rules":{"triangle":{"teleport":"free"}}}}]}
 check(not bool(AICopilotAnalyst.parse_response(JSON.stringify(unsupported),"balanced").get("ok",false)),"参谋拒绝越权字段")
 var invalid_enum: Dictionary = {"proposals":[{"slot":0,"recommend_score":90,"title":"无效","reason":"未知移动","profile_patch":{"unit_rules":{"triangle":{"movement":"teleport"}}}}]}
 check(not bool(AICopilotAnalyst.parse_response(JSON.stringify(invalid_enum),"balanced").get("ok",false)),"参谋拒绝非法枚举")
 var duplicate_program: Dictionary = {"proposals":[
  {"slot":0,"recommend_score":90,"title":"a","reason":"one","profile_patch":first_patch},
  {"slot":1,"recommend_score":80,"title":"b","reason":"two","profile_patch":first_patch}
 ]}
 check(not bool(AICopilotAnalyst.parse_response(JSON.stringify(duplicate_program),"balanced").get("ok",false)),"参谋拒绝重复建议")
 var bound: Dictionary = TacticPlan.default_program("triangle")
 bound["plan"]["map_id"] = "flanks"
 var wrong_map: Dictionary = {"proposals":[{"slot":0,"recommend_score":90,"title":"地图绑定","reason":"不匹配","profile_patch":{"unit_rules":{"triangle":{"program":bound}}}}]}
 check(not bool(AICopilotAnalyst.parse_response(JSON.stringify(wrong_map),"balanced").get("ok",false)),"参谋精细方案遵守当前地图绑定")
 var malformed: Dictionary = AICopilotAnalyst.parse_response("{broken","balanced")
 check(not bool(malformed.get("ok",false)),"参谋非法 JSON 被拒绝")
 var payload: Dictionary = LLMService.request_payload("copilot",JSON.stringify({"snapshot":{"blue":{},"red_visible":{}}}),"triangle","balanced","只优先建议防守并保护基地")
 var payload_messages: Array = payload["messages"]
 check(str(payload_messages[0]["content"]).contains("只优先建议防守并保护基地") and not str(payload_messages[1]["content"]).contains("directive"),"参谋指令进入系统约束，遥测快照不携带提示词")

func test_keybinds() -> void:
 var original_bindings: Dictionary = KeybindManager.bindings.duplicate(true)
 var original_path: String = KeybindManager.config_path
 var original_error: String = KeybindManager.persistence_error
 var temporary_path: String = "user://hybrid-keybind-test-%d.json" % get_instance_id()
 KeybindManager.config_path = temporary_path
 KeybindManager.bindings = KeybindManager.DEFAULT_BINDINGS.duplicate(true)
 var swap: Dictionary = KeybindManager.rebind_action("skill_triangle",KEY_W)
 check(bool(swap.get("ok",false)) and str(swap.get("swapped","")) == "skill_square" and KeybindManager.key_for("skill_square") == KEY_Q,"重绑定时交换冲突按键")
 check(KeybindManager.get_key_label("skill_triangle") == "W" and KeybindManager.get_key_label("skill_square") == "Q","按键标签即时反映交换")
 KeybindManager.config_path = "user://missing-keybind-directory-%d/keybinds.json" % get_instance_id()
 var failed_save: Dictionary = KeybindManager.rebind_action("skill_triangle",KEY_F6)
 check(bool(failed_save.get("ok",false)) and not bool(failed_save.get("saved",true)) and not KeybindManager.persistence_error.is_empty(),"保存失败保留本次按键并报告错误")
 KeybindManager.bindings = original_bindings
 KeybindManager.config_path = original_path
 KeybindManager.persistence_error = original_error
 SignalBus.keybinds_updated.emit(original_bindings)
 var absolute_path: String = ProjectSettings.globalize_path(temporary_path)
 if FileAccess.file_exists(absolute_path): DirAccess.remove_absolute(absolute_path)

func test_manual_unit_tick() -> void:
 var blue_units: Array[BaseGeoUnit] = arena.units_for(0)
 var red_units: Array[BaseGeoUnit] = arena.units_for(1)
 var enemy_base: CoreMatrixBase = arena.bases[1]
 var enemy_base_position: Vector2 = enemy_base.global_position
 for kind_index: int in range(UnitCatalog.TYPES.size()):
  var kind: String = UnitCatalog.TYPES[kind_index]
  var actor: BaseGeoUnit = null
  for candidate: BaseGeoUnit in blue_units:
   if candidate.unit_type == kind:
    actor = candidate
    break
  var focused_target: BaseGeoUnit = red_units[kind_index]
  var passive_target: Node2D = enemy_base
  actor.global_position = Vector2(480.0 + kind_index * 150.0, 600.0)
  focused_target.global_position = actor.global_position + Vector2(20.0, 0.0)
  enemy_base.global_position = actor.global_position + Vector2(320.0, 0.0)
  actor.set_manual_attack(focused_target,6.0)
  actor.current_target = passive_target
  actor.attack_left = 0.0
  actor.tick_unit(0.016)
  check(actor.current_target == focused_target,"手动集火锁定指定目标："+kind)
  check(not actor.should_run_ai_decision(),"手动控制期间停止战术重选："+kind)
  actor.set_manual_move(actor.global_position+Vector2(120.0,0.0),4.0)
  actor.current_target = passive_target
  enemy_base.global_position = actor.global_position + Vector2(20.0,0.0)
  actor.attack_left = 0.0
  actor.skill_left = 0.0
  actor.scan_left = 0.0
  var attacks_before: int = actor.attack_serial
  var skills_before: int = actor.skill_serial
  var scans_before: int = actor.scan_serial
  actor.tick_unit(0.016)
  check(actor.attack_serial == attacks_before and actor.skill_serial == skills_before and actor.scan_serial == scans_before,"手动移动期间不自动攻击、施法或扫描："+kind)
  enemy_base.global_position = enemy_base_position
  actor.release_manual_control()
  check(actor.authority_state != BaseGeoUnit.ControlAuthority.MANUAL_OVERRIDE,"手动窗口可归还原控制层："+kind)

func test_modal_key_capture(modal: Node) -> void:
 var original_bindings: Dictionary = KeybindManager.bindings.duplicate(true)
 var original_path: String = KeybindManager.config_path
 var temporary_path: String = "user://hybrid-modal-key-test-%d.json" % get_instance_id()
 KeybindManager.config_path = temporary_path
 var buttons: Dictionary = modal.get("key_buttons")
 modal.call("begin_capture","skill_triangle",buttons["skill_triangle"])
 var tab_event: InputEventKey = InputEventKey.new()
 tab_event.keycode = KEY_TAB
 tab_event.physical_keycode = KEY_TAB
 tab_event.pressed = true
 modal.call("_input",tab_event)
 check(KeybindManager.key_for("skill_triangle") == KEY_TAB and KeybindManager.key_for("toggle_tactical_drawer") == KEY_Q,"Tab 可被捕获并与已有按键交换")
 KeybindManager.bindings = original_bindings
 KeybindManager.config_path = original_path
 SignalBus.keybinds_updated.emit(original_bindings)
 var absolute_path: String = ProjectSettings.globalize_path(temporary_path)
 if FileAccess.file_exists(absolute_path): DirAccess.remove_absolute(absolute_path)

func run_tests() -> void:
 check(KeybindManager.get_key_label("skill_triangle") == "Q", "默认兵种技能按键")
 check(KeybindManager.get_key_label("copilot_opt_1") == "I", "默认参谋按键")
 await test_keybinds()
 test_copilot_validator()
 await fresh_arena()
 var modal: Node = load("res://scripts/ui/keybind_settings_modal.gd").new()
 arena.add_child(modal)
 modal.call("open_modal")
 await get_tree().process_frame
 var blocked_key: InputEventKey = InputEventKey.new()
 blocked_key.keycode = KEY_I
 blocked_key.physical_keycode = KEY_I
 blocked_key.pressed = true
 check(not KeybindManager.gameplay_input_allowed() and not KeybindManager.action_matches(blocked_key,"copilot_opt_1"),"按键设置模态层阻断参谋快捷键")
 test_modal_key_capture(modal)
 modal.call("close_modal")
 await get_tree().process_frame
 arena.start_match()
 test_manual_unit_tick()
 var units: Array[BaseGeoUnit] = arena.units_for(0)
 var first: BaseGeoUnit = units[0]
 var second: BaseGeoUnit = units[1]
 arena.set_selection([first,second])
 var local_result: Dictionary = arena.submit_tactic("侧翼切后排")
 check(bool(local_result.get("ok",false)) and first.authority_state == BaseGeoUnit.ControlAuthority.SQUAD_AI_SCOPED and second.authority_state == BaseGeoUnit.ControlAuthority.SQUAD_AI_SCOPED, "局部小队指令只接管所选单位")
 check(is_equal_approx(arena.local_override_left,3.0), "局部小队指令使用独立三秒冷却")
 arena.clear_selection()
 check(bool(arena.submit_tactic("保护六边形").get("ok",false)) and first.authority_state == BaseGeoUnit.ControlAuthority.SQUAD_AI_SCOPED, "局部冷却不影响全局提交且局部单位保留规则")
 first.set_manual_move(first.global_position+Vector2(120,0),4.0)
 check(first.authority_state == BaseGeoUnit.ControlAuthority.MANUAL_OVERRIDE, "右键移动进入手动控制权")
 first.return_to_ai()
 check(first.authority_state == BaseGeoUnit.ControlAuthority.SQUAD_AI_SCOPED, "归还 AI 恢复原有小队规则层")
 var copilot: Node = arena.copilot
 copilot.call("request_snapshot")
 await get_tree().process_frame
 var proposals: Array = copilot.get("current_proposals")
 check(proposals.size() == 3 and int(proposals[0]["recommend_score"]) > int(proposals[1]["recommend_score"]), "参谋生成三条递减本地建议")
 var auto_unit: BaseGeoUnit = units[2]
 var original_program: Dictionary = TacticPlan.default_program(auto_unit.unit_type)
 var saved_execution: TacticExecution = TacticExecution.new()
 saved_execution.install(original_program)
 saved_execution.state = {"time":0.75,"path_index":2,"initialized":true}
 saved_execution.cover_point = Vector2(350,240)
 auto_unit.execution = saved_execution
 auto_unit.base_rule["program"] = original_program
 auto_unit.rule = original_program["base"].duplicate(true)
 var temporary_rule: Dictionary = {"movement":"flank_sides","priority":"ranged_or_commander","skill_cond":"backstab_or_grav","retreat_hp":0.2}
 auto_unit.apply_copilot_rule(temporary_rule)
 check(auto_unit.copilot_active and auto_unit.execution == null,"参谋规则接管时暂停原编排实例")
 auto_unit.restore_copilot_rule()
 check(auto_unit.execution == saved_execution and is_equal_approx(float(auto_unit.execution.state["time"]),0.75) and auto_unit.execution.cover_point == Vector2(350,240),"恢复参谋接管前的步骤进度与掩体状态")
 auto_unit.apply_copilot_rule(temporary_rule)
 auto_unit.set_manual_move(auto_unit.global_position+Vector2(120,0),4.0)
 check(not auto_unit.copilot_active and auto_unit.authority_state == BaseGeoUnit.ControlAuthority.MANUAL_OVERRIDE and auto_unit.execution == saved_execution,"手动接管先恢复参谋临时层并保留原步骤实例")
 auto_unit.release_manual_control()
 check(auto_unit.authority_state == BaseGeoUnit.ControlAuthority.AUTO_AGENT and auto_unit.execution == saved_execution and is_equal_approx(float(auto_unit.execution.state["time"]),0.75),"手动窗口结束恢复原执行器进度")
 var blocked_unit: BaseGeoUnit = units[3]
 blocked_unit.set_manual_move(blocked_unit.global_position+Vector2(500,0),4.0)
 arena.call("_update_manual_authority",0.5)
 arena.call("_update_manual_authority",0.5)
 arena.call("_update_manual_authority",0.5)
 check(blocked_unit.authority_state != BaseGeoUnit.ControlAuthority.MANUAL_OVERRIDE and str(blocked_unit.action_blocked).contains("持续受阻"),"持续无位移的手动指令显示原因并归还AI")
 blocked_unit.set_manual_move(blocked_unit.global_position+Vector2(500,0),4.0)
 blocked_unit.stun_left = 2.0
 for _index: int in range(4): arena.call("_update_manual_authority",0.5)
 check(blocked_unit.authority_state == BaseGeoUnit.ControlAuthority.MANUAL_OVERRIDE and is_zero_approx(blocked_unit.manual_blocked_time),"受控期间冻结持续受阻判定")
 blocked_unit.stun_left = 0.0
 blocked_unit.release_manual_control()
 arena.set_selection([first,second])
 var good_path: Array[Vector2] = [Vector2(1150,580),Vector2(1280,620)]
 var bad_path: Array[Vector2] = [Vector2(1150,580),Vector2(-100,620)]
 check(arena.tactical_path_error(good_path).is_empty() and not arena.tactical_path_error(bad_path).is_empty(),"小队航线只接受地图内安全航点")
 first.set_tactical_path(good_path)
 check(first.authority_state == BaseGeoUnit.ControlAuthority.SQUAD_AI_SCOPED and first.tactical_waypoints.size() == 2,"Shift路径将单位交给局部小队控制")
 arena.call("issue_right_click_order",Vector2(1200,620))
 check(first.authority_state == BaseGeoUnit.ControlAuthority.MANUAL_OVERRIDE and second.authority_state == BaseGeoUnit.ControlAuthority.MANUAL_OVERRIDE and first.manual_move_target.distance_to(second.manual_move_target) >= first.unit_radius+second.unit_radius+8.0,"混编编队移动使用不重叠落点")
 var previous_manual_target: Vector2 = first.manual_move_target
 arena.call("issue_right_click_order",Vector2(-10000,-10000))
 check(first.manual_move_target == previous_manual_target,"无安全编队落点时拒绝且不部分覆盖原命令")
 arena.clear_selection()
 var accepted: bool = copilot.call("accept_proposal",0)
 check(accepted and arena.units_for(0).any(func(unit: BaseGeoUnit) -> bool: return unit.copilot_active), "参谋临时接管自动单位")
 var previous_advice: String = str(auto_unit.base_rule.get("movement",""))
 var replacement_profile: Dictionary = TacticalBrain.get_default_profile()
 replacement_profile["unit_rules"]["square"]["movement"] = "protect_hexagon"
 check(arena.apply_copilot_proposal(replacement_profile) and auto_unit.copilot_active and str(auto_unit.base_rule.get("movement","")) != previous_advice,"新参谋方案替换旧临时层并重新保存原执行器")
 copilot.call("restore_original")
 check(not arena.units_for(0).any(func(unit: BaseGeoUnit) -> bool: return unit.copilot_active), "参谋恢复原方案")
 var old_serial: int = int(copilot.get("snapshot_serial"))
 copilot.set("request_pending",true)
 var stale_proposals: Array[Dictionary] = [{"slot":0,"recommend_score":90,"title":"旧方案","reason":"过期","profile_patch":{}}]
 copilot.set("current_proposals",stale_proposals)
 copilot.call("on_directive_updated")
 check(not bool(copilot.get("request_pending")) and (copilot.get("current_proposals") as Array).is_empty() and int(copilot.get("snapshot_serial")) > old_serial,"参谋提示词变更取消旧请求并使建议失效")
 arena.queue_free()
 await get_tree().process_frame
