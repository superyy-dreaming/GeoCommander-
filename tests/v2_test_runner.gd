extends Node

var checks: int = 0
var failures: int = 0
var arena: MainArena
var fixture_viewports: Array[SubViewport] = []

func check(ok: bool, description: String) -> void:
 checks += 1
 if ok: print("PASS: "+description)
 else:
  failures += 1
  push_error("FAIL: "+description)

func _ready() -> void:
 await get_tree().process_frame
 await run_tests()
 print("V2_TEST_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures == 0 else 1)

func fixture() -> CombatContext:
 var viewport: SubViewport = SubViewport.new()
 viewport.world_2d = World2D.new()
 viewport.size = Vector2i(820,680)
 add_child(viewport)
 fixture_viewports.append(viewport)
 var context: CombatContext = CombatContext.new()
 viewport.add_child(context)
 return context

func spawn(context: CombatContext, kind: String, team: int, point: Vector2) -> BaseGeoUnit:
 var script: Script = load("res://scripts/units/unit_"+kind+".gd")
 var unit: BaseGeoUnit = script.new() as BaseGeoUnit
 unit.arena = context
 unit.team = team
 unit.position = point
 unit.scripted_control = true
 context.add_child(unit)
 return unit

func frames(count: int) -> void:
 for index: int in range(count): await get_tree().physics_frame

func run_tests() -> void:
 var prompts: Dictionary = {"中路推进":"mid","走中路":"mid","mid lane":"mid","分推":"split","南北包抄":"split","split push":"split"}
 for prompt: String in prompts:
  var result: Dictionary = TacticalBrain.parse_prompt(prompt)
  check(bool(result["ok"]) and result["profile"]["lane_mode"] == prompts[prompt],"通道关键词 "+prompt)
 for prompt: String in ["利用地形折射","晶簇折射","crystal bounce"]:
  check(TacticalBrain.parse_prompt(prompt)["profile"]["unit_rules"]["diamond"]["movement"] == "align_with_crystal","完整晶簇短语不被通用折射覆盖："+prompt)
 check(TacticalBrain.parse_prompt("crystal bounce 然后 refract")["profile"]["unit_rules"]["diamond"]["movement"] == "align_with_square","独立后置护盾折射指令覆盖晶簇偏好")
 check(TacticalBrain.parse_prompt("走中路，然后南北包抄")["profile"]["lane_mode"] == "split","通道冲突按文本顺序覆盖")
 check(TacticalBrain.parse_prompt("分推，晶簇折射，然后均衡")["profile"] == TacticalBrain.get_default_profile(),"均衡恢复含地形字段的默认配置")
 for kind: String in UnitCatalog.TYPES:
  check(bool(TacticalBrain.parse_prompt(UnitDossier.DATA[kind]["prompt"])["ok"]),"档案推荐指令可真实编译："+kind)
 check(bool(TacticalBrain.save_opening_prompt("分推，晶簇折射")["ok"]),"保存默认开局指令")
 check(not bool(TacticalBrain.save_opening_prompt("unrecognized")["ok"]) and TacticalBrain.opening_prompt == "分推，晶簇折射","无效开局指令不覆盖设置")
 arena = (load("res://scenes/main_arena.tscn") as PackedScene).instantiate() as MainArena
 add_child(arena)
 arena.set_physics_process(false)
 arena.ai_enabled = false
 for unit: BaseGeoUnit in arena.local_units: unit.set_physics_process(false)
 check(arena.phase == MainArena.Phase.PREPARING and TacticalBrain.team_profiles[0]["lane_mode"] == "split","战场准备阶段带入菜单开局指令")
 check(TacticalBrain.team_profiles[1] == TacticalBrain.get_default_profile(),"开局设置不污染红方配置")
 arena.submit_tactic("全军突击")
 check(TacticalBrain.opening_prompt == "分推，晶簇折射","战场战术不反向覆盖默认开局")
 TacticalBrain.begin_match_profiles()
 check(TacticalBrain.team_profiles[0]["unit_rules"]["diamond"]["movement"] == "align_with_crystal","再次开局恢复已保存设置")
 var terrain: ArenaObstacles = arena.navigation
 check(terrain.walls.size() == 6 and terrain.crystals.size() == 4 and terrain.fields.size() == 2,"六掩体、四晶簇、两减速区")
 check(terrain.crystals[0].collision_layer == 20 and terrain.walls[0].collision_layer == 16,"地形碰撞层保持五层契约")
 check(not arena.spawn_clear(terrain.crystals[0].position,18) and not arena.spawn_clear(terrain.walls[0].position,18),"安全部署拒绝掩体及晶簇内位置")
 var path: PackedVector2Array = terrain.make_route(Vector2(350,675),Vector2(2050,675))
 var valid_path: bool = path.size() > 2
 var start: Vector2 = Vector2(350,675)
 for point: Vector2 in path:
  valid_path = valid_path and terrain.segment_clear(start,point)
  start = point
 check(valid_path,"全局路线绕开中路晶簇，逐段满足单位净空")
 for y: float in [260.0,675.0,1090.0]:
  check(not terrain.make_route(Vector2(350,y),Vector2(2050,y)).is_empty(),"三路均存在跨场可通行路径 Y="+str(y))
 await frames(3)
 var context: CombatContext = fixture()
 var diamond: BaseGeoUnit = spawn(context,"diamond",0,Vector2(140,500))
 var mirror: PrismBarrier = PrismBarrier.new()
 mirror.arena = context
 mirror.team = 0
 mirror.position = Vector2(400,500)
 mirror.rotation = PI/4.0
 mirror.life = 100.0
 context.add_child(mirror)
 var target: BaseGeoUnit = spawn(context,"square",1,Vector2(395,300))
 await frames(3)
 diamond.call("fire_beam",Vector2.RIGHT)
 check(is_equal_approx(target.current_hp,460.0-85.0*1.35),"严格法线折射护盾段增伤35%且命中拐角目标")
 mirror.queue_free()
 await frames(2)
 var crystal: NeutralCrystal = NeutralCrystal.new()
 crystal.arena = context
 crystal.position = Vector2(400,500)
 context.add_child(crystal)
 target.position = Vector2(700,100)
 await frames(2)
 var trace: BeamTrace = BeamTrace.trace(context,diamond.position,Vector2.RIGHT)
 check(trace.bounces == 1 and is_equal_approx(trace.gains[1],1.25),"中立晶簇折射增伤25%")
 target.position = trace.points[1].lerp(trace.points[2],0.35)
 diamond.call("fire_beam",Vector2.RIGHT)
 check(is_equal_approx(target.current_hp,460.0-85.0*1.35-85.0*1.25),"中立晶簇实际折射段按25%结算")
 check(diamond.enemies().size() == 1 and arena.units_for(1).size() == 9,"物理世界与敌我查询均隔离")
 for team: int in [0,1]:
  var mover: BaseGeoUnit = spawn(context,"triangle",team,Vector2(300,500))
  mover.scripted_direction = Vector2.RIGHT
  await frames(40)
  check(mover.position.x < 360.0,"晶簇阻挡队伍 "+str(team)+" 的物理移动")
  mover.die()
 await frames(2)
 var field: EntropyField = EntropyField.new()
 field.arena = context
 field.position = Vector2(160,160)
 context.add_child(field)
 var slow_unit: BaseGeoUnit = spawn(context,"square",0,Vector2(160,160))
 await frames(4)
 check(is_equal_approx(slow_unit.terrain_multiplier(),0.65),"进入熵减区速度乘0.65")
 var second: EntropyField = EntropyField.new()
 second.arena = context
 second.position = field.position
 context.add_child(second)
 await frames(4)
 check(slow_unit.slow_sources.size() == 2 and is_equal_approx(slow_unit.terrain_multiplier(),0.65),"重叠区域按来源记录且不叠乘")
 slow_unit.scripted_direction = Vector2.RIGHT
 slow_unit.overclock_left = 1.0
 check(is_equal_approx(slow_unit.movement_velocity(0.016).length(),115.0*1.6*0.65),"超频与地形减速相乘")
 slow_unit.scripted_direction = Vector2.ZERO
 field.queue_free()
 await frames(2)
 check(slow_unit.slow_sources.size() == 1,"释放一个区域不解除另一个区域的减速")
 slow_unit.position = Vector2(700,600)
 await frames(4)
 check(slow_unit.slow_sources.is_empty(),"离开区域自动清除减速来源")
 second.queue_free()
 var stage: UnitShowcaseStage = UnitShowcaseStage.new()
 stage.size = Vector2(820,680)
 add_child(stage)
 stage.set_auto_loop(false)
 var profile_before: Array[Dictionary] = TacticalBrain.team_profiles.duplicate(true)
 var flux_before: Array[float] = arena.flux.duplicate()
 for kind: String in UnitCatalog.TYPES:
  stage.select_unit(kind)
  stage.set_auto_loop(false)
  await frames(3)
  var previous_events: int = stage.damage_log.size()
  if kind != "hexagon":
   stage.demonstrate_attack()
   await frames(150)
   check(stage.attack_count == 1 and stage.damage_log.size() > previous_events,"演武真实普攻命中："+kind)
  else:
   stage.demonstrate_attack()
   check(stage.attack_count == 0,"六边形演武没有虚构普攻")
  stage.demonstrate_skill()
  await frames(125)
  check(stage.skill_count == 1 and not stage.busy,"演武真实技能完成："+kind)
  if kind == "triangle": check(stage.damage_log.has(110.0),"演武背刺实际产生110伤害")
  if kind == "diamond": check(stage.last_beam_bounces == 1 and stage.damage_log.any(func(value: float) -> bool: return is_equal_approx(value,114.75)),"菱形演武经护盾转向并以增幅伤害命中")
  if kind == "square":
   check(stage.context.reflectors.any(func(surface: LaserReflector) -> bool: return surface is PrismBarrier and is_equal_approx(surface.get("hp"),254.0)),"方形演武敌方真实弹体撞盾并扣除26耐久")
   check(stage.damage_log.any(func(value: float) -> bool: return is_equal_approx(value,114.75)),"方形演武友方菱形实际借盾折射命中")
  if kind == "hexagon":
   var healed: bool = true
   for friend: BaseGeoUnit in stage.healing_targets: healed = healed and friend.current_hp > friend.max_hp*0.5
   check(healed,"六边形演武实际恢复三名友军生命")
 check(TacticalBrain.team_profiles == profile_before and arena.flux == flux_before and arena.units_for(0).size() == 9,"所有演武不改变战局战术、经济或人口")
 stage.select_unit("diamond")
 stage.demonstrate_skill()
 await frames(5)
 stage.select_unit("hexagon")
 var epoch: int = stage.generation
 await frames(90)
 check(stage.generation == epoch and stage.actor.unit_type == "hexagon" and stage.damage_log.is_empty(),"切换兵种使旧蓄力及伤害回调失效")
 stage.set_auto_loop(true)
 stage.select_unit("circle")
 await frames(600)
 check(stage.attack_count > 0 and stage.skill_count > 0,"自动循环能够同时演示普攻和技能")
 stage.set_auto_loop(false)
 await frames(140)
 var counts: Vector2i = Vector2i(stage.attack_count,stage.skill_count)
 await frames(240)
 check(counts == Vector2i(stage.attack_count,stage.skill_count),"关闭自动循环不再产生新动作")
 stage.reset_scenario()
 check(not stage.auto_loop and not stage.busy,"重置保留自动开关并解除施放占用")
 stage.shutdown()
 TacticalBrain.save_opening_prompt("默认均衡战术")
