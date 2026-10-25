class_name MainMenu
extends Control

var ui: Control
var pages: Dictionary = {}
var page: String = "home"
var map_preview: MapPreview
var home_preview: MapPreview
var map_title: Label
var map_description: Label
var map_buttons: Dictionary = {}
var feedback: Label
var launch_button: Button
var fade: ColorRect
var transitioning: bool = false
var background: ShaderMaterial
var settings: SettingsPanel

func _ready() -> void:
 GameSettings.apply_content_scale()
 var world: Node2D = Node2D.new()
 add_child(world)
 background = CombatContext.create_environment(world,Rect2(0,0,3200,2150))
 var layer: CanvasLayer = CanvasLayer.new()
 layer.layer = 10
 add_child(layer)
 ui = Control.new()
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.theme = CommanderTheme.create()
 layer.add_child(ui)
 build_home()
 build_single()
 build_multiplayer()
 feedback = text_label("",16)
 feedback.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 feedback.offset_left = 32
 feedback.offset_right = -32
 feedback.offset_top = -30
 ui.add_child(feedback)
 fade = ColorRect.new()
 fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fade.color = Color(0.005,0.012,0.02,0)
 fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 ui.add_child(fade)
 GameSettings.settings_changed.connect(settings_updated)
 settings_updated()
 select_map(MatchSession.selected_map_id)
 show_page(MatchSession.menu_page)
 if not GameSettings.status.is_empty(): feedback.text = GameSettings.status

func text_label(text: String, base: int = 18, tint: Color = CommanderTheme.TEXT) -> Label:
 var label: Label = Label.new()
 label.text = text
 CommanderTheme.font(label,base)
 label.add_theme_color_override("font_color",tint)
 return label

func button(text: String, action: Callable) -> Button:
 var node: Button = Button.new()
 node.text = text
 node.custom_minimum_size.y = 52
 node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 node.pressed.connect(action)
 return node

func page_column(id: String) -> VBoxContainer:
 var margin: MarginContainer = MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,32 if edge != "bottom" else 44)
 ui.add_child(margin)
 pages[id] = margin
 var column: VBoxContainer = VBoxContainer.new()
 column.add_theme_constant_override("separation",20)
 margin.add_child(column)
 return column

func build_home() -> void:
 var column: VBoxContainer = page_column("home")
 var header: HBoxContainer = HBoxContainer.new()
 column.add_child(header)
 var title: Label = text_label("GeoCommander",36)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(title)
 header.add_child(text_label("几何最高指挥官",20,CommanderTheme.MUTED))
 var body: HBoxContainer = HBoxContainer.new()
 body.add_theme_constant_override("separation",48)
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(body)
 var navigation: VBoxContainer = VBoxContainer.new()
 navigation.custom_minimum_size.x = 330
 navigation.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 navigation.add_theme_constant_override("separation",16)
 body.add_child(navigation)
 var heading: Label = text_label("你的部署，\n决定战局。",32)
 navigation.add_child(heading)
 var intro: Label = text_label("部署五种几何兵种，编写战术指令，争夺能源并摧毁敌方核心。",18,CommanderTheme.MUTED)
 intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 intro.custom_minimum_size.x = 330
 navigation.add_child(intro)
 for name: String in ["单人游戏","多人游戏","设置"]:
  var action: Callable = open_settings if name == "设置" else func() -> void: show_page("single" if name == "单人游戏" else "multiplayer")
  var entry: Button = button(name,action)
  CommanderTheme.font(entry,24)
  entry.custom_minimum_size.y = 62
  navigation.add_child(entry)
 var training: Button = button("兵种演练",open_academy)
 training.tooltip_text = "查看五兵种档案，体验真实普攻与技能"
 navigation.add_child(training)
 var right: VBoxContainer = VBoxContainer.new()
 right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body.add_child(right)
 home_preview = MapPreview.new()
 home_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
 right.add_child(home_preview)
 var note: Label = text_label("六张战场，六种推进思路。选择地图后，在战前矩阵中配置你的开局。",18,CommanderTheme.MUTED)
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 right.add_child(note)

