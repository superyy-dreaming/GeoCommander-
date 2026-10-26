class_name KeybindManagerService
extends Node

var config_path: String = "user://keybinds.json"
const DEFAULT_BINDINGS: Dictionary = {
 "skill_triangle": KEY_Q,
 "skill_square": KEY_W,
 "skill_circle": KEY_E,
 "skill_diamond": KEY_R,
 "skill_hexagon": KEY_F,
 "squad_hold_orbit": KEY_A,
 "squad_return_ai": KEY_G,
 "spawn_triangle": KEY_1,
 "spawn_square": KEY_2,
 "spawn_circle": KEY_3,
 "spawn_diamond": KEY_4,
 "spawn_hexagon": KEY_5,
 "cmd_emp": KEY_Z,
 "cmd_overclock": KEY_X,
 "cmd_swap": KEY_C,
 "copilot_opt_1": KEY_I,
 "copilot_opt_2": KEY_O,
 "copilot_opt_3": KEY_P,
 "copilot_toggle_auto": KEY_U,
 "toggle_tactical_drawer": KEY_TAB
}

var bindings: Dictionary = {}
var persistence_error: String = ""
var _pressed_frame_by_action: Dictionary = {}

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 bindings = DEFAULT_BINDINGS.duplicate(true)
 _load_bindings()

func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
 if not gameplay_input_allowed(): return
 var key_event: InputEventKey = event as InputEventKey
 var code: int = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
 for action: String in DEFAULT_BINDINGS:
  if int(bindings.get(action)) == code: _pressed_frame_by_action[action] = Engine.get_process_frames()

func _load_bindings() -> void:
 var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
 if file == null:
  return
 var parsed: Variant = JSON.parse_string(file.get_as_text())
 if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
  persistence_error = "按键配置版本无效，已使用默认按键"
  return
 var loaded: Variant = parsed.get("bindings", {})
 if not loaded is Dictionary:
  persistence_error = "按键配置格式无效，已使用默认按键"
  return
 for action: String in DEFAULT_BINDINGS:
  var code: Variant = loaded.get(action, DEFAULT_BINDINGS[action])
  if (code is int or code is float) and int(code) > 0:
   bindings[action] = int(code)
  else:
   persistence_error = "按键配置包含无效按键，已使用默认按键"
   bindings = DEFAULT_BINDINGS.duplicate(true)
   return
 _normalize_conflicts()

func _normalize_conflicts() -> void:
 var requested: Dictionary = bindings.duplicate(true)
 var used_keys: Dictionary = {}
 for action: String in DEFAULT_BINDINGS:
  var code: int = int(requested.get(action, DEFAULT_BINDINGS[action]))
  if used_keys.has(code):
   bindings = DEFAULT_BINDINGS.duplicate(true)
   persistence_error = "按键配置存在冲突，已使用默认按键"
   return
  bindings[action] = code
  used_keys[code] = action

func _save_bindings() -> bool:
 var file: FileAccess = FileAccess.open(config_path, FileAccess.WRITE)
 if file == null:
  persistence_error = "按键已在本次运行生效，但未保存"
  return false
 file.store_string(JSON.stringify({"version": 1, "bindings": bindings}))
 file.close()
 persistence_error = ""
 return true

func get_key_label(action_id: String) -> String:
 var code: int = int(bindings.get(action_id, DEFAULT_BINDINGS.get(action_id, KEY_NONE)))
 return OS.get_keycode_string(code) if code != KEY_NONE else "未设置"

func key_for(action_id: String) -> Key:
 return int(bindings.get(action_id, DEFAULT_BINDINGS.get(action_id, KEY_NONE))) as Key

func is_action_just_pressed(action_id: String) -> bool:
 if not gameplay_input_allowed(): return false
 return int(_pressed_frame_by_action.get(action_id,-1)) == Engine.get_process_frames()

func action_matches(event: InputEventKey, action_id: String) -> bool:
 if event == null or not event.pressed or event.is_echo() or not gameplay_input_allowed():
  return false
 var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
 return code == int(key_for(action_id))

func rebind_action(action_id: String, new_key: Key) -> Dictionary:
 if not DEFAULT_BINDINGS.has(action_id) or new_key == KEY_NONE or new_key == KEY_ESCAPE:
  return {"ok": false, "message": "无效的按键或操作"}
 var swapped: String = ""
 for other: String in DEFAULT_BINDINGS:
  if other != action_id and int(bindings.get(other)) == int(new_key):
   swapped = other
   bindings[other] = int(bindings[action_id])
   break
 bindings[action_id] = int(new_key)
 var saved: bool = _save_bindings()
 if is_instance_valid(SignalBus):
  SignalBus.keybinds_updated.emit(bindings.duplicate(true))
 return {"ok": true, "swapped": swapped, "saved": saved, "message": persistence_error}

func retry_save() -> bool:
 var saved: bool = _save_bindings()
 if is_instance_valid(SignalBus):
  SignalBus.keybinds_updated.emit(bindings.duplicate(true))
 return saved

func reset_to_defaults() -> Dictionary:
 bindings = DEFAULT_BINDINGS.duplicate(true)
 var saved: bool = _save_bindings()
 if is_instance_valid(SignalBus):
  SignalBus.keybinds_updated.emit(bindings.duplicate(true))
 return {"ok": true, "saved": saved, "message": persistence_error}

func gameplay_input_allowed() -> bool:
 var focus: Control = get_viewport().gui_get_focus_owner() if is_instance_valid(get_viewport()) else null
 if not is_instance_valid(focus): return true
 if focus is LineEdit or focus is TextEdit: return false
 return not focus_is_modal()

func focus_is_modal() -> bool:
 var focus: Control = get_viewport().gui_get_focus_owner() if is_instance_valid(get_viewport()) else null
 if not is_instance_valid(focus): return false
 var ancestor: Node = focus
 while is_instance_valid(ancestor):
  if ancestor.is_in_group("gameplay_input_blocker"): return true
  ancestor = ancestor.get_parent()
 return false
