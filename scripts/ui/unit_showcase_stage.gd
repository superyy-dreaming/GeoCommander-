class_name UnitShowcaseStage
extends Control

signal state_changed

var viewport: SubViewport
var display: SubViewportContainer
var world_root: Node2D
var context: CombatContext
var damage_layer: CanvasLayer
var actor: BaseGeoUnit
var selected_kind: String = "triangle"
var auto_loop: bool = true
var busy: bool = false
var generation: int = 0
var next_attack: float = 1.5
var next_skill: float = 3.5
var status: String = "真实物理演武，演示节奏已加速"
var damage_log: Array[float] = []
var last_beam_bounces: int = 0
var attack_count: int = 0
var skill_count: int = 0
var terminal_left: float = 30.0
var background: ShaderMaterial
var helper: BaseGeoUnit
var scenario_wall: TerrainWall
var healing_targets: Array[BaseGeoUnit] = []

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 custom_minimum_size = Vector2(360,300)
 display = SubViewportContainer.new()
 display.mouse_filter = Control.MOUSE_FILTER_IGNORE
 display.size = Vector2(820,680)
 add_child(display)
 viewport = SubViewport.new()
 viewport.size = Vector2i(820,680)
 viewport.world_2d = World2D.new()
 viewport.use_hdr_2d = true
 viewport.msaa_2d = Viewport.MSAA_4X
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 display.add_child(viewport)
 world_root = Node2D.new()
 viewport.add_child(world_root)
 background = CombatContext.create_environment(world_root,Rect2(0,0,820,680))
 resized.connect(fit_stage)
 fit_stage()
 GameSettings.settings_changed.connect(_settings_updated)
 select_unit(selected_kind)

func fit_stage() -> void:
 if not is_instance_valid(display): return
 var factor: float = minf(size.x/820.0,size.y/680.0)
 display.scale = Vector2.ONE * factor
 display.position = (size-Vector2(820,680)*factor)*0.5

func spawn(kind: String, team: int, point: Vector2) -> BaseGeoUnit:
 var code: Script = load("res://scripts/units/unit_"+kind+".gd")
 var unit: BaseGeoUnit = code.new() as BaseGeoUnit
 unit.arena = context
 unit.team = team
 unit.position = point
 unit.scripted_control = true
 context.add_child(unit)
 return unit

func select_unit(kind: String) -> void:
 if not UnitCatalog.TYPES.has(kind): return
 selected_kind = kind
 attack_count = 0
 skill_count = 0
 damage_log.clear()
 last_beam_bounces = 0
 reset_scenario()

func reset_scenario(restart_clock: bool = true) -> void:
 generation += 1
 busy = false
 if restart_clock:
  next_attack = 1.5
  next_skill = 3.5
 terminal_left = 30.0
 healing_targets.clear()
 helper = null
 scenario_wall = null
 if is_instance_valid(context):
  context.active = false
  context.queue_free()
 context = CombatContext.new()
 context.reduced_motion = bool(GameSettings.values["reduced_motion"])
 context.damage_reported.connect(_damage_reported)
 context.unit_removed.connect(_dummy_died)
 world_root.add_child(context)
 damage_layer = CanvasLayer.new()
 damage_layer.layer = 10
 context.add_child(damage_layer)
 build_bounds()
 match selected_kind:
  "triangle":
   actor = spawn("triangle",0,Vector2(240,350))
   spawn("diamond",1,Vector2(420,350))
   spawn("diamond",1,Vector2(510,350))
  "square":
   actor = spawn("square",0,Vector2(340,500))
   spawn("hexagon",0,Vector2(230,520))
   helper = spawn("diamond",0,Vector2(130,500))
   spawn("circle",1,Vector2(400,240))
   spawn("diamond",1,Vector2(570,340))
   actor.rule["skill_cond"] = "reflect_laser"
  "circle":
   actor = spawn("circle",0,Vector2(240,350))
   for point: Vector2 in [Vector2(420,310),Vector2(480,350),Vector2(420,410),Vector2(500,420)]:
    spawn("triangle",1,point)
  "diamond":
   actor = spawn("diamond",0,Vector2(140,500))
   var barrier: PrismBarrier = PrismBarrier.new()
   barrier.arena = context
   barrier.team = 0
   barrier.position = Vector2(400,500)
   barrier.rotation = PI/4.0
   barrier.life = 1000.0
   context.add_child(barrier)
   for y: float in [360.0,275.0,190.0]: spawn("square",1,Vector2(395,y))
   scenario_wall = TerrainWall.new()
   scenario_wall.position = Vector2(270,330)
   scenario_wall.polygon = PackedVector2Array([Vector2(-60,-120),Vector2(60,-120),Vector2(60,120),Vector2(-60,120)])
   context.add_child(scenario_wall)
  "hexagon":
   actor = spawn("hexagon",0,Vector2(410,340))
   for index: int in range(3):
    var unit: BaseGeoUnit = spawn(UnitCatalog.TYPES[index],0,Vector2(410,340)+Vector2.RIGHT.rotated(float(index)*TAU/3.0)*150.0)
    unit.current_hp = unit.max_hp*0.5
    unit.heal(0.0)
    healing_targets.append(unit)
 if not context.units_for(1).is_empty(): actor.current_target = context.units_for(1)[0]
 set_reduced_motion(bool(GameSettings.values["reduced_motion"]))
 status = "无直接普攻。技能恢复友军生命，链路恢复速度 ×1.4" if selected_kind == "hexagon" else "靶人使用真实生命、受击和碎裂。演示冷却已加速。"
 state_changed.emit()

