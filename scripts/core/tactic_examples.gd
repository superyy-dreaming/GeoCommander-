class_name TacticExamples
extends RefCounted

const PROMPT: String = "向上移动2秒；寻找能遮挡目标菱形直射的可达墙体后方；等待冲刺就绪，最多5秒；移动到菱形背后；满足实际背刺条件后冲刺；完成后返回掩体并循环。生命低于30%时中断并撤退。"

static func for_unit(kind: String) -> Dictionary:
 var value: Dictionary = TacticPlan.default_program(kind)
 var steps: Array = []
 if kind == "triangle":
  steps = [{"id":"north","label":"向上2秒","action":"move_direction","direction":"up","seconds":2.0,"target":"diamond","next":"cover"},{"id":"cover","label":"避开菱形直射","action":"seek_cover","target":"diamond","timeout":30.0,"next":"ready"},{"id":"ready","action":"wait","when":{"fact":"skill_ready","op":"eq","value":true},"timeout":5.0,"target":"diamond","next":"rear"},{"id":"rear","action":"flank_target","target":"diamond","timeout":30.0,"next":"strike"},{"id":"strike","action":"cast_skill","target":"diamond","skill_request":{"aim":"target","purpose":"backstab"},"timeout":5.0,"next":"return_cover"},{"id":"return_cover","action":"move_to","goal":{"anchor":"cover"},"target":"diamond","timeout":30.0,"next":"cover"}]
 elif kind == "square":
  steps = [{"id":"guard","action":"move_to","goal":{"anchor":"home"},"next":"shield"},{"id":"shield","action":"cast_skill","skill_request":{"aim":"direction","direction":"forward","purpose":"support"},"next":"wait"},{"id":"wait","action":"wait","seconds":2.0,"attack":true,"next":"shield"}]
 elif kind == "circle":
  steps = [{"id":"cover","action":"seek_cover","target":"nearest","timeout":30.0,"next":"ready"},{"id":"ready","action":"wait","when":{"all":[{"fact":"skill_ready","op":"eq","value":true},{"fact":"target_cluster","op":"gte","value":2}]},"timeout":15.0,"next":"gravity"},{"id":"gravity","action":"cast_skill","skill_request":{"aim":"auto"},"timeout":10.0,"next":"ready"}]
 elif kind == "diamond":
  steps = [{"id":"cover","action":"seek_cover","timeout":30.0,"next":"peek"},{"id":"peek","action":"peek","timeout":10.0,"next":"fire"},{"id":"fire","action":"cast_skill","skill_request":{"aim":"auto"},"timeout":10.0,"next":"hide"},{"id":"hide","action":"move_to","goal":{"anchor":"cover"},"next":"wait"},{"id":"wait","action":"wait","when":{"fact":"skill_ready","op":"eq","value":true},"timeout":10.0,"next":"peek"}]
 else:
  steps = [{"id":"wait","action":"wait","when":{"fact":"ally_min_hp","op":"lt","value":0.7},"timeout":120.0,"next":"heal"},{"id":"heal","action":"cast_skill","skill_request":{"aim":"self","purpose":"support"},"timeout":5.0,"next":"wait"}]
 steps.append({"id":"escape","action":"retreat","timeout":30.0,"next":"return"})
 value["plan"]["entry"] = steps[0]["id"]
 value["plan"]["steps"] = steps
 value["plan"]["interrupts"] = [{"id":"critical","when":{"fact":"self_hp","op":"lt","value":0.3},"goto":"escape"}]
 return value
