extends "res://shared/body.gd"
const RADIUS = .32
const MAX_SPEED = 3.0
# Keep the old stored property so existing maps retain their choice.
@export_storage var ground_adhesion = true
## Keeps the Wheel against build surfaces. Falling Things remain unassisted.
@export var assisted: bool:
 get: return ground_adhesion
 set(value): ground_adhesion = value
var control_override = Vector2.ZERO
var sinking = false
var sink_age = 0.0
var water_level = 0
var pending_reset = false
var reset_position = Vector3.ZERO
var supported = false
var support_normal = Vector3.UP
var air_age = 0.0
func _ready() -> void:
 super._ready()
 collision_layer = 2
 collision_mask = 5
 angular_damp = .8
func configure_scale() -> void:
 $Shape.shape.radius = RADIUS
 mass = maxf(.1,float(data.get("mass",1)))
func snapshot() -> Dictionary:
 var out = super.snapshot()
 out.scale = RADIUS/runtime.compiler.numbers.body.radius
 return out
func prepare(p: Dictionary,delta: float) -> void:
 # The Wheel is a grounded route tester. Generic things carry the full rest/apex laws.
 parameters = p
 var gravity = p.gravity.vector*p.gravity.strength if p.gravity.enabled else Vector3.ZERO
 gravity_scale = -gravity.y/9.8 if absf(gravity.x)+absf(gravity.z)<.0001 else 0.0
 constant_force = gravity*mass if absf(gravity.x)+absf(gravity.z)>=.0001 else Vector3.ZERO
 if p.weather.wind_enabled:
  var n = runtime.compiler.numbers
  constant_force += runtime.compiler.vector_path(p.weather.wind_path,Vector3.RIGHT,runtime.elapsed)*(n.bench.wind_ground_gain if supported else n.bench.wind_air_gain)/n.bench.wind_reference_pixels_per_metre*p.body.response_factor*p.weather.wind_strength
 linear_damp = p.body.motion_resistance
 physics_material_override.bounce = p.body.rebound
 previous_velocity = linear_velocity
 landed = supported
 hanging = false
 carried = false
 ring_age += delta
 $Vibration.visible = p.sound.visible and ring_age<1.5 and not runtime.first_person
 $Vibration.scale = Vector3.ONE*(1+ring_age*8)
 if supported: air_age = 0
 else: air_age += delta
 # A zero/upward gravity condition must not strand the map tester above a gap.
 if ground_adhesion and air_age>1.0 and (not p.gravity.enabled or p.gravity.vector.y>-.2): runtime.recover_wheel()
func reset_to(point: Vector3) -> void:
 reset_position = point
 pending_reset = true
 sinking = false
 sink_age = 0
 hanging = false
 carried = false
 supported = false
 air_age = 0
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 if pending_reset:
  state.transform = Transform3D(Basis.IDENTITY,reset_position)
  state.linear_velocity = Vector3.ZERO
  state.angular_velocity = Vector3.ZERO
  pending_reset = false
 if runtime == null or not runtime.active_plot or parameters.is_empty(): return
 var axis = control_override
 if axis.is_zero_approx():
  axis = Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
 if axis.length()>1: axis = axis.normalized()
 var direction = Vector3(-axis.y,0,axis.x)
 var support = runtime.wheel_support(state.transform.origin)
 supported = not support.is_empty() and support.normal.dot(Vector3.UP)>.5 and not sinking
 if supported:
  support_normal = support.normal
  var tangent = direction.slide(support_normal).normalized()
  var normal_speed = state.linear_velocity.dot(support_normal)
  if ground_adhesion:
   # Cancel only separation from an existing surface, not the world's gravity on things.
   if normal_speed>0: state.linear_velocity -= support_normal*normal_speed
   var outward = (Vector3(0,-gravity_scale*9.8,0)+constant_force/mass).dot(support_normal)
   state.apply_central_force(-support_normal*mass*(4.0+maxf(0,outward)))
  var plane_velocity = state.linear_velocity.slide(support_normal)
  var target_velocity = tangent*MAX_SPEED
  if not direction.is_zero_approx():
   var barrier = runtime.wheel_barrier(state.transform.origin,direction)
   if not barrier.is_empty(): target_velocity = Vector3.ZERO
  state.apply_central_force((target_velocity-plane_velocity)*mass*10.0)
 else:
  if not direction.is_zero_approx(): state.apply_central_force(direction*mass*.5)
 var horizontal = Vector2(state.linear_velocity.x,state.linear_velocity.z)
 if horizontal.length()>MAX_SPEED:
  horizontal = horizontal.normalized()*MAX_SPEED
  state.linear_velocity.x = horizontal.x
  state.linear_velocity.z = horizontal.y
 # View orientation follows travel, independently of the sphere's rolling rotation.
 if not direction.is_zero_approx(): runtime.view_direction = direction
 if sinking:
  state.linear_velocity.y = minf(state.linear_velocity.y,-1.5)
  state.linear_velocity.x *= .9
  state.linear_velocity.z *= .9