func build_bounds() -> void:
 var body: StaticBody2D = StaticBody2D.new()
 body.collision_layer = 16
 context.add_child(body)
 for rect: Rect2 in [Rect2(-30,-30,880,30),Rect2(-30,680,880,30),Rect2(-30,0,30,680),Rect2(820,0,30,680)]:
  var collision: CollisionShape2D = CollisionShape2D.new()
  var shape: RectangleShape2D = RectangleShape2D.new()
  shape.size = rect.size
  collision.shape = shape
  collision.position = rect.get_center()
  body.add_child(collision)

func set_reduced_motion(enabled: bool) -> void:
 if is_instance_valid(context): context.reduced_motion = enabled
 if is_instance_valid(background): background.set_shader_parameter("reduced_motion",enabled)

func set_auto_loop(enabled: bool) -> void:
 auto_loop = enabled
 state_changed.emit()

func _physics_process(delta: float) -> void:
 if not is_instance_valid(actor): return
 terminal_left = maxf(0.0,terminal_left-delta*(1.4 if selected_kind == "hexagon" else 1.0))
 if not auto_loop: return
 next_attack = maxf(0.0,next_attack-delta)
 next_skill = maxf(0.0,next_skill-delta)
 if busy: return
 if next_skill <= 0.0:
  next_skill = 3.5
  demonstrate_skill()
 elif next_attack <= 0.0 and selected_kind != "hexagon":
  next_attack = 1.5
  demonstrate_attack()

func wait_seconds(seconds: float, epoch: int) -> bool:
 await get_tree().create_timer(seconds,false,true).timeout
 return is_inside_tree() and generation == epoch

func demonstrate_attack() -> void:
 if busy or selected_kind == "hexagon": return
 reset_scenario(false)
 busy = true
 var epoch: int = generation
 state_changed.emit()
 await get_tree().physics_frame
 await get_tree().physics_frame
 if epoch != generation: return
 var target: BaseGeoUnit = context.units_for(1)[0]
 if selected_kind == "diamond":
  target.position = Vector2(440,560)
 if selected_kind == "square": target.position = actor.position+Vector2(105,0)
 actor.current_target = target
 status = "真实普攻：接近目标并结算伤害"
 if selected_kind in ["triangle","square"]:
  var frames: int = 0
  while is_instance_valid(target) and actor.global_position.distance_to(target.global_position) > actor.attack_range and frames < 100:
   actor.scripted_direction = actor.global_position.direction_to(target.global_position)
   await get_tree().physics_frame
   if epoch != generation: return
   frames += 1
  actor.scripted_direction = Vector2.ZERO
 actor.attack_left = 0.0
 actor.basic_attack()
 attack_count += 1
 if selected_kind == "diamond": actor.scripted_direction = Vector2.LEFT
 if not await wait_seconds(0.65,epoch): return
 actor.scripted_direction = Vector2.ZERO
 busy = false
 state_changed.emit()

