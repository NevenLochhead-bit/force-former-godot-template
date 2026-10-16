@tool
extends EditorPlugin
const Shape = preload("shape.gd")
var toolbar: HBoxContainer
var grid: GridMap
var dialog: ConfirmationDialog
var name_field: LineEdit
var collection: OptionButton
var part_list: ItemList
var fields={}
var colour: ColorPickerButton
var solid: CheckBox
var status: Label
var viewport: SubViewport
var model: MeshInstance3D
var camera: Camera3D
var parts: Array=[]
var selected=0
var editing=-1
var updating=false
var view_turn=.65
func _enter_tree() -> void:
 toolbar=HBoxContainer.new()
 var button=Button.new();button.text="Make tile";button.tooltip_text="Build a custom shape and add it to this GridMap's tile palette."
 button.pressed.connect(open_builder);toolbar.add_child(button)
 add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU,toolbar)
 toolbar.hide()
func _exit_tree() -> void:
 remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU,toolbar);toolbar.queue_free()
 if is_instance_valid(dialog):dialog.queue_free()
func _handles(object: Object) -> bool:return object is GridMap
func _edit(object: Object) -> void:grid=object as GridMap
func _make_visible(value: bool) -> void:
 if is_instance_valid(toolbar):toolbar.visible=value
func label(text: String,parent: Node) -> Label:
 var node=Label.new();node.text=text;parent.add_child(node);return node
func action(text: String,parent: Node,callback: Callable) -> Button:
 var node=Button.new();node.text=text;node.pressed.connect(callback);parent.add_child(node);return node
func build_dialog() -> void:
 dialog=ConfirmationDialog.new();dialog.title="Make tile";dialog.size=Vector2i(1000,640)
 dialog.ok_button_text="Add to GridMap";dialog.confirmed.connect(save_tile);dialog.dialog_hide_on_ok=false
 EditorInterface.get_base_control().add_child(dialog)
 var main=VBoxContainer.new();dialog.add_child(main)
 var heading=HBoxContainer.new();main.add_child(heading)
 label("Tile",heading);collection=OptionButton.new();collection.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(collection);collection.item_selected.connect(load_choice)
 var columns=HBoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_child(columns)
 var left=VBoxContainer.new();left.custom_minimum_size.x=180;columns.add_child(left)
 label("Combine shapes",left)
 var row=HBoxContainer.new();left.add_child(row)
 action("+ Box",row,func():add_part("Box"));action("+ Sphere",row,func():add_part("Sphere"))
 row=HBoxContainer.new();left.add_child(row)
 action("+ Cylinder",row,func():add_part("Cylinder"));action("+ Ramp",row,func():add_part("Ramp"))
 part_list=ItemList.new();part_list.custom_minimum_size.y=320;part_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;left.add_child(part_list);part_list.item_selected.connect(select_part)
 action("Remove shape",left,remove_part)
 var centre=VBoxContainer.new();centre.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(centre)
 var container=SubViewportContainer.new();container.stretch=true;container.custom_minimum_size=Vector2(360,440);container.size_flags_vertical=Control.SIZE_EXPAND_FILL;container.size_flags_horizontal=Control.SIZE_EXPAND_FILL;centre.add_child(container)
 viewport=SubViewport.new();viewport.size=Vector2i(440,440);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
 var world=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("303437");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.55;world.environment=env;viewport.add_child(world)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);sun.light_energy=1.2;viewport.add_child(sun)
 model=MeshInstance3D.new();viewport.add_child(model)
 var floor_mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(32,32);floor_mesh.mesh=plane;floor_mesh.position.y=-.02
 var floor_mat=StandardMaterial3D.new();floor_mat.albedo_color=Color("555b5d");floor_mesh.material_override=floor_mat;viewport.add_child(floor_mesh)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;viewport.add_child(camera)
 row=HBoxContainer.new();centre.add_child(row)
 action("Turn left",row,func():view_turn-=PI/8;refresh_preview());action("Turn right",row,func():view_turn+=PI/8;refresh_preview())
 var right=VBoxContainer.new();right.custom_minimum_size.x=270;columns.add_child(right)
 label("Name",right);name_field=LineEdit.new();name_field.placeholder_text="My tile";right.add_child(name_field)
 for group in ["Size","Position"]:
  label(group+" · metres",right)
  row=HBoxContainer.new();right.add_child(row)
  for axis in ["X","Y","Z"]:
   var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(column);label(axis,column)
   var spin=SpinBox.new();spin.min_value=.05 if group=="Size" else -24;spin.max_value=24;spin.step=.05;spin.custom_minimum_size.x=80;column.add_child(spin)
   fields[group+axis]=spin;spin.value_changed.connect(func(_value):write_part())
 label("Turn · degrees",right);var turn=SpinBox.new();turn.min_value=-360;turn.max_value=360;turn.step=15;right.add_child(turn);fields.Turn=turn;turn.value_changed.connect(func(_value):write_part())
 label("Colour",right);colour=ColorPickerButton.new();colour.custom_minimum_size.y=32;colour.edit_alpha=false;right.add_child(colour);colour.color_changed.connect(func(_value):refresh_preview())
 solid=CheckBox.new();solid.text="Solid · Wheel collides with it";solid.button_pressed=true;right.add_child(solid)
 var help=label("One grid cell is 1 metre wide.\nY = 0 is the floor.\nLarger shapes can span several cells.",right);help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.custom_minimum_size.x=270
 status=label("",main);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func open_builder() -> void:
 if not is_instance_valid(grid) or grid.mesh_library==null:return
 if not is_instance_valid(dialog):build_dialog()
 collection.clear();collection.add_item("New tile");collection.set_item_metadata(0,-1)
 var saved=grid.mesh_library.get_meta("custom_shapes",{})
 for id in saved:
  collection.add_item(grid.mesh_library.get_item_name(int(id)),int(id));collection.set_item_metadata(collection.item_count-1,int(id))
 load_choice(0);dialog.popup_centered(Vector2i(Vector2(1100,680)*EditorInterface.get_editor_scale()))
