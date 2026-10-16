@tool
extends RefCounted
static func primitive(kind: String) -> Mesh:
 if kind == "Sphere":
  var sphere = SphereMesh.new();sphere.radius=.5;sphere.height=1; sphere.radial_segments=20;sphere.rings=12
  return sphere
 if kind == "Cylinder":
  var cylinder = CylinderMesh.new();cylinder.top_radius=.5;cylinder.bottom_radius=.5;cylinder.height=1;cylinder.radial_segments=20
  return cylinder
 if kind == "Ramp":
  var a=Vector3(-.5,-.5,-.5);var b=Vector3(.5,-.5,-.5);var c=Vector3(.5,.5,-.5)
  var d=Vector3(-.5,-.5,.5);var e=Vector3(.5,-.5,.5);var f=Vector3(.5,.5,.5)
  var vertices=[a,c,b,d,e,f,a,d,f,a,f,c,b,c,f,b,f,e,a,b,e,a,e,d]
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  for index in range(0,vertices.size(),3):
   for v in [vertices[index],vertices[index+2],vertices[index+1]]:tool.add_vertex(v)
  tool.generate_normals();return tool.commit()
 var box=BoxMesh.new();box.size=Vector3.ONE;return box
static func transform(part: Dictionary) -> Transform3D:
 return Transform3D((Basis(Vector3.UP,deg_to_rad(part.get("turn",0.0)))*Basis.from_scale(Vector3(part.size[0],part.size[1],part.size[2]))),Vector3(part.position[0],part.position[1],part.position[2]))
static func mesh(parts: Array,colour: Color) -> ArrayMesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var material=StandardMaterial3D.new();material.albedo_color=colour;material.roughness=.9
 tool.set_material(material)
 for part in parts:tool.append_from(primitive(part.kind),0,transform(part))
 return tool.commit()
static func shapes(parts: Array) -> Array:
 var result=[]
 for part in parts:
  var points=PackedVector3Array()
  var basis=transform(part).basis
  for point in primitive(part.kind).get_faces():points.append(basis*point)
  var shape=ConvexPolygonShape3D.new();shape.points=points
  result.append(shape);result.append(Transform3D(Basis.IDENTITY,Vector3(part.position[0],part.position[1],part.position[2])))
 return result
