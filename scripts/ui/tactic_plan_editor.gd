class_name TacticPlanEditor
extends VBoxContainer

signal edited(program: Dictionary)
signal step_selected(id: String)
var program: Dictionary = {}
var kind: String = "triangle"
var map_id: String = "balanced"
var selected: int = 0
var updating: bool = false
var history: Array[Dictionary] = []
var future: Array[Dictionary] = []
var picker: OptionButton
var form: VBoxContainer
var notice: Label
var fields: Dictionary = {}

func _ready() -> void:
 picker = OptionButton.new()
 picker.fit_to_longest_item = false
 picker.custom_minimum_size.y = 44
 picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 add_child(picker)
 picker.item_selected.connect(func(index: int) -> void:
  selected = index
  render()
  step_selected.emit(str(program["plan"]["steps"][selected]["id"])))
 var scroll: ScrollContainer = ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus = true
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 add_child(scroll)
 var contents: VBoxContainer = VBoxContainer.new()
 contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(contents)
 var operations: MenuButton = MenuButton.new()
 operations.text="步骤操作…"
 operations.flat=false
 operations.custom_minimum_size.y=44
 contents.add_child(operations)
 var items: Array[String]=["添加","删除","上移","下移","撤销","重做","新建v2","示例方案"]
 for title: String in items: operations.get_popup().add_item(title)
 operations.get_popup().id_pressed.connect(func(index: int) -> void:
  match items[index]:
   "新建v2": change(TacticPlan.default_program(kind))
   "示例方案": change(TacticExamples.for_unit(kind))
   "撤销": undo()
   "重做": redo()
   _: operate(items[index])
 )
 notice = Label.new()
 notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 CommanderTheme.font(notice,14)
 contents.add_child(notice)
 form = VBoxContainer.new()
 form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 contents.add_child(form)
 contents.add_child(btn("应用步骤修改",commit_form))
 render()

func btn(title: String, action: Callable) -> Button:
 var node: Button = Button.new()
 node.text = title
 node.custom_minimum_size.y = 44
 node.pressed.connect(action)
 return node

func set_program(value: Dictionary) -> void:
 program = value.duplicate(true)
 if is_node_ready(): render()

func change(value: Dictionary) -> void:
 history.append(program.duplicate(true))
 if history.size()>40: history.pop_front()
 future.clear()
 program = value.duplicate(true)
 render()
 edited.emit(program)

func undo() -> void:
 if history.is_empty(): return
 future.append(program.duplicate(true))
 program = history.pop_back()
 render()
 edited.emit(program)

func redo() -> void:
 if future.is_empty(): return
 history.append(program.duplicate(true))
 program = future.pop_back()
 render()
 edited.emit(program)

func valid_v2() -> bool:
 return int(program.get("version",1))==2 and program.has("plan")

func operate(action: String) -> void:
 if not valid_v2(): return
 var value: Dictionary = program.duplicate(true)
 var steps: Array = value["plan"]["steps"]
 match action:
  "添加":
   if steps.size()>=24: return
   var id: String = "step_%d" % (steps.size()+1)
   while steps.any(func(s: Dictionary) -> bool: return s["id"]==id): id+="_new"
   steps.append(TacticPlan.step(id))
   selected = steps.size()-1
  "删除":
   if steps.size()<=1: return
   var id: String = steps[selected]["id"]
   steps.remove_at(selected)
   for entry: Dictionary in steps:
    for key: String in ["next","on_failure"]:
     if entry.get(key)==id: entry[key]="end" if key=="next" else "stop"
   value["plan"]["interrupts"] = value["plan"].get("interrupts",[]).filter(func(i: Dictionary) -> bool: return i["goto"]!=id)
   if value["plan"]["entry"]==id: value["plan"]["entry"]=steps[0]["id"]
   selected = mini(selected,steps.size()-1)
  "上移","下移":
   var index: int = selected+(-1 if action=="上移" else 1)
   if index<0 or index>=steps.size(): return
   var entry: Dictionary = steps[selected]
   steps[selected] = steps[index]
   steps[index] = entry
   selected = index
 change(value)

