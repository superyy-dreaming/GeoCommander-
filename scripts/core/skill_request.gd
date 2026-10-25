class_name SkillRequest
extends RefCounted

static func validation_error(value: Variant, kind: String) -> String:
 if not value is Dictionary: return "skill_request必须是对象"
 var extra: String = UnitTacticProgram.unknown(value,["ability","aim","direction","angle","point","purpose"])
 if not extra.is_empty(): return extra
 if value.get("ability","primary") not in ["primary","scan"]: return "未知技能ability"
 if value.get("ability")=="scan" and kind!="hexagon": return "仅六边形支持独立扫描"
 if value.get("aim","auto") not in ["auto","target","direction","point","self"]: return "未知技能瞄准方式"
 if value.get("purpose","attack") not in ["attack","travel","backstab","support","reflect"]: return "未知技能用途"
 if value.get("aim")=="direction" and not value.has("direction"): return "定向技能需要明确的direction"
 if kind in ["triangle","circle","diamond"] and value.get("purpose") == "support": return "support仅用于方形保护或六边形治疗"
 if value.get("aim") == "point" and not TacticPlan.point_valid(value.get("point")): return "定点技能需要合法point"
 if value.get("aim") == "direction" and value.get("direction","forward") not in TacticPlan.DIRECTIONS and value.get("direction","forward") not in ["forward","backward","angle"]: return "未知技能方向"
 if value.has("angle") and (not UnitTacticProgram.numeric(value["angle"]) or absf(value["angle"])>360): return "技能角度超出范围"
 if kind == "hexagon" and (value.get("aim","auto") not in ["auto","self"] or value.get("purpose","support") not in ["support","attack"]): return "六边形只能自身治疗脉冲"
 if kind != "triangle" and value.get("purpose") in ["travel","backstab"]: return "仅三角可赶路或背刺"
 if kind != "square" and value.get("purpose") == "reflect": return "reflect用于方形护盾；菱形使用auto实际寻镜或指定方向"
 if kind == "circle" and value.get("aim","auto") not in ["auto","target","point"]: return "圆形需要目标或地面位置"
 if kind in ["triangle","square","diamond"] and value.get("aim") == "self": return "此兵种不支持自身瞄准"
 return ""

static func attempt(unit: BaseGeoUnit, spec: Dictionary) -> Dictionary:
 var reason: String = validation_error(spec,unit.unit_type)
 if reason.is_empty():
  if unit.dead or not unit.arena.is_combat_active(): reason = "战斗未进行"
  elif unit.stun_left>0: reason = "正在受控"
  elif unit.skill_active: reason = "已有技能正在施放"
  elif spec.get("ability","primary")=="scan" and unit.scan_left>0: reason = "扫描冷却 %.2fs" % unit.scan_left
  elif spec.get("ability","primary")=="primary" and unit.skill_left>0: reason = "技能冷却 %.2fs" % unit.skill_left
 if not reason.is_empty():
  unit.arena.skill_lifecycle.emit(unit,"rejected",unit.skill_serial,reason)
  return {"ok":false,"message":reason}
 unit.requested_skill = spec.duplicate(true)
 unit.skill_rejection = "射程、朝向、聚集数量或合法目标不满足"
 var started: bool = unit.try_scan() if spec.get("ability","primary")=="scan" else unit.try_cast_skill()
 unit.requested_skill.clear()
 if not started: unit.arena.skill_lifecycle.emit(unit,"rejected",unit.skill_serial,unit.skill_rejection)
 return {"ok":started,"message":"技能已启动" if started else unit.skill_rejection,"serial":unit.scan_serial if spec.get("ability")=="scan" else unit.skill_serial,"ability":spec.get("ability","primary")}

static func point(unit: BaseGeoUnit, spec: Dictionary) -> Vector2:
 match str(spec.get("aim","auto")):
  "point": return Vector2(spec["point"][0],spec["point"][1])
  "direction": return unit.global_position+TacticPlan.direction(spec,unit.team)*300.0
 if unit.target_valid(): return unit.current_target.global_position
 return unit.global_position+Vector2.RIGHT.rotated(unit.visual_root.rotation)*300.0
