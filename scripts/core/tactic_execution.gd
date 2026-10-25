class_name TacticExecution
extends RefCounted

var program: Dictionary = {}
var steps: Dictionary = {}
var current: String = ""
var state: Dictionary = {}
var suspended: Dictionary = {}
var latched: Dictionary = {}
var visits: Dictionary = {}
var status: String = "运行"
var reason: String = ""
var unit_time: float = 0.0
var cover_point: Vector2 = Vector2.INF
var cover_id: String = ""
var facts: Dictionary = {}
var facts_left: float = 0.0
var transition_serial: int = 0
var events: Array[String] = []
var goal: Vector2 = Vector2.INF
var move_direction: Vector2 = Vector2.ZERO
var direct: bool = false
var allow_attack: bool = false
var skill_policy: String = "hold"
var use_base: bool = false
var arrival_distance: float = 24.0

func install(value: Dictionary) -> void:
 program = value.duplicate(true)
 for entry: Dictionary in program["plan"]["steps"]: steps[entry["id"]] = entry
 current = program["plan"]["entry"]

func log_event(unit: BaseGeoUnit, text: String) -> void:
 var line: String = "%.2fs %s #%d %s" % [unit_time,unit.unit_type,unit.spawn_index,text]
 events.append(line)
 if events.size()>80: events.pop_front()
 unit.arena.tactic_event.emit(unit,line)

func enter(unit: BaseGeoUnit, id: String) -> void:
 current = id
 goal = Vector2.INF
 move_direction = Vector2.ZERO
 allow_attack = false
 skill_policy = "hold"
 direct = false
 visits[id] = int(visits.get(id,0))+1
 var step: Dictionary = steps[id]
 unit.rule = program["base"].duplicate(true)
 match str(step.get("target","current")):
  "nearest": unit.rule["priority"] = "closest"
  "diamond": unit.rule["priority"] = "diamond_first"
  "lowest_hp": unit.rule["priority"] = "lowest_hp"
 if step.get("target","current") != "current" or not unit.target_valid(): unit.evaluate_best_target()
 if step.get("target") in ["diamond","hexagon"]:
  var selected: BaseGeoUnit = null
  var distance: float = INF
  for enemy: BaseGeoUnit in unit.enemies():
   if enemy.unit_type == step["target"] and unit.global_position.distance_squared_to(enemy.global_position)<distance:
    selected = enemy
    distance = unit.global_position.distance_squared_to(enemy.global_position)
  unit.current_target = selected
 elif step.get("target") == "base": unit.current_target = unit.arena.base_for(1-unit.team)
 elif step.get("target") == "none": unit.current_target = null
 state = {"time":0.0,"path_index":0,"initialized":false,"started":false,"target":weakref(unit.current_target) if is_instance_valid(unit.current_target) else null,"direction":TacticPlan.direction(step,unit.team),"attacks":unit.attack_serial,"skills":unit.skill_serial,"skill_serial":-1,"portals":unit.portal_used_count,"pickups":unit.flux_collected_count,"scans":unit.scan_serial}
 transition_serial += 1
 reason = ""
 if is_instance_valid(unit.arena.navigation): unit.arena.navigation.routes.erase(unit.get_instance_id())
 facts_left = 0
 log_event(unit,"进入 "+id+" · "+str(step.get("label",step["action"])))

func stop(unit: BaseGeoUnit, message: String) -> void:
 transition_serial+=1
 status = "受阻停止"
 reason = message
 goal = Vector2.INF
 move_direction = Vector2.ZERO
 allow_attack = false
 skill_policy = "hold"
 log_event(unit,reason)

func transition(unit: BaseGeoUnit, link: String) -> void:
 if link == "stop":
  stop(unit,reason if not reason.is_empty() else "步骤失败，未配置恢复分支")
 elif link == "return":
  if suspended.is_empty():
   stop(unit,"return仅能从中断处理返回")
  else:
   current = suspended["id"]
   state = suspended["state"]
   cover_point = suspended["cover_point"]
   cover_id = suspended["cover_id"]
   suspended = {}
   goal = Vector2.INF
   move_direction = Vector2.ZERO
   direct = false
   allow_attack = false
   skill_policy = "hold"
   transition_serial += 1
   facts_left = 0
   log_event(unit,"恢复 "+current)
 elif link == "end":
  if not suspended.is_empty():
   transition(unit,"return")
  else:
   match str(program["plan"].get("finish","hold")):
    "repeat": enter(unit,program["plan"]["entry"])
    "base":
     transition_serial+=1
     status = "基础战术"
     use_base = true
    _:
     transition_serial+=1
     status = "完成待命"
     goal = Vector2.INF
     move_direction = Vector2.ZERO
     allow_attack = false
     skill_policy = "hold"
   log_event(unit,status)
 else: enter(unit,link)

