class_name CombatContext
extends Node2D

signal unit_added(unit: BaseGeoUnit)
signal unit_removed(unit: BaseGeoUnit)
signal profile_changed(team: int, profile: Dictionary)
signal gravity_triggered(team: int, center: Vector2, radius: float)
signal base_damage_reported(base: CoreMatrixBase, amount: float, attacker: Node2D)
signal healing_reported(unit: BaseGeoUnit, amount: float)
signal skill_reported(unit: BaseGeoUnit)
signal actual_damage_reported(unit: BaseGeoUnit, amount: float, attacker: Node2D)
signal damage_reported(unit: BaseGeoUnit, amount: float, attacker: Node2D)

var reduced_motion: bool = false
var local_units: Array[BaseGeoUnit] = []
var reflectors: Array[LaserReflector] = []
var local_bases: Array[CoreMatrixBase] = []
var local_prisms: Array[EnergyPrism] = []
var navigation: ArenaObstacles
var local_profiles: Array[Dictionary] = []
var active: bool = true
var tactic_decisions: int = 0
var tactic_usec: int = 0

func is_combat_active() -> bool:
 return active

func profile_for(team: int) -> Dictionary:
 if local_profiles.is_empty():
  local_profiles = [TacticalBrain.get_default_profile(),TacticalBrain.get_default_profile()]
 return local_profiles[team]

func register_unit(unit: BaseGeoUnit) -> void:
 local_units.append(unit)
 unit_added.emit(unit)

func unregister_unit(unit: BaseGeoUnit) -> void:
 local_units.erase(unit)
 if is_instance_valid(navigation): navigation.routes.erase(unit.get_instance_id())
 unit_removed.emit(unit)

func units_for(team: int) -> Array[BaseGeoUnit]:
 var result: Array[BaseGeoUnit] = []
 for unit: BaseGeoUnit in local_units:
  if is_instance_valid(unit) and not unit.dead and unit.team == team:
   result.append(unit)
 return result

func base_for(team: int) -> CoreMatrixBase:
 for base: CoreMatrixBase in local_bases:
  if is_instance_valid(base) and base.team == team:
   return base
 return null

func objective_for(unit: BaseGeoUnit) -> Vector2:
 return unit.global_position

func formation_anchor(unit: BaseGeoUnit) -> Vector2:
 return unit.global_position

func routed_direction(unit: BaseGeoUnit, goal: Vector2, intent: String = "objective") -> Vector2:
 if is_instance_valid(navigation):
  return navigation.direction_for(unit,goal,intent)
 return unit.global_position.direction_to(goal)

func friendly_shield_rids(team: int) -> Array[RID]:
 var result: Array[RID] = []
 for reflector: LaserReflector in reflectors:
  if is_instance_valid(reflector) and reflector is PrismBarrier and reflector.team == team:
   result.append(reflector.get_rid())
 return result

static func create_environment(parent: Node, bounds: Rect2) -> ShaderMaterial:
 var world: WorldEnvironment = WorldEnvironment.new()
 var environment: Environment = Environment.new()
 environment.background_mode = Environment.BG_CANVAS
 environment.background_canvas_max_layer = 0
 environment.glow_enabled = true
 environment.glow_intensity = 0.9
 environment.glow_strength = 1.1
 environment.glow_bloom = 0.15
 environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
 environment.glow_hdr_threshold = 1.0
 world.environment = environment
 GameSettings.track_environment(world)
 parent.add_child(world)
 var background: ColorRect = ColorRect.new()
 background.position = bounds.position
 background.size = bounds.size
 background.z_index = -20
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var material: ShaderMaterial = ShaderMaterial.new()
 material.shader = load("res://shaders/tactical_grid.gdshader") as Shader
 material.set_shader_parameter("world_size",bounds.size)
 material.set_shader_parameter("world_origin",bounds.position)
 background.material = material
 parent.add_child(background)
 return material

func capture_objective(unit: BaseGeoUnit) -> Vector2:
 var direction: float = 1 if unit.team == 0 else -1
 if not local_prisms.is_empty():
  var preferred: int = unit.spawn_index % local_prisms.size()
  for offset: int in range(local_prisms.size()):
   var prism: EnergyPrism = local_prisms[(preferred+offset)%local_prisms.size()]
   if prism.capture_owner != unit.team: return prism.global_position+Vector2(-direction*25,0)
 var base: CoreMatrixBase = base_for(1-unit.team)
 return base.global_position if is_instance_valid(base) else unit.global_position