func build_single() -> void:
 var column: VBoxContainer = page_column("single")
 column.add_child(text_label("单人游戏 · 选择战场",30))
 var body: HBoxContainer = HBoxContainer.new()
 body.add_theme_constant_override("separation",24)
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(body)
 var list_scroll: ScrollContainer=ScrollContainer.new()
 list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 list_scroll.custom_minimum_size.x=300
 body.add_child(list_scroll)
 var list: VBoxContainer = VBoxContainer.new()
 list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 list.add_theme_constant_override("separation",16)
 list_scroll.add_child(list)
 for id: String in MapCatalog.IDS:
  var data: Dictionary = MapCatalog.definition(id)
  var choice: Button = button(data["title"],func() -> void: select_map(id))
  CommanderTheme.font(choice,24)
  choice.toggle_mode = true
  choice.custom_minimum_size.y = 84
  list.add_child(choice)
  map_buttons[id] = choice
 var rules: Label = text_label("全部地图已解锁\n\n相同兵种与经济\n对局最长十分钟\n摧毁敌方核心获胜",18,CommanderTheme.MUTED)
 rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 list.add_child(rules)
 var right: VBoxContainer = VBoxContainer.new()
 right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body.add_child(right)
 map_title = text_label("",24)
 right.add_child(map_title)
 map_description = text_label("",18,CommanderTheme.MUTED)
 map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 map_preview = MapPreview.new()
 map_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
 right.add_child(map_preview)
 var detail_scroll: ScrollContainer=ScrollContainer.new()
 detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 detail_scroll.size_flags_stretch_ratio=0.45
 right.add_child(detail_scroll)
 var details: VBoxContainer=VBoxContainer.new()
 details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 details.add_theme_constant_override("separation",16)
 detail_scroll.add_child(details)
 details.add_child(map_description)
 details.add_child(MapLegend.new())
 var footer: HBoxContainer = HBoxContainer.new()
 column.add_child(footer)
 footer.add_child(button("返回首页",func() -> void: show_page("home")))
 var spacer: Control = Control.new()
 spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 footer.add_child(spacer)
 launch_button = button("进入战前准备",launch_battle)
 launch_button.custom_minimum_size.x = 300
 footer.add_child(launch_button)

func build_multiplayer() -> void:
 var column: VBoxContainer = page_column("multiplayer")
 column.add_child(text_label("多人游戏",30))
 var panel: VBoxContainer = VBoxContainer.new()
 panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
 panel.alignment = BoxContainer.ALIGNMENT_CENTER
 column.add_child(panel)
 panel.add_child(text_label("开发中",32,ProceduralGeo.GOLD))
 panel.add_child(text_label("多人对战尚未开放。当前版本可体验单人战场和兵种演练。",18,CommanderTheme.MUTED))
 for title: String in ["创建房间","加入房间"]:
  var entry: Button = button(title,func() -> void: pass)
  entry.disabled = true
  entry.tooltip_text = "多人功能开发中"
  panel.add_child(entry)
 column.add_child(button("返回首页",func() -> void: show_page("home")))

func show_page(id: String) -> void:
 if transitioning or is_instance_valid(settings): return
 page = id if pages.has(id) else "home"
 MatchSession.menu_page = page
 for key: String in pages: (pages[key] as Control).visible = key == page
 var focusables: Array[Control] = []
 collect_buttons(pages[page],focusables)
 if not focusables.is_empty(): focusables[0].grab_focus()

func collect_buttons(node: Node, found: Array[Control]) -> void:
 if node is Button and not (node as Button).disabled: found.append(node as Control)
 for child: Node in node.get_children(): collect_buttons(child,found)

func select_map(id: String) -> void:
 MatchSession.selected_map_id = id
 var data: Dictionary = MapCatalog.definition(id)
 map_title.text = data["title"]
 map_description.text = data["description"]
 map_preview.map_id = id
 home_preview.map_id = id
 for key: String in map_buttons: (map_buttons[key] as Button).button_pressed = key == id

func open_settings() -> void:
 if is_instance_valid(settings) or transitioning: return
 settings = SettingsPanel.new()
 add_child(settings)
 settings.open_panel()

func settings_updated() -> void:
 CommanderTheme.refresh(ui)
 background.set_shader_parameter("reduced_motion",bool(GameSettings.values["reduced_motion"]))

func launch_battle() -> void:
 MatchSession.request_match(MatchSession.selected_map_id)
 switch_scene("res://scenes/main_arena.tscn")

func open_academy() -> void:
 MatchSession.menu_page = "home"
 switch_scene("res://scenes/unit_academy.tscn")

func switch_scene(path: String) -> void:
 if transitioning: return
 transitioning = true
 fade.mouse_filter = Control.MOUSE_FILTER_STOP
 var tween: Tween = create_tween()
 tween.tween_property(fade,"color:a",1.0,0.0 if bool(GameSettings.values["reduced_motion"]) else 0.18)
 await tween.finished
 var error: Error = get_tree().change_scene_to_file(path)
 if error != OK:
  MatchSession.pending_map_id = ""
  feedback.text = "页面载入失败："+error_string(error)+"。请重试。"
  transitioning = false
  fade.color.a = 0
  fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE and page != "home":
  show_page("home")
  get_viewport().set_input_as_handled()