func target(unit: BaseGeoUnit) -> Node2D:
 var ref: Variant = state.get("target")
 var victim: Node2D = ref.get_ref() as Node2D if ref is WeakRef else null
 if is_instance_valid(victim) and not bool(victim.get("dead")) and (not victim is BaseGeoUnit or not is_instance_valid(unit.arena.terrain) or unit.arena.terrain.can_perceive(unit,victim)):
  unit.current_target = victim
  return victim
 if is_instance_valid(victim): reason="目标不可感知，无法锁定"
 state["target"]=null
 unit.current_target = null
 return null

func destination(unit: BaseGeoUnit, spec: Dictionary) -> Vector2:
 var victim: Node2D = target(unit)
 match str(spec.get("anchor","target")):
  "point": return Vector2(spec["point"][0],spec["point"][1])
  "home": return unit.arena.base_for(unit.team).global_position+Vector2(130 if unit.team == 0 else -130,0)
  "enemy_base": return unit.arena.base_for(1-unit.team).global_position
  "cover": return cover_point
  "north_prism": return MapCatalog.prism_positions(str(unit.arena.get("map_id")))[0]
  "south_prism": return MapCatalog.prism_positions(str(unit.arena.get("map_id")))[1]
 if str(spec.get("anchor","target")) in ["rail_entry","rail_exit","portal","nebula","splitter_firing","safe_zone","flux_crystal"]:
  return unit.arena.terrain.semantic_goal(unit,str(spec["anchor"])) if is_instance_valid(unit.arena.terrain) else Vector2.INF
 if not is_instance_valid(victim): return Vector2.INF
 var heading: Vector2 = BoundaryManeuver.facing_of(victim)
 var distance: float = float(spec.get("distance",190))
 match str(spec.get("anchor","target")):
  "rear": return victim.global_position-heading*distance
  "target_left": return victim.global_position-heading.orthogonal()*distance
  "target_right": return victim.global_position+heading.orthogonal()*distance
 return victim.global_position

func update_facts(unit: BaseGeoUnit) -> void:
 facts = unit.tactic_facts()
 facts.merge({"match_time":float(unit.arena.get("elapsed")),"unit_time":unit_time,"step_time":float(state.get("time",0)),"arrived":goal.is_finite() and unit.global_position.distance_to(goal)<=arrival_distance,"target_lost":not unit.target_valid(),"in_cover":cover_point.is_finite() and unit.global_position.distance_to(cover_point)<=30 and CoverPlanner.hidden(unit,unit.global_position,unit.current_target),"cover_valid":cover_point.is_finite() and CoverPlanner.hidden(unit,cover_point,unit.current_target),"action_done":false,"action_failed":false,"step_attacks":unit.attack_serial-int(state.get("attacks",unit.attack_serial)),"step_skills":unit.skill_serial-int(state.get("skills",unit.skill_serial)),"step_portals":unit.portal_used_count-int(state.get("portals",unit.portal_used_count)),"step_pickups":unit.flux_collected_count-int(state.get("pickups",unit.flux_collected_count)),"step_scans":unit.scan_serial-int(state.get("scans",unit.scan_serial)),"step_visits":int(visits.get(current,0))},true)
 unit.last_facts = facts