func demonstrate_skill() -> void:
 if busy: return
 reset_scenario(false)
 busy = true
 var epoch: int = generation
 state_changed.emit()
 await get_tree().physics_frame
 await get_tree().physics_frame
 if epoch != generation: return
 actor.skill_left = 0.0
 if selected_kind == "square":
  helper.current_target = context.units_for(1)[0]
  helper.skill_left = 0.0
  helper.try_cast_skill()
 var started: bool = actor.try_cast_skill()
 if not started:
  status = "演武目标未满足施放条件，请重置靶场后重试"
  busy = false
  state_changed.emit()
  return
 skill_count += 1
 match selected_kind:
  "triangle": status = "Apex Dash：0.25 秒蓄力，背刺每目标 110 伤害"
  "circle": status = "Orbital Collapse：真实引力拉拽，随后坍缩击退"
  "diamond": status = "Refracting Beam：0.5 秒蓄力，护盾折射增伤 35%"
  "hexagon": status = "Command Resonance：每位友军恢复 35 HP，链路 ×1.4"
  "square":
   status = "Prism Barrier：敌弹受阻，友方激光经护盾折射"
   await get_tree().physics_frame
   await get_tree().physics_frame
   if epoch != generation: return
   var red: BaseGeoUnit = context.units_for(1)[1]
   red.current_target = context.units_for(0)[1]
   red.basic_attack()
   helper.current_target = context.units_for(1)[0]
   helper.cancel_active_skill()
   helper.skill_left = 0.0
   helper.try_cast_skill()
 state_changed.emit()
 if not await wait_seconds(1.7,epoch): return
 if selected_kind == "diamond": last_beam_bounces = int(actor.get("last_beam_bounces"))
 busy = false
 state_changed.emit()

func _damage_reported(unit: BaseGeoUnit, amount: float, _attacker: Node2D) -> void:
 damage_log.append(amount)
 var card: PanelContainer = PanelContainer.new()
 card.mouse_filter = Control.MOUSE_FILTER_IGNORE
 card.theme = CommanderTheme.create()
 var frame: StyleBoxFlat = CommanderTheme.box(Color(0.012,0.025,0.04,0.96),Color(0.7,0.55,0.16))
 frame.content_margin_top = 3
 frame.content_margin_bottom = 3
 frame.content_margin_left = 8
 frame.content_margin_right = 8
 card.add_theme_stylebox_override("panel",frame)
 card.custom_minimum_size = Vector2(150,34)
 card.position = unit.position+Vector2(26,-36)
 card.position.x = clampf(card.position.x,8,656)
 for previous: Node in damage_layer.get_children():
  if previous is Control and Rect2((previous as Control).position,Vector2(155,38)).intersects(Rect2(card.position,Vector2(155,38))):
   card.position.y = minf(card.position.y,(previous as Control).position.y-40)
 card.position.y = clampf(card.position.y,8,630)
 var text: Label = Label.new()
 var value: String = ("%.2f" % amount).trim_suffix("0").trim_suffix("0").trim_suffix(".")
 text.text = ("背刺 " if is_equal_approx(amount,110.0) else "")+value+" DMG"
 CommanderTheme.font(text,20)
 text.add_theme_color_override("font_color",Color(1.0,0.85,0.4))
 text.mouse_filter = Control.MOUSE_FILTER_IGNORE
 card.add_child(text)
 damage_layer.add_child(card)
 var tween: Tween = card.create_tween().set_parallel(true)
 if not context.reduced_motion: tween.tween_property(card,"position:y",card.position.y-22,0.8)
 tween.tween_property(card,"modulate:a",0.0,0.8)
 tween.chain().tween_callback(card.queue_free)

func _dummy_died(unit: BaseGeoUnit) -> void:
 if unit.team != 1: return
 var epoch: int = generation
 var point: Vector2 = unit.position
 var kind: String = unit.unit_type
 if await wait_seconds(0.8,epoch): spawn(kind,1,point)

func shutdown() -> void:
 generation += 1
 auto_loop = false
 busy = false
 if is_instance_valid(context): context.active = false
 set_physics_process(false)

func _settings_updated() -> void:
 set_reduced_motion(bool(GameSettings.values["reduced_motion"]))
 if is_instance_valid(damage_layer): CommanderTheme.refresh_fonts(damage_layer)