func caption(text: String) -> void:
 var label: Label = Label.new()
 label.text = text
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 CommanderTheme.font(label,14)
 form.add_child(label)

func line(key: String, title: String, value: String) -> void:
 caption(title)
 var input: LineEdit = LineEdit.new()
 input.text = value
 input.custom_minimum_size.y = 44
 form.add_child(input)
 fields[key] = input

func choice(key: String, title: String, values: Array, value: String) -> void:
 caption(title)
 var input: OptionButton = OptionButton.new()
 input.fit_to_longest_item = false
 var translations: Dictionary={"target":{"current":"沿用当前目标","nearest":"最近敌军","diamond":"敌方菱形","hexagon":"敌方六边形","lowest_hp":"最低生命敌军","base":"敌方基地","none":"不选择目标"},"skill":{"hold":"保留技能","auto":"允许自动施放","travel":"允许赶路冲刺"},"direction":{"up":"向上","down":"向下","left":"向左","right":"向右","up_left":"左上","up_right":"右上","down_left":"左下","down_right":"右下","forward":"向敌方基地","backward":"向己方基地","angle":"指定角度"},"finish":{"hold":"原地待命","base":"转用基础战术","repeat":"重复入口"},"attack":{"false":"关闭","true":"开启"}}
 for item: String in values:
  var text: String=TacticPlan.ACTION_TITLES[TacticPlan.ACTIONS.find(item)] if key=="action" else str(translations.get(key,{}).get(item,item))
  input.add_item(text)
  input.set_item_metadata(input.item_count-1,item)
 input.select(maxi(0,values.find(value)))
 input.custom_minimum_size.y = 44
 form.add_child(input)
 fields[key] = input

func json_field(key: String, title: String, value: Variant) -> void:
 caption(title)
 var input: TextEdit = TextEdit.new()
 input.text = "" if value == null else JSON.stringify(value,"  ")
 input.custom_minimum_size.y = 110
 input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 CommanderTheme.font(input,14)
 form.add_child(input)
 fields[key] = input

func render() -> void:
 if not is_instance_valid(form): return
 for child: Node in form.get_children():
  form.remove_child(child)
  child.queue_free()
 fields.clear()
 picker.clear()
 if not valid_v2():
  notice.show()
  notice.text = "当前为旧版或空方案。可保留旧版运行，或点击新建v2/示例方案开始编排。无效JSON请先在JSON页修正。"
  return
 var plan: Dictionary = program["plan"]
 var steps: Array = plan["steps"]
 selected = clampi(selected,0,steps.size()-1)
 for entry: Dictionary in steps: picker.add_item(str(entry["id"])+" · "+str(entry.get("label",entry["action"])))
 picker.select(selected)
 var step: Dictionary = steps[selected]
 line("id","步骤标识",step["id"])
 line("label","说明名称",step.get("label",""))
 choice("action","动作",TacticPlan.ACTIONS,step["action"])
 if not (step["action"]=="wait" and step.has("when")): line("seconds","持续秒数（方向移动/等待）",str(step.get("seconds",1)))
 line("timeout","最长等待秒数",str(step.get("timeout",20)))
 choice("target","进入步骤时选择目标",TacticPlan.TARGETS,step.get("target","current"))
 choice("attack","允许原地普攻（不追敌）",["false","true"],str(step.get("attack",false)))
 choice("skill","自动技能策略",["hold","auto","travel"],step.get("skill","hold"))
 choice("direction","地图方向，前后按基地",TacticPlan.DIRECTIONS.keys()+["forward","backward","angle"],step.get("direction","up"))
 line("angle","角度（0向右，90向下）",str(step.get("angle",0)))
 var ids: Array = steps.map(func(s: Dictionary) -> String: return s["id"])
 choice("next","成功跳转",ids+["end","return"],step.get("next","end"))
 choice("on_failure","失败/超时跳转",ids+["stop","end","return"],step.get("on_failure","stop"))
 choice("entry","方案入口",ids,plan["entry"])
 choice("finish","主流程结束行为",["hold","base","repeat"],plan.get("finish","hold"))
 choice("map_id","绑定地图（航点/障碍物必须绑定）",[""]+MapCatalog.IDS,plan.get("map_id",""))
 line("obstacle","指定墙体标识（可在地图选择）",step.get("obstacle",""))
 json_field("goal","目的地：如 {\"anchor\":\"rear\",\"distance\":190}",step.get("goal"))
 json_field("path","路径[x,y]数组，也可在地图编辑",step.get("path"))
 json_field("when","完成条件：{fact,op,value} 或 all/any/not",step.get("when"))
 json_field("skill_request","技能瞄准与用途（施放技能步骤）",step.get("skill_request"))
 json_field("interrupts","优先级中断数组：{id,when,goto}",plan.get("interrupts",[]))
 form.add_child(btn("在地图编辑此步骤",func() -> void: step_selected.emit(step["id"])))
 notice.text = ""
 notice.hide()

