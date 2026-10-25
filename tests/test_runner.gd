extends Node

var arena: MainArena
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
 checks += 1
 if condition:
  print("PASS: " + description)
 else:
  failures += 1
  push_error("FAIL: " + description)

func _ready() -> void:
 await get_tree().process_frame
 await run_tests()
 print("TEST_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures == 0 else 1)

func fresh_arena() -> void:
 if is_instance_valid(arena):
  arena.queue_free()
  await get_tree().process_frame
 var scene: PackedScene = load("res://scenes/main_arena.tscn") as PackedScene
 arena = scene.instantiate() as MainArena
 arena.terrain_enabled = false
 get_tree().root.add_child(arena)
 get_tree().current_scene = arena
 arena.ai_enabled = false
 arena.set_physics_process(false)
 freeze_units()
 await get_tree().physics_frame

func freeze_units() -> void:
 for node: Node in get_tree().get_nodes_in_group("units"):
  node.set_physics_process(false)

func clear_units() -> void:
 for node: Node in get_tree().get_nodes_in_group("units"):
  (node as BaseGeoUnit).die()
 await get_tree().process_frame

func spawn(kind: String, team: int, pos: Vector2) -> BaseGeoUnit:
 var unit: BaseGeoUnit = arena.spawn_unit(kind,team,pos,false)
 unit.set_physics_process(false)
 return unit

func send_key(code: int, unicode_value: int = 0, backwards: bool = false) -> void:
 var event: InputEventKey = InputEventKey.new()
 event.physical_keycode = code
 event.keycode = code
 event.unicode = unicode_value
 event.shift_pressed = backwards
 event.pressed = true
 get_viewport().push_input(event)
 var release: InputEventKey = event.duplicate() as InputEventKey
 release.pressed = false
 get_viewport().push_input(release)

func run_tests() -> void:
 var parsed: Dictionary = TacticalBrain.parse_prompt("全军突击，然后保护六边形")
 check(bool(parsed["ok"]) and parsed["profile"]["stance"] == "defensive", "文本顺序决定冲突规则")
 parsed = TacticalBrain.parse_prompt("保护六边形，然后冲锋")
 check(parsed["profile"]["stance"] == "aggressive" and parsed["profile"]["unit_rules"]["triangle"]["movement"] == "direct_charge", "反向顺序产生不同结果")
 var prompts: Array[String] = ["FLANK assassin", "snipe", "defend guard", "refract bounce", "all in rush", "kite retreat", "绕后侧翼", "切后排切菱形刺杀指挥", "保护死守保六边形", "折射反射棱镜配合", "全军突击冲锋", "拉扯风筝后撤"]
 for prompt: String in prompts:
  check(bool(TacticalBrain.parse_prompt(prompt)["ok"]), "识别中英文关键词：" + prompt)
 var kite: Dictionary = TacticalBrain.parse_prompt("kite retreat 风筝")["profile"]
 check(is_equal_approx(float(kite["unit_rules"]["triangle"]["retreat_hp"]),0.4), "同义词重复不累积撤退阈值")
 check(not bool(TacticalBrain.parse_prompt("hello world")["ok"]), "无法识别的指令明确失败")
 check(JSON.parse_string(TacticalBrain.json_preview(kite)) is Dictionary, "包含坐标的战术可序列化为 JSON")
 await fresh_arena()
 check(arena.phase == MainArena.Phase.PREPARING and arena.units_for(0).size() == 9 and arena.units_for(1).size() == 9, "初始双方各九单位，处于准备阶段")
 check(arena.flux == [180.0,180.0] and arena.hex_counts == [1,1], "免费初始阵容及双方资源正确")
 arena.start_match()
 var before: float = arena.flux[0]
 check(arena.deploy("triangle") and is_equal_approx(arena.flux[0],before-30.0) and arena.units_for(0).size() == 10, "部署原子扣费并增加人口")
 freeze_units()
 var prompt: LineEdit = arena.hud.get("prompt_input") as LineEdit
 prompt.grab_focus()
 await get_tree().process_frame
 var population_before: int = arena.units_for(0).size()
 send_key(KEY_1,49)
 await get_tree().process_frame
 check(arena.units_for(0).size() == population_before and prompt.text == "1", "输入框聚焦时数字仅编辑文本，不部署单位")
 prompt.text = "三角形绕后切菱形"
 send_key(KEY_ENTER,13)
 await get_tree().process_frame
 check(TacticalBrain.last_prompts[0] == "三角形绕后切菱形" and arena.override_left == 30.0, "中文战术通过原生输入框 Enter 提交")
 prompt.release_focus()
 send_key(KEY_TAB)
 await get_tree().process_frame
 var matrix_text: TextEdit = arena.hud.get("matrix_prompt") as TextEdit
 check(bool(arena.hud.get("matrix_open")) and get_viewport().gui_get_focus_owner() == matrix_text, "Tab 打开矩阵并聚焦战术编辑器")
 check(matrix_text.text == TacticalBrain.last_prompts[0], "矩阵打开时同步已生效战术")
 send_key(KEY_TAB)
 await get_tree().process_frame
 check(bool(arena.hud.get("matrix_open")) and get_viewport().gui_get_focus_owner() != matrix_text, "矩阵内 Tab 导航控件，不关闭矩阵")
 send_key(KEY_TAB,0,true)
 await get_tree().process_frame
 check(get_viewport().gui_get_focus_owner() == matrix_text, "Shift+Tab 返回上一矩阵控件")
 var modal: Control = arena.hud.get("matrix_backdrop") as Control
 var focus_stayed_inside: bool = true
 for index: int in range(24):
  send_key(KEY_TAB)
  await get_tree().process_frame
  focus_stayed_inside = focus_stayed_inside and modal.is_ancestor_of(get_viewport().gui_get_focus_owner())
 check(focus_stayed_inside, "完整 Tab 循环的焦点始终位于矩阵内部")
 population_before = arena.units_for(0).size()
 send_key(KEY_1,49)
 await get_tree().process_frame
 check(arena.units_for(0).size() == population_before, "矩阵打开时阻止背后的部署快捷键")
 arena.hud.call("close_matrix")
 prompt.grab_focus()
 arena.hud.call("open_matrix")
 send_key(KEY_ESCAPE)
 await get_tree().process_frame
 check(not bool(arena.hud.get("matrix_open")) and get_viewport().gui_get_focus_owner() == prompt, "Esc 关闭矩阵并恢复进入前的焦点")
 prompt.release_focus()
 arena.override_left = 0.0
 arena.flux[0] = 10.0
 check(not arena.deploy("square") and is_equal_approx(arena.flux[0],10.0), "资源不足不扣费、不生成单位")
 arena.flux[0] = 100000.0
 check(arena.deploy("hexagon") and arena.hex_counts[0] == 2, "可部署第二个指挥官")
 check(not arena.deploy("hexagon") and arena.hex_counts[0] == 2, "指挥官上限不能绕过")
 check(is_equal_approx(arena.commander_recharge(),1.8), "双指挥官冷却倍率为 1.8")
 while arena.units_for(0).size() < 30:
  arena.deploy("triangle")
 freeze_units()
 before = arena.flux[0]
 check(not arena.deploy("triangle") and is_equal_approx(arena.flux[0],before), "人口上限不扣费")
 var victim: BaseGeoUnit = arena.units_for(0)[0]
 victim.die()
 check(arena.units_for(0).size() == 29, "死亡立即释放人口")
 check(arena.deploy("square"), "死亡后可立即补充部署")
 freeze_units()
 arena.override_left = 30.0
 arena.skill_cooldowns["EMP_STRIKE"] = 22.0
 var recharge: float = arena.commander_recharge()
 arena._physics_process(1.0)
 check(is_equal_approx(arena.override_left,30.0-recharge) and is_equal_approx(float(arena.skill_cooldowns["EMP_STRIKE"]),22.0-recharge), "终端与全局技能共享链路加速语义")
 arena.override_left = 0.0
 var red_before: Dictionary = TacticalBrain.team_profiles[1].duplicate(true)
 check(bool(arena.submit_tactic("全军突击")["ok"]), "战中可提交战术")
 check(not bool(arena.submit_tactic("保护六边形")["ok"]), "冷却不能被重复提交绕过")
 arena.override_left = 0.0
 check(bool(arena.submit_tactic("保护六边形")["ok"]) and is_equal_approx(float(TacticalBrain.team_profiles[0]["unit_rules"]["diamond"]["retreat_hp"]),0.45), "新指令从默认规则重编译")
 check(TacticalBrain.team_profiles[1] == red_before, "蓝方战术不修改红方配置")
 arena.override_left = 0.0
 var profile_before: Dictionary = TacticalBrain.team_profiles[0].duplicate(true)
 check(not bool(arena.submit_tactic("unrecognized")["ok"]) and arena.override_left == 0.0 and TacticalBrain.team_profiles[0] == profile_before, "无效指令不消耗冷却也不覆盖配置")
 for unit: BaseGeoUnit in arena.units_for(0):
  if unit.unit_type == "hexagon": unit.die()
 check(arena.communication_jammed and not bool(arena.submit_tactic("rush")["ok"]), "指挥官全灭锁定战术终端")
 arena.skill_cooldowns["EMP_STRIKE"] = 0.0
 check(arena.skill_reason("EMP_STRIKE").is_empty(), "链路中断不锁定全局技能")
 arena.deploy("hexagon")
 freeze_units()
 check(not arena.communication_jammed, "重新部署指挥官恢复链路")
 var prism: EnergyPrism = arena.prisms[0]
 prism.update_capture(2.0,2,0)
 prism.update_capture(4.0,1,1)
 check(prism.capture_owner == -1 and is_equal_approx(prism.progress,2.0), "占点人数持平暂停进度")
 prism.update_capture(3.0,2,0)
 check(prism.capture_owner == 0 and arena.income(0) == 18.0, "五秒占点增加每秒六点收入")
 prism.update_capture(2.0,0,2)
 check(prism.capture_owner == 0, "夺取未完成时原归属保持")
 prism.update_capture(3.0,0,2)
 check(prism.capture_owner == 1 and arena.income(0) == 12.0 and arena.income(1) == 18.0, "夺取完成切换经济收益")
 arena.skill_cooldowns["EMP_STRIKE"] = 0.0
 before = arena.flux[0]
 check(not arena.cast_skill("EMP_STRIKE",Vector2(-200,-200)) and arena.flux[0] == before and float(arena.skill_cooldowns["EMP_STRIKE"]) == 0.0, "边界外施法不扣费、不进入冷却")
 check(not arena.cast_skill("TOPOLOGY_SWAP",Vector2(2100,100)) and arena.flux[0] == before, "无单位可转移时不扣费")
 await fresh_arena()
 arena.start_match()
 await clear_units()
 var mover: BaseGeoUnit = spawn("triangle",0,Vector2(50,400))
 var barrier: PrismBarrier = PrismBarrier.new()
 barrier.arena = arena
 barrier.team = 1
 barrier.position = Vector2(100,400)
 arena.add_child(barrier)
 await get_tree().physics_frame
 for frame: int in range(20):
  mover.velocity = Vector2(300,0)
  mover.move_and_slide()
  await get_tree().physics_frame
 check(mover.position.x < 82.0, "敌方护盾真实阻挡移动")
 mover.position = Vector2(50,900)
 var friend: BaseGeoUnit = spawn("triangle",1,Vector2(50,400))
 await get_tree().physics_frame
 for frame: int in range(25):
  friend.velocity = Vector2(300,0)
  friend.move_and_slide()
  await get_tree().physics_frame
 check(friend.position.x > 125.0, "护盾对后生成的友军放行")
 barrier.queue_free()
 await clear_units()
 var triangle: BaseGeoUnit = spawn("triangle",0,Vector2(100,300))
 var target: BaseGeoUnit = spawn("square",1,Vector2(200,300))
 triangle.set("dash_dir",Vector2.RIGHT)
 target.visual_root.rotation = 0.0
 triangle.call("hit_dash_segment",Vector2(100,300),Vector2(300,300))
 triangle.call("hit_dash_segment",Vector2(100,300),Vector2(300,300))
 check(is_equal_approx(target.current_hp,350.0), "背刺双倍伤害且同次冲刺只命中一次")
 (triangle.get("dash_victims") as Dictionary).clear()
 target.visual_root.rotation = PI
 triangle.call("hit_dash_segment",Vector2(100,300),Vector2(300,300))
 check(is_equal_approx(target.current_hp,295.0), "正面冲刺伤害为 55")
 triangle.set("dash_state",2)
 triangle.collision_mask = 4 | 16
 var diamond: BaseGeoUnit = spawn("diamond",1,Vector2(210,310))
 diamond.set("windup_left",0.5)
 arena.flux[0] = 180.0
 check(arena.cast_skill("EMP_STRIKE",Vector2(200,300)), "EMP 可施放")
 check(int(triangle.get("dash_state")) == 2, "EMP 不影响友军冲刺")
 check(float(diamond.get("windup_left")) == 0.0 and diamond.stun_left > 2.7, "EMP 中断敌方激光蓄力并施加控制")
 var red_triangle: BaseGeoUnit = spawn("triangle",1,Vector2(230,310))
 red_triangle.set("dash_state",2)
 red_triangle.collision_mask = 4 | 16
 arena.skill_cooldowns["EMP_STRIKE"] = 0.0
 arena.cast_skill("EMP_STRIKE",Vector2(200,300))
 check(int(red_triangle.get("dash_state")) == 0 and red_triangle.collision_mask == 23, "EMP 中断冲刺并恢复碰撞掩码")
 await clear_units()
 diamond = spawn("diamond",0,Vector2(350,700))
 target = spawn("square",1,Vector2(420,700))
 var reflected_target: BaseGeoUnit = spawn("square",1,Vector2(300,700))
 for x: float in [500.0,200.0]:
  var mirror: PrismBarrier = PrismBarrier.new()
  mirror.arena = arena
  mirror.team = 0
  mirror.position = Vector2(x,700)
  mirror.life = 10.0
  arena.add_child(mirror)
 await get_tree().physics_frame
 diamond.call("fire_beam",Vector2.RIGHT)
 var beam: PackedVector2Array = diamond.get("last_beam_points")
 var length: float = 0.0
 for index: int in range(beam.size()-1): length += beam[index].distance_to(beam[index+1])
 check(int(diamond.get("last_beam_bounces")) == 2 and beam.size() == 4 and length <= 750.1, "激光恰好两次反射且总长不超过 750px")
 check(is_equal_approx(target.current_hp,460.0-85.0*1.35*1.35), "多段激光对重复路径目标只结算一次")
 check(is_equal_approx(reflected_target.current_hp,460.0-85.0*1.35*1.35), "重叠反射段取最高倍率 1.35²")
 for node: Node in get_tree().get_nodes_in_group("barriers"): node.queue_free()
 await clear_units()
 var shooter: BaseGeoUnit = spawn("circle",0,Vector2(200,850))
 var ranged_target: BaseGeoUnit = spawn("square",1,Vector2(400,850))
 var friendly_shield: PrismBarrier = PrismBarrier.new()
 friendly_shield.arena = arena
 friendly_shield.team = 0
 friendly_shield.position = Vector2(260,850)
 arena.add_child(friendly_shield)
 var enemy_shield: PrismBarrier = PrismBarrier.new()
 enemy_shield.arena = arena
 enemy_shield.team = 1
 enemy_shield.position = Vector2(330,850)
 arena.add_child(enemy_shield)
 shooter.current_target = ranged_target
 await get_tree().physics_frame
 shooter.basic_attack()
 for frame: int in range(25): await get_tree().physics_frame
 check(enemy_shield.hp == 262.0 and friendly_shield.hp == 280.0 and ranged_target.current_hp == 460.0, "飞行弹体穿过友盾并被敌盾吸收")
 enemy_shield.queue_free()
 await get_tree().physics_frame
 shooter.attack_left = 0.0
 shooter.basic_attack()
 for frame: int in range(25): await get_tree().physics_frame
 check(ranged_target.current_hp == 442.0, "普通远程弹体实际飞行并命中造成伤害")
 friendly_shield.queue_free()
 await clear_units()
 var circle: BaseGeoUnit = spawn("circle",0,Vector2(800,500))
 triangle = spawn("triangle",0,Vector2(760,530))
 for point: Vector2 in [Vector2(1000,500),Vector2(1010,510),Vector2(1020,490)]:
  spawn("square",1,point)
 circle.skill_left = 0.0
 circle.evaluate_best_target()
 circle.tick_unit(0.01)
 check(get_tree().get_nodes_in_group("gravity_wells").size() == 1 and float(triangle.get("gravity_hint_left")) > 1.0, "圆形聚集目标并通知三角协同")
 for node: Node in get_tree().get_nodes_in_group("gravity_wells"): node.queue_free()
 await clear_units()
 mover = spawn("square",1,Vector2(40,400))
 mover.stun_left = 10.0
 mover.set_physics_process(true)
 var well: GravityWell = GravityWell.new()
 well.arena = arena
 well.team = 0
 well.position = Vector2(-50,400)
 arena.add_child(well)
 var minimum_x: float = mover.position.x
 for frame: int in range(80):
  await get_tree().physics_frame
  minimum_x = minf(minimum_x,mover.position.x)
 check(minimum_x >= mover.unit_radius - 1.0 and mover.current_hp < mover.max_hp, "引力通过物理移动，不穿边界且最终造成伤害")
 await clear_units()
 var commander: BaseGeoUnit = spawn("hexagon",0,Vector2(600,600))
 mover = spawn("square",0,Vector2(650,600))
 mover.take_damage(100.0)
 commander.skill_left = 0.0
 commander.tick_unit(0.01)
 check(mover.current_hp == 395.0 and mover.buff_left == 3.0, "指挥官恢复 35HP 并施加三秒增益")
 var zone: OverclockZone = OverclockZone.new()
 zone.arena = arena
 zone.position = mover.position
 arena.add_child(zone)
 zone._physics_process(0.016)
 check(mover.overclock_left > 0.0, "超频区为范围内友军提供增益")
 var reserve: BaseGeoUnit = spawn("triangle",0,Vector2(360,680))
 spawn("square",1,Vector2(1500,700))
 arena.flux[0] = 180.0
 check(arena.cast_skill("TOPOLOGY_SWAP",Vector2(1500,700)) and reserve.global_position.distance_to(Vector2(1500,700)) < 260.0 and arena.flux[0] == 135.0, "进攻转移将基地后备前线送至敌军附近并扣费")
 for enemy: BaseGeoUnit in arena.units_for(1): enemy.die()
 arena.skill_cooldowns["TOPOLOGY_SWAP"] = 0.0
 check(arena.cast_skill("TOPOLOGY_SWAP",reserve.global_position) and reserve.global_position.distance_to(commander.global_position) < 300.0, "防守转移返回最近指挥官附近")
 arena.bases[0].current_hp = 1900.0
 arena.bases[1].current_hp = 1800.0
 arena.resolve_timeout()
 check(arena.phase == MainArena.Phase.ENDED and arena.winner_team == 0, "超时按基地生命比例判胜")
 var restart_button: Button = arena.hud.get("restart_button") as Button
 check(get_viewport().gui_get_focus_owner() == restart_button, "结算后焦点进入重新开局按钮")
 send_key(KEY_TAB)
 send_key(KEY_TAB,0,true)
 check(get_viewport().gui_get_focus_owner() == restart_button, "结算 Tab 与 Shift+Tab 保持可用键盘入口")
 before = arena.flux[0]
 var hp_before: float = arena.bases[0].current_hp
 arena.bases[0].take_damage(100.0)
 check(not arena.deploy("triangle") and arena.flux[0] == before and arena.bases[0].current_hp == hp_before, "对局结束后停止扣费与战斗结算")
 send_key(KEY_ENTER,13)
 await get_tree().process_frame
 await get_tree().process_frame
 arena = get_tree().current_scene as MainArena
 arena.set_physics_process(false)
 arena.ai_enabled = false
 freeze_units()
 check(arena.phase == MainArena.Phase.PREPARING and arena.flux[0] == 180.0 and arena.units_for(0).size() == 9 and TacticalBrain.team_profiles[0]["stance"] == "balanced", "重开恢复阵容、资源、阶段和 Autoload 战术")
 arena.start_match()
 arena.resolve_timeout()
 check(arena.winner_team == -1, "基地血量相同时超时平局")
