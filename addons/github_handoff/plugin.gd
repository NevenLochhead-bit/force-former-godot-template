@tool
extends EditorPlugin

var button: Button
var panel: AcceptDialog
var status: Label

func _enter_tree() -> void:
 button=Button.new()
 button.text="Save for GitHub"
 button.tooltip_text="Save scenes, then commit and push the complete project in GitHub Desktop."
 button.pressed.connect(open_handoff)
 add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,button)
 panel=AcceptDialog.new()
 panel.title="Save your project to GitHub"
 panel.ok_button_text="Done"
 var scale=EditorInterface.get_editor_scale()
 panel.min_size=Vector2i(int(740*scale),int(480*scale))
 EditorInterface.get_base_control().add_child(panel)
 var box=VBoxContainer.new()
 box.custom_minimum_size=Vector2(700*scale,0)
 box.add_theme_constant_override("separation",16)
 panel.add_child(box)
 var intro=Label.new()
 intro.text="Your complete Godot project is the submission.\nTerrain, sounds, Condition.json and Inspector settings stay together."
 box.add_child(intro)
 status=Label.new()
 box.add_child(status)
 var folder=LineEdit.new()
 folder.text=ProjectSettings.globalize_path("res://")
 folder.editable=false
 folder.tooltip_text="Use this exact folder in GitHub Desktop."
 box.add_child(folder)
 var steps=Label.new()
 steps.text="1. Open this project's repository in GitHub Desktop.\n2. Review your changes and write a short summary.\n3. Commit, then Push origin.\n4. Post the repository link to Condition Artefacts.\n\nSave any script edits before committing."
 box.add_child(steps)
 var actions=HBoxContainer.new()
 actions.add_theme_constant_override("separation",12)
 box.add_child(actions)
 var show_folder=Button.new()
 show_folder.text="Open project folder"
 show_folder.pressed.connect(func():OS.shell_open(ProjectSettings.globalize_path("res://")))
 actions.add_child(show_folder)
 var guide=Button.new()
 guide.text="Course Guide"
 guide.pressed.connect(func():OS.shell_open("https://www.notion.so/3dfe76ad1e9f816692b8eb43006151f6"))
 actions.add_child(guide)

func open_handoff() -> void:
 EditorInterface.save_all_scenes()
 var root=ProjectSettings.globalize_path("res://")
 var linked=DirAccess.dir_exists_absolute(root.path_join(".git")) or FileAccess.file_exists(root.path_join(".git"))
 status.text="Scenes saved. This folder is a Git repository.\nOpen the same repository in GitHub Desktop." if linked else "Scenes saved. This folder is not yet a Git repository.\nIn GitHub Desktop: File → Add Local Repository → select this folder.\nChoose Create a Repository here if prompted, then Publish repository."
 var scale=EditorInterface.get_editor_scale()
 for child in panel.get_children():
  if child is VBoxContainer:child.custom_minimum_size.x=700*scale
 panel.min_size=Vector2i(int(740*scale),int(480*scale))
 panel.popup_centered(panel.min_size)

func _exit_tree() -> void:
 if is_instance_valid(button):
  remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,button)
  button.queue_free()
 if is_instance_valid(panel):panel.queue_free()