func tick(unit: BaseGeoUnit, delta: float) -> void:
 if status != "运行": return
 unit_time += delta
 if state.is_empty(): enter(unit,current)
 target(unit)
 facts_left -= delta
 var refreshed: bool = facts_left<=0
 if refreshed:
  facts_left = 0.15
  update_facts(unit)
 if unit.stun_left>0: return
 if refreshed:
  for interrupt: Dictionary in program["plan"].get("interrupts",[]):
   var matches: bool = UnitTacticProgram.matches(interrupt["when"],facts)
   if not matches: latched[interrupt["id"]] = false
   elif suspended.is_empty() and not bool(latched.get(interrupt["id"],false)) and not unit.skill_active:
    latched[interrupt["id"]] = true
    suspended = {"id":current,"state":state.duplicate(true),"cover_point":cover_point,"cover_id":cover_id}
    enter(unit,interrupt["goto"])
    return
 state["time"] = float(state["time"])+delta
 facts["step_time"] = state["time"]
 facts["unit_time"] = unit_time
 facts["match_time"] = float(unit.arena.get("elapsed"))
 var step: Dictionary = steps[current]
 allow_attack = bool(step.get("attack",step["action"]=="attack_target"))
 skill_policy = str(step.get("skill","hold"))
 direct = false
 goal = Vector2.INF
 move_direction = Vector2.ZERO
 arrival_distance=24.0
 var done: bool = false
 var failed: String = str(state.get("pending_failure",""))
 state.erase("pending_failure")
 var victim: Node2D = target(unit)
 var action: String = step["action"]
 # A cover waypoint represents the safe stance outside a wall, not the wall
 # polygon itself. CharacterBody2D stops at its collision radius before the
 # exact geometric waypoint, so use a bounded cover tolerance while keeping
 # normal point movement precise.
 if action in ["seek_cover", "peek"] or (action == "move_to" and str(step.get("goal", {}).get("anchor", "")) == "cover"):
  arrival_distance = maxf(96.0, unit.unit_radius + 26.0)
 match action:
  "move_direction":
   direct = true
   move_direction = state["direction"]
   done = float(state["time"])+0.00001>=float(step.get("seconds",1))
   if unit.get_slide_collision_count()>0: reason = "方向移动被碰撞阻挡，保持原方向至时长结束"
  "move_to","retreat","flank_target":
   var spec: Dictionary = step.get("goal",{"anchor":"home" if action == "retreat" else "rear"})
   if action == "flank_target" and is_instance_valid(victim):
    goal = unit.boundary_maneuver.rear_position(unit,victim,BoundaryManeuver.facing_of(victim))
    if goal == unit.global_position: failed = "目标背后没有安全位置"
   else: goal = destination(unit,spec)
   var anchor: String=spec.get("anchor","")
   var collision_target: Node2D=unit.arena.base_for(1-unit.team) if anchor=="enemy_base" else victim if anchor=="target" else null
   if is_instance_valid(collision_target): arrival_distance=maxf(24,unit.unit_radius+float(collision_target.get("unit_radius"))+6)
   if anchor=="portal" and unit.portal_used_count>int(state["portals"]): done=true
   elif anchor=="flux_crystal" and unit.flux_collected_count>int(state["pickups"]): done=true
   elif not goal.is_finite(): failed = "目的地不可用、机关无可用次数或目标不可感知："+anchor
   elif anchor in ["portal","flux_crystal"]: done=false
   else: done = unit.global_position.distance_to(goal)<=arrival_distance
  "follow_path":
   var path: Array = step["path"]
   var index: int = int(state["path_index"])
   goal = Vector2(path[index][0],path[index][1])
   if unit.global_position.distance_to(goal)<=24:
    if index == path.size()-1: done = true
    else: state["path_index"] = index+1
  "seek_cover","peek":
   if not state["initialized"]:
    if action == "seek_cover":
     var found: Dictionary = CoverPlanner.find(unit,victim,str(step.get("obstacle","")))
     if found.get("pending",false):
      reason = found["message"]
      return
     if not found["ok"]: failed = found["message"]
     else:
      cover_point = found["point"]
      cover_id = found["obstacle"]
      state["goal"] = cover_point
      prime_route(unit,cover_point,found["route"])
    else:
     var found: Dictionary=CoverPlanner.peek_route(unit,cover_point,victim) if cover_point.is_finite() else {}
     if found.get("pending",false):
      reason=found["message"]
      return
     if found.is_empty(): failed = "没有可达探出点或尚未选择掩体"
     else:
      state["goal"] = found["point"]
      prime_route(unit,found["point"],found["route"])
    state["initialized"] = true
   goal = state.get("goal",Vector2.INF)
   if goal.is_finite():
    done = unit.global_position.distance_to(goal)<=arrival_distance
    if action == "seek_cover" and refreshed and not CoverPlanner.hidden(unit,goal,victim):
     # The threat may have moved while the unit was routing. Re-plan the
     # cover point in the same step so the tactic keeps its explicit cover
     # intent instead of silently switching to an attack or stopping.
     state["initialized"] = false
     state["goal"] = Vector2.INF
     goal = Vector2.INF
     done = false
     reason = "威胁移动，重新寻找掩体"
  "wait": done = not step.has("when") and float(state["time"])+0.00001>=float(step.get("seconds",1))
  "attack_target":
   allow_attack = true
   done = not is_instance_valid(victim)
  "cast_skill":
   if not state["started"]:
    var result: Dictionary = SkillRequest.attempt(unit,step.get("skill_request",{"aim":"auto"})) if refreshed else {"ok":false,"message":reason}
    reason = result["message"]
    if result["ok"]:
     state["started"] = true
     state["skill_serial"] = result["serial"]
     state["ability"]=result.get("ability","primary")
     if state["ability"]=="scan": done=true
   else:
    if state.get("ability")=="scan": done=unit.scan_serial>=int(state["skill_serial"])
    elif unit.skill_interrupted_serial == int(state["skill_serial"]): failed = "技能被中断"
    if state.get("ability","primary")=="primary": done = unit.skill_complete_serial == int(state["skill_serial"])
 if step.has("when"):
  facts["action_done"] = done
  facts["action_failed"] = not failed.is_empty()
  done = UnitTacticProgram.matches(step["when"],facts)
 var skill_aim: String=step.get("skill_request",{}).get("aim","auto")
 var needs_target: bool=step.get("skill_request",{}).get("ability","primary")!="scan" and (action!="cast_skill" or skill_aim=="target" or (skill_aim=="auto" and unit.unit_type in ["triangle","diamond"]))
 if failed.is_empty() and action in ["seek_cover","peek","flank_target","attack_target","cast_skill"] and not is_instance_valid(victim) and not done and needs_target and not unit.skill_active: failed = "目标已死亡或丢失"
 if not failed.is_empty() and not unit.skill_active:
  reason = failed
  log_event(unit,current+"失败："+reason)
  transition(unit,str(step.get("on_failure","stop")))
 elif done and not unit.skill_active:
  reason = ""
  transition(unit,str(step.get("next","end")))
 elif float(state["time"])+0.00001>=float(step.get("timeout",20)) and not unit.skill_active:
  reason = "步骤超时："+current+("；"+reason if not reason.is_empty() else "")
  log_event(unit,reason)
  transition(unit,str(step.get("on_failure","stop")))
 unit.matched_rule = current+" · "+status
 unit.action_blocked = reason