func commit_form() -> void:
 if not valid_v2(): return
 notice.show()
 var value: Dictionary = program.duplicate(true)
 var entry: Dictionary = value["plan"]["steps"][selected]
 var old_id: String = entry["id"]
 for key: String in ["id","label","obstacle"]: entry[key]=(fields[key] as LineEdit).text.strip_edges()
 for key: String in ["seconds","timeout","angle"]:
  if not fields.has(key):
   entry.erase(key)
   continue
  var text: String = (fields[key] as LineEdit).text
  if not text.is_valid_float():
   notice.text = key+"需要数字，尚未修改方案"
   return
  entry[key]=float(text)
 for key: String in ["action","target","skill","direction","next","on_failure"]:
  var option: OptionButton = fields[key]
  entry[key]=option.get_item_metadata(option.selected)
 var attack: OptionButton = fields["attack"]
 entry["attack"] = attack.get_item_metadata(attack.selected)=="true"
 for key: String in ["entry","finish","map_id"]:
  var option: OptionButton = fields[key]
  value["plan"][key]=option.get_item_metadata(option.selected)
 for key: String in ["goal","path","when","skill_request","interrupts"]:
  var text: String = (fields[key] as TextEdit).text.strip_edges()
  if text.is_empty():
   if key!="interrupts": entry.erase(key)
   continue
  var parser: JSON = JSON.new()
  if parser.parse(text)!=OK:
   notice.text = key+"："+parser.get_error_message()
   return
  if key=="interrupts": value["plan"][key]=parser.data
  else: entry[key]=parser.data
 if entry["id"] != old_id:
  if value["plan"]["entry"]==old_id: value["plan"]["entry"]=entry["id"]
  for other: Dictionary in value["plan"]["steps"]:
   for key: String in ["next","on_failure"]:
    if other.get(key)==old_id: other[key]=entry["id"]
  if value["plan"]["interrupts"] is Array:
   for interrupt: Variant in value["plan"]["interrupts"]:
    if interrupt is Dictionary and interrupt.get("goto")==old_id: interrupt["goto"]=entry["id"]
 var result: Dictionary = UnitTacticProgram.validate(value,kind)
 if not result["ok"]:
  notice.text=result["message"]+"；表单修改保留，请修正后应用。"
  return
 change(result["program"])

func edit_path(id: String, points: Array, obstacle: String = "") -> void:
 if not valid_v2(): return
 notice.show()
 var value: Dictionary = program.duplicate(true)
 value["plan"]["map_id"] = map_id
 for entry: Dictionary in value["plan"]["steps"]:
  if entry["id"]!=id: continue
  if not obstacle.is_empty():
   entry["action"] = "seek_cover"
   entry["obstacle"] = obstacle
  else:
   entry["action"] = "follow_path"
   if points.is_empty():
    notice.text="路径至少保留一个航点；使用删除步骤移除整个动作。"
    return
   entry["path"] = points
 var result: Dictionary = UnitTacticProgram.validate(value,kind)
 if result["ok"]: change(result["program"])
 else: notice.text=result["message"]
