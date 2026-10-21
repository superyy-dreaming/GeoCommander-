extends Node

func _ready() -> void:
 var paths: Array[String] = []
 collect("res://scripts",paths)
 collect("res://tests",paths)
 var failures: int = 0
 for path: String in paths:
  var script: Script = load(path) as Script
  if not is_instance_valid(script) or not script.can_instantiate():
   push_error("Cannot compile " + path)
   failures += 1
 print("SCRIPT_CHECK files=%d failures=%d" % [paths.size(),failures])
 get_tree().quit(0 if failures == 0 else 1)

func collect(directory: String, paths: Array[String]) -> void:
 var access: DirAccess = DirAccess.open(directory)
 for child: String in access.get_directories(): collect(directory + "/" + child,paths)
 for file: String in access.get_files():
  if file.ends_with(".gd"): paths.append(directory + "/" + file)
