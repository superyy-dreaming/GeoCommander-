class_name TerrainObject
extends Node2D

var spec: Dictionary = {}
var runtime: TerrainRuntime
var collision: StaticBody2D
var shape: CollisionPolygon2D
var closed: bool = true
var status: String = ""
var blocked_reason: String = ""
var status_font: Font

func _ready() -> void:
 status_font = CommanderTheme.create().default_font
 position = spec["position"]
 rotation = spec["angle"]
 set_meta("obstacle_id",spec["id"])
 if spec["kind"]=="gate":
  collision = StaticBody2D.new()
  collision.collision_layer = 16
  collision.collision_mask = 3
  add_child(collision)
  shape = CollisionPolygon2D.new()
  shape.polygon = polygon()
  collision.add_child(shape)
  status = "闭合"

func polygon() -> PackedVector2Array:
 return PackedVector2Array([Vector2(-75,-9),Vector2(75,-9),Vector2(75,9),Vector2(-75,9)])

func set_closed(value: bool) -> void:
 if closed == value: return
 closed = value
 shape.set_deferred("disabled",not value)
 runtime.topology_changed()

func _draw() -> void:
 var age: float = runtime.clock if not runtime.arena.reduced_motion else 0.0
 var ratio: float = 1.0
 if spec["kind"]=="gate": ratio = (20.0-fmod(runtime.clock,35.0))/20.0 if fmod(runtime.clock,35.0)<20 else (35.0-fmod(runtime.clock,35.0))/15.0
 if spec["kind"]=="reactor": ratio = fmod(runtime.clock,55.0)/55.0
 TerrainArt.mechanism(self,spec["kind"],age,status,ratio)
 if spec["kind"] in ["gate","portal","reactor"]:
  draw_set_transform(Vector2.ZERO,-rotation)
  var text: String = status if blocked_reason.is_empty() else blocked_reason
  draw_string(status_font,Vector2(-75,-38),text,HORIZONTAL_ALIGNMENT_LEFT,200,13,Color(0.9,0.9,0.8))
