extends CharacterBody3D

const tilt_lower_limit : float = deg_to_rad(-90)
const tilt_upper_limit : float = deg_to_rad(90)

@export_range(.1, 1., .05) var look_sensitivity : float = .3

@export_group("running")
@export var running_speed : float = 8.
@export var running_accel_time : float = .02

@export_group("dash")
@export var dash_distance : float = 2.
@export var dash_duration : float = .05
@export var dash_count : int = 3
@export var dash_recharge : float = 2.

@export_group("jump")
@export var jump_height : float = 4.
@export var jump_duration : float = .5
@export var fall_duration : float = .5

## peak is the duration that the jump peak its height, 
## we can slow down gravity during peak for a longer peak
@export var peak_threshold : float = .2

## how much gravity is slowed down during peak
@export var peak_multiplier : float = .5

## if jump is released early, we can cutoff the upward velocity to fall down faster
@export var jump_cutoff_multiplier : float = .5

@export_group("wall climb")
## only for horizontal velocity
@export var wall_friction_multiplier : float = .5
## downward velocity clamp
@export var wall_sliding_speed : float = 4.
@export var wall_bounce_time : float = .2
@export var wall_bounce_count : int = 3

@export_group("assists")
@export var coyote_time : float = .2
@export var jump_buffer : float = .2

@onready var camera : Camera3D = $Camera3D

@onready var running_accel : float = running_speed / running_accel_time

@onready var coyote_timer : float = 0.
@onready var jump_buffer_timer : float = 0.
@onready var wall_bounce_timer : float = 0.

@onready var dash_speed : float = dash_distance / dash_duration
@onready var dash_timer : float = 0.
@onready var dash_direction : Vector3
@onready var dash_recharge_timer : float = 0.

@onready var dash_left : int = dash_count
@onready var wall_bounce_left : int = wall_bounce_count

@onready var wall_jump_hud := $HUD/HBoxContainer/WallJumpHud
@onready var dash_hud := $HUD/HBoxContainer/DashHud

# jump variables
var _jump_velocity : float
var _base_gravity : float
var _fall_multiplier : float

var _mouse_rotation : Vector3
var _camera_rotation : Vector3
var _player_rotation : Vector3

var _rotation_input : float
var _tilt_input : float

func state_process(delta: float) -> void:
	coyote_timer = move_toward(coyote_timer, 0., delta)
	jump_buffer_timer = move_toward(jump_buffer_timer, 0., delta)
	wall_bounce_timer = move_toward(wall_bounce_timer, 0., delta)
	dash_timer = move_toward(dash_timer, 0., delta)

	if dash_left < dash_count:
		if dash_recharge_timer > 0:
			dash_recharge_timer = move_toward(dash_recharge_timer, 0., delta)
		else:
			dash_recharge_timer = dash_recharge
			dash_left = dash_count
			dash_hud.value = 100.0

	if is_on_floor() or is_on_wall():
		coyote_timer = coyote_time

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer

func estimate_jump_and_gravity() -> void:
	# h = v * t - 0.5 * g * t^2
	_jump_velocity = 2. * jump_height / jump_duration
	# v = g * t
	_base_gravity = _jump_velocity / jump_duration
	# h = 0.5 * g * m * t^2
	_fall_multiplier = (2. * jump_height) / (_base_gravity * (fall_duration ** 2))

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	estimate_jump_and_gravity()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode():
		_rotation_input = -event.relative.x
		_tilt_input = -event.relative.y

func _process(delta: float) -> void:
	_mouse_rotation.x += _tilt_input * look_sensitivity * delta
	_mouse_rotation.y += _rotation_input * look_sensitivity * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, tilt_lower_limit, tilt_upper_limit)

	_camera_rotation = Vector3(_mouse_rotation.x, 0., 0.)
	_player_rotation = Vector3(0., _mouse_rotation.y, 0.)

	camera.transform.basis = Basis.from_euler(_camera_rotation)
	camera.rotation.z = 0.

	var current_speed : float = Vector3(velocity.x, 0., velocity.z).length()
	var max_speed : float = dash_speed
	var min_speed : float = running_speed
	camera.fov = lerpf(75, 73, (current_speed - min_speed) / (max_speed - min_speed))

	global_transform.basis = Basis.from_euler(_player_rotation)

	_rotation_input = 0.
	_tilt_input = 0.

func _physics_process(delta: float) -> void:
	state_process(delta)

	if dash_timer > 0.:
		velocity = (transform.basis * dash_direction).normalized() * dash_speed
	else:
		if is_on_floor():
			wall_bounce_left = wall_bounce_count
			wall_jump_hud.value = 100.0

		var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var input_direction := Vector3(input_vector.x, 0., input_vector.y)

		if Input.is_action_just_pressed("dash") and dash_left > 0:
			if input_direction:
				dash_direction = Vector3(input_vector.x, 0., input_vector.y)
			else:
				dash_direction = Vector3.FORWARD
			dash_timer = dash_duration
			if dash_left >= dash_count:
				dash_recharge_timer = dash_recharge
			dash_left -= 1
			dash_hud.value = dash_left*100.0/dash_count
			return
		elif wall_bounce_timer <= 0.:
			var running_direction : Vector3 = (transform.basis * input_direction).normalized()
			velocity.x = move_toward(velocity.x, running_direction.x * running_speed, running_accel * delta)
			velocity.z = move_toward(velocity.z, running_direction.z * running_speed, running_accel * delta)

		if not is_on_floor():
			var is_going_down : bool = velocity.y < 0.
			var gravity : float = _base_gravity
			if absf(velocity.y) < peak_threshold:
				gravity *= peak_multiplier
			elif is_going_down:
				gravity *= _fall_multiplier
			velocity.y -= gravity * delta

			if Input.is_action_just_released("jump") and not is_going_down:
				wall_bounce_timer = 0
				velocity.y *= jump_cutoff_multiplier

		if jump_buffer_timer > 0 and coyote_timer > 0:
			jump_buffer_timer = 0
			if is_on_wall():
				if wall_bounce_left > 0:
					wall_bounce_timer = wall_bounce_time
					var bounce_direction = (get_wall_normal() + Vector3.UP * 2.).normalized()
					velocity = bounce_direction * _jump_velocity
					wall_bounce_left -= 1
					wall_jump_hud.value = wall_bounce_left*100.0/wall_bounce_count
			else:
				velocity.y = _jump_velocity
			if not Input.is_action_pressed("jump"):
				velocity.y *= jump_cutoff_multiplier
		
		if is_on_wall() and velocity.dot(get_wall_normal()) < 0.:
				velocity.x *= wall_friction_multiplier
				velocity.z *= wall_friction_multiplier
				velocity.y = maxf(velocity.y, -wall_sliding_speed)

	move_and_slide()
