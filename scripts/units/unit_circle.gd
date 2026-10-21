extends BaseGeoUnit

func _init() -> void:
 unit_type = "circle"

func tick_unit(_delta: float) -> void:
 if not scripted_control:
  basic_attack()
  automatic_skill()

func try_cast_skill() -> bool:
 if skill_left > 0.0 or not target_valid():
  return false
 var enemy_list: Array[BaseGeoUnit] = enemies()
 var best_cluster: Array[BaseGeoUnit] = []
 for candidate: BaseGeoUnit in enemy_list:
  if global_position.distance_to(candidate.global_position) > 320.0:
   continue
  var cluster: Array[BaseGeoUnit] = []
  for enemy: BaseGeoUnit in enemy_list:
   if candidate.global_position.distance_to(enemy.global_position) < 160.0:
    cluster.append(enemy)
  if cluster.size() > best_cluster.size():
   best_cluster = cluster
 var minimum: int = 3 if String(rule.get("skill_cond")) == "cluster_3plus" else 2
 if best_cluster.size() < minimum:
  return false
 var center: Vector2 = Vector2.ZERO
 for enemy: BaseGeoUnit in best_cluster:
  center += enemy.global_position
 center /= float(best_cluster.size())
 if global_position.distance_to(center) > 320.0:
  return false
 var well: GravityWell = GravityWell.new()
 well.team = team
 well.arena = arena
 well.position = center
 arena.add_child(well)
 skill_left = skill_cd
 skill_started()
 return true