func load_choice(index: int) -> void:
 editing=int(collection.get_item_metadata(index))
 if editing<0:
  parts=[];name_field.text="";colour.color=Color("b4bca9");solid.button_pressed=true;add_part("Box")
 else:
  var saved=grid.mesh_library.get_meta("custom_shapes",{})[str(editing)]
  parts=saved.parts.duplicate(true);name_field.text=grid.mesh_library.get_item_name(editing);colour.color=Color(saved.colour);solid.button_pressed=saved.solid;selected=0;refresh_list();read_part()
 dialog.ok_button_text="Add to GridMap" if editing<0 else "Update tile"
 status.text="";refresh_preview()
func add_part(kind: String) -> void:
 parts.append({"kind":kind,"size":[1.0,1.0,1.0],"position":[0.0,.5,0.0],"turn":0.0})
 selected=parts.size()-1;refresh_list();read_part();refresh_preview()
func remove_part() -> void:
 if parts.size()<2:return
 parts.remove_at(selected);selected=mini(selected,parts.size()-1);refresh_list();read_part();refresh_preview()
func select_part(index: int) -> void:selected=index;read_part()
func refresh_list() -> void:
 part_list.clear()
 for i in parts.size():part_list.add_item(str(i+1)+" · "+parts[i].kind)
 part_list.select(selected)
func read_part() -> void:
 updating=true
 for i in 3:
  var axis=["X","Y","Z"][i]
  fields["Size"+axis].value=parts[selected].size[i];fields["Position"+axis].value=parts[selected].position[i]
 fields.Turn.value=parts[selected].turn;updating=false
func write_part() -> void:
 if updating or parts.is_empty():return
 for i in 3:
  var axis=["X","Y","Z"][i]
  parts[selected].size[i]=fields["Size"+axis].value;parts[selected].position[i]=fields["Position"+axis].value
 parts[selected].turn=fields.Turn.value;refresh_preview()
func refresh_preview() -> void:
 if parts.is_empty() or not is_instance_valid(model):return
 model.mesh=Shape.mesh(parts,colour.color)
 var bounds=model.mesh.get_aabb();var centre=bounds.get_center();var span=maxf(1.5,bounds.size.length())
 camera.size=span*1.25;camera.position=centre+Vector3(cos(view_turn),.8,sin(view_turn))*span*2;camera.look_at(centre)
func save_tile() -> void:
 if not is_instance_valid(grid):status.text="Select your GridMap and open Make tile again.";return
 var tile_name=name_field.text.strip_edges()
 if tile_name.is_empty():status.text="Give your tile a name first.";return
 var library=grid.mesh_library
 var duplicate=library.find_item_by_name(tile_name)
 if duplicate>=0 and duplicate!=editing:status.text="That name is already in the palette. Choose a different name.";return
 var path=library.resource_path
 if not path.begins_with("res://") or not path.ends_with(".tres"):status.text="This GridMap needs a saved MeshLibrary (.tres).";return
 var updated=library.duplicate(true)
 var id=editing if editing>=0 else maxi(11,updated.get_last_unused_item_id())
 if editing<0:updated.create_item(id)
 updated.set_item_name(id,tile_name);updated.set_item_mesh(id,Shape.mesh(parts,colour.color));updated.set_item_mesh_transform(id,Transform3D.IDENTITY)
 updated.set_item_shapes(id,Shape.shapes(parts) if solid.button_pressed else [])
 var saved=updated.get_meta("custom_shapes",{}).duplicate(true)
 saved[str(id)]={"parts":parts.duplicate(true),"colour":colour.color.to_html(false),"solid":solid.button_pressed};updated.set_meta("custom_shapes",saved)
 var error=ResourceSaver.save(updated,path)
 if error!=OK:status.text="The tile could not be saved: "+error_string(error);return
 # Keep both Terrain and Things on the same library, including scenes opened later.
 updated.take_over_path(path)
 var root=EditorInterface.get_edited_scene_root()
 for node in root.find_children("*","GridMap",true,false):
  if node.mesh_library==library:node.mesh_library=updated
 EditorInterface.mark_scene_as_unsaved()
 EditorInterface.get_resource_filesystem().scan_sources()
 dialog.call_deferred("hide")
