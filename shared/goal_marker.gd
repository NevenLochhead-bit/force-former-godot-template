@tool
extends Label3D
@export var marker_height = 1.0
var refresh = 0.0
func _process(delta: float) -> void:
 if not Engine.is_editor_hint(): return
 refresh += delta
 if refresh < .3: return
 refresh = 0
 var terrain = get_parent().get_node_or_null("Terrain")
 if terrain == null: return
 var goals = terrain.get_used_cells_by_item(5)
 visible = not goals.is_empty()
 if visible: position = terrain.map_to_local(goals[0])+Vector3(0,marker_height,0)
