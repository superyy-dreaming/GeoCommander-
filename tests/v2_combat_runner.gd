extends Node

var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
 checks += 1
 if ok: print("PASS: "+label)
 else:
  failures += 1
  push_error("FAIL: "+label)

func frames(count: int) -> void:
 for index: int in range(count): await get_tree().physics_frame

func fixture() -> CombatContext:
 var viewport: SubViewport = SubViewport.new()
 viewport.world_2d = World2D.new()
 add_child(viewport)
 var context: CombatContext = CombatContext.new()
 viewport.add_child(context)
 return context

func spawn(context: CombatContext, kind: String, team: int, point: Vector2) -> BaseGeoUnit:
 var unit: BaseGeoUnit = (load("res://scripts/units/unit_"+kind+".gd") as Script).new() as BaseGeoUnit
 unit.arena = context
 unit.team = team
 unit.position = point
 unit.scripted_control = true
 context.add_child(unit)
 return unit

func _ready() -> void:
 await get_tree().physics_frame
 var context: CombatContext = fixture()
 var laser: BaseGeoUnit = spawn(context,"diamond",0,Vector2(140,510))
 var crystal: NeutralCrystal = NeutralCrystal.new()
 crystal.arena = context
 crystal.position = Vector2(400,500)
 context.add_child(crystal)
 await frames(3)
 var first: BeamTrace = BeamTrace.trace(context,laser.position,Vector2.RIGHT)
 var outgoing: Vector2 = first.points[1].direction_to(first.points[2])
 var mirror: PrismBarrier = PrismBarrier.new()
 mirror.arena = context
 mirror.position = first.points[1]+outgoing*150.0
 mirror.rotation = outgoing.angle()+PI/4.0
 mirror.life = 100.0
 context.add_child(mirror)
 await frames(3)
 var trace: BeamTrace = BeamTrace.trace(context,laser.position,Vector2.RIGHT)
 check(trace.bounces == 2 and trace.points.size() == 4,"晶簇与护盾混合路径恰好两次折射")
 check(trace.gains.size() == 3 and is_equal_approx(trace.gains[2],1.25*1.35),"混合折射逐段乘以1.25与1.35")
 var total: float = 0.0
 for index: int in range(trace.points.size()-1): total += trace.points[index].distance_to(trace.points[index+1])
 check(total <= 750.01 and trace.normals.size() == trace.gains.size(),"激光总路径不超过750px并保留各段法线")
 var target: BaseGeoUnit = spawn(context,"square",1,trace.points[2].lerp(trace.points[3],0.5))
 await frames(2)
 laser.call("fire_beam",Vector2.RIGHT)
 check(is_equal_approx(target.current_hp,target.max_hp-85.0*1.25*1.35),"两次混合折射以实际倍率结算伤害")
 target.position = first.points[1]+outgoing*70.0
 mirror.rotation = outgoing.angle()
 await frames(3)
 target.heal(1000.0)
 laser.call("fire_beam",Vector2.RIGHT)
 check(is_equal_approx(target.current_hp,target.max_hp-85.0*1.25),"光束折返穿过同目标只扣一次生命")
 var walls: CombatContext = fixture()
 var wall: TerrainWall = TerrainWall.new()
 wall.position = Vector2(300,350)
 wall.polygon = PackedVector2Array([Vector2(-10,-100),Vector2(10,-100),Vector2(10,100),Vector2(-10,100)])
 walls.add_child(wall)
 var shooter: BaseGeoUnit = spawn(walls,"diamond",0,Vector2(140,350))
 var behind: BaseGeoUnit = spawn(walls,"square",1,Vector2(440,350))
 await frames(3)
 var blocked: BeamTrace = BeamTrace.trace(walls,shooter.position,Vector2.RIGHT)
 check(blocked.bounces == 0 and blocked.points[-1].x < 301.0,"黑曜石停止激光且不反射")
 shooter.call("fire_beam",Vector2.RIGHT)
 shooter.current_target = behind
 shooter.basic_attack()
 await frames(30)
 check(is_equal_approx(behind.current_hp,behind.max_hp),"掩体同时阻挡真实激光与高速弹体")
 shooter.queue_free()
 await frames(2)
 var striker: BaseGeoUnit = spawn(walls,"triangle",0,Vector2(140,350))
 striker.set("dash_state",2)
 striker.slow_sources[-1] = 0.65
 striker.overclock_left = 1.0
 check(is_equal_approx(striker.movement_velocity(0.016).length(),980.0*0.65*1.6),"冲刺同时应用熵减与超频的乘法倍率")
 striker.cancel_active_skill()
 striker.slow_sources.clear()
 striker.overclock_left = 0.0
 striker.current_target = behind
 striker.skill_left = 0.0
 check(striker.try_cast_skill(),"地形冲刺测试使用真实技能入口")
 await frames(60)
 check(striker.position.x < 277.0 and behind.current_hp == behind.max_hp,"冲刺被掩体截停且不伤害墙后敌人")
 var arena: MainArena = (load("res://scenes/main_arena.tscn") as PackedScene).instantiate() as MainArena
 add_child(arena)
 arena.start_match()
 arena.set_physics_process(false)
 arena.ai_enabled = false
 for unit: BaseGeoUnit in arena.local_units: unit.set_physics_process(false)
 arena.flux[0] = 500.0
 var solid: PackedVector2Array = PackedVector2Array([Vector2(25,25),Vector2(2375,25),Vector2(2375,1325),Vector2(25,1325)])
 arena.navigation.solid_polygons.append(solid)
 var money: float = arena.flux[0]
 var population: int = arena.units_for(0).size()
 check(not arena.deploy("triangle") and arena.flux[0] == money and arena.units_for(0).size() == population,"没有安全部署位置时不扣资源且不增加人口")
 arena.navigation.solid_polygons.remove_at(arena.navigation.solid_polygons.size()-1)
 var center: Vector2 = Vector2(1200,675)
 arena.spawn_unit("square",1,center,false).set_physics_process(false)
 var blocker: TerrainWall = TerrainWall.new()
 blocker.position = center
 blocker.polygon = PackedVector2Array([Vector2(-300,-300),Vector2(300,-300),Vector2(300,300),Vector2(-300,300)])
 arena.add_child(blocker)
 await frames(3)
 var positions: Array[Vector2] = []
 for unit: BaseGeoUnit in arena.units_for(0): positions.append(unit.position)
 check(not arena.cast_skill("TOPOLOGY_SWAP",center) and arena.flux[0] == money and arena.skill_cooldowns["TOPOLOGY_SWAP"] == 0.0,"转移无安全落点不扣费且不进入冷却")
 var unchanged: bool = true
 for index: int in range(positions.size()): unchanged = unchanged and positions[index] == arena.units_for(0)[index].position
 check(unchanged,"转移失败不部分移动任何单位")
 print("V2_COMBAT_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures == 0 else 1)
