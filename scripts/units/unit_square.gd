extends BaseGeoUnit

func _init() -> void:
 unit_type = "square"

func tick_unit(_delta: float) -> void:
 if not scripted_control:
  basic_attack()
  automatic_skill()

func try_cast_skill() -> bool:
 if skill_left > 0.0:
  return false
 var should_deploy: bool = under_attack_left > 0.0
 if target_valid():
  should_deploy = should_deploy or global_position.distance_to(current_target.global_position) < 220.0
 for friend: BaseGeoUnit in allies():
  if friend.unit_type == "diamond" and global_position.distance_to(friend.global_position) < 380.0 and float(friend.get("windup_left")) > 0.0:
   should_deploy = true
 if (String(rule.get("skill_cond")) == "on_cooldown" or String(rule.get("skill_usage","auto")) == "try"):
  should_deploy = target_valid()
 if not requested_skill.is_empty(): should_deploy = true
 if not should_deploy:
  return false
 var direction: Vector2 = Vector2.RIGHT.rotated(visual_root.rotation)
 if target_valid():
  direction = global_position.direction_to(current_target.global_position)
 if not requested_skill.is_empty(): direction = global_position.direction_to(SkillRequest.point(self,requested_skill))
 var barrier: PrismBarrier = PrismBarrier.new()
 barrier.arena = arena
 barrier.team = team
 barrier.position = global_position + direction * 34.0
 barrier.rotation = direction.angle()
 if ((requested_skill.is_empty() and String(rule.get("skill_cond")) == "reflect_laser") or (requested_skill.get("purpose") == "reflect" and requested_skill.get("aim","auto") != "direction")) and target_valid():
  var closest_diamond: BaseGeoUnit = null
  var closest_distance: float = 380.0
  for friend: BaseGeoUnit in allies():
   var distance: float = global_position.distance_to(friend.global_position)
   if friend.unit_type == "diamond" and distance < closest_distance:
    closest_diamond = friend
    closest_distance = distance
  if is_instance_valid(closest_diamond):
   var incoming: Vector2 = closest_diamond.global_position.direction_to(barrier.position)
   var outgoing: Vector2 = barrier.position.direction_to(current_target.global_position)
   var mirror_normal: Vector2 = incoming - outgoing
   if mirror_normal.length_squared() > 0.01:
    barrier.rotation = mirror_normal.angle()
 arena.add_child(barrier)
 skill_left = skill_cd
 skill_started()
 skill_finished()
 return true
