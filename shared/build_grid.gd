@tool
extends GridMap
@export var keep_tiles_upright = true
var inspection_age = 0.0
func _process(delta: float) -> void:
 if not Engine.is_editor_hint() or not keep_tiles_upright: return
 inspection_age += delta
 if inspection_age < .2: return
 inspection_age = 0
 straighten_tiles()
func upright_index(original: Basis) -> int:
 var best = 0
 var score = -INF
 for turn in range(4):
  var candidate = Basis(Vector3.UP,turn*PI/2)
  var agreement = candidate.x.dot(original.x)+candidate.z.dot(original.z)
  if agreement > score:
   score = agreement
   best = get_orthogonal_index_from_basis(candidate)
 return best
func straighten_tiles() -> int:
 var changed = 0
 for cell in get_used_cells():
  var index = get_cell_item_orientation(cell)
  var original = get_basis_with_orthogonal_index(index)
  if original.y.dot(Vector3.UP) > .99: continue
  set_cell_item(cell,get_cell_item(cell),upright_index(original))
  changed += 1
 return changed
