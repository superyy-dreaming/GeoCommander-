class_name ReadoutText
extends RefCounted

static func update(control: TextEdit, value: String) -> void:
 if control.text == value: return
 var vertical: float = control.scroll_vertical
 var horizontal: int = control.scroll_horizontal
 var line: int = control.get_caret_line()
 var column: int = control.get_caret_column()
 var selection: PackedInt32Array = []
 if control.has_selection(): selection = PackedInt32Array([control.get_selection_from_line(),control.get_selection_from_column(),control.get_selection_to_line(),control.get_selection_to_column()])
 control.text = value
 control.set_caret_line(mini(line,control.get_line_count()-1),false)
 control.set_caret_column(mini(column,control.get_line(control.get_caret_line()).length()),false)
 if selection.size() == 4 and selection[2] < control.get_line_count(): control.select(selection[0],selection[1],selection[2],selection[3])
 control.scroll_vertical = vertical
 control.scroll_horizontal = horizontal