func movement(unit: BaseGeoUnit) -> Vector2:
 if status != "运行": return Vector2.ZERO
 if direct: return move_direction
 var strategy: String=str(steps[current].get("terrain_strategy",program["base"].get("terrain_strategy","none")))
 if is_instance_valid(unit.arena.terrain) and strategy!="none" and strategy!="auto":
  var adjusted: Vector2=unit.arena.terrain.strategy_goal(unit,goal if goal.is_finite() else unit.global_position,strategy)
  if adjusted.is_finite(): goal=adjusted
 if not goal.is_finite() or unit.global_position.distance_to(goal)<=arrival_distance: return Vector2.ZERO
 var direction: Vector2 = unit.arena.routed_direction(unit,goal,"plan:"+current+":"+str(transition_serial))
 if direction.is_zero_approx(): state["pending_failure"] = "无路可走："+current
 return direction

func prime_route(unit: BaseGeoUnit, point: Vector2, path: PackedVector2Array) -> void:
 unit.arena.navigation.routes[unit.get_instance_id()]={"goal":point,"intent":"plan:"+current+":"+str(transition_serial),"path":path,"index":0,"refresh":Engine.get_physics_frames()+27,"topology":unit.arena.terrain.topology_version if is_instance_valid(unit.arena.terrain) else 0,"portal_ready":unit.arena.navigation.portal_allowed(unit)}

func readout() -> Dictionary:
 var step: Dictionary=steps.get(current,{})
 var duration: float=float(step.get("seconds",1)) if step.get("action")=="move_direction" or (step.get("action")=="wait" and not step.has("when")) else float(step.get("timeout",20))
 var ref: Variant=state.get("target")
 var victim: Node2D=ref.get_ref() as Node2D if ref is WeakRef else null
 var target_data: Dictionary={}
 if is_instance_valid(victim): target_data={"type":victim.unit_type if victim is BaseGeoUnit else "base","position":[victim.global_position.x,victim.global_position.y],"alive":not bool(victim.get("dead"))}
 return {"step":current,"status":status,"reason":reason,"step_seconds":state.get("time",0),"remaining":maxf(0,duration-float(state.get("time",0))),"timeout_remaining":maxf(0,float(step.get("timeout",20))-float(state.get("time",0))),"target":target_data,"waypoint_index":state.get("path_index",0),"goal":[goal.x,goal.y] if goal.is_finite() else [],"cover":[cover_point.x,cover_point.y] if cover_point.is_finite() else [],"obstacle":cover_id,"protection":"仅墙体遮挡指定目标的直射；不免疫范围攻击或折射激光","transition":transition_serial,"facts":facts}
