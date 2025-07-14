extends CharacterBody3D


@export_group("camera")
@export_range(.1, 1., .05) var look_sensitivity : float = .3
@export var walking_height : float = .5
@export var sliding_height : float = -.5

@export var camera_max_tilt : float = .02
@export var camera_tilt_speed : float = .5

@onready var head : Node3D = $Head
@onready var camera : Camera3D = $Head/Camera3D

var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float

@export_group("stamina")
@export var max_stamina : float = 3
@export var stamina_recovery_rate : float = 1.2
@export var infinite_stamina : bool = false

@onready var stamina : float = max_stamina

@export_group("walk")
@export var walking_speed : float = 8.

var _horizontal_velocity : Vector2

@export_group("jump")
@export var jumping_height : float = 4.
@export var jumping_duration : float = .5

## if jump is released early, we can cutoff the upward velocity to fall down faster
@export var jump_cutoff_multiplier : float = .5

var _jump_velocity : float
var _gravity : float

var _vertical_velocity : float

@export_group("fall")
@export var aerial_accel : float = 32.
@export var max_aerial_velocity : float = 8.

@export_group("dash")
@export var dashing_speed : float = 24.
@export var dashing_distance : float = 4.

@onready var dash_duration : float = dashing_distance / dashing_speed
@onready var dash_timer : float = 0.

@export_group("slide")
@export var sliding_speed : float = 12.
@export var sliding_decel : float = 32.

@export_group("slamming")
@export var slamming_speed : float = 50.

@export_group("wall")
## only for horizontal velocity
@export var wall_friction_multiplier : float = .5
## downward velocity clamp
@export var wall_fall_speed : float = 4.

@export var wall_bounce_time : float = .2
@onready var wall_bounce_timer : float = 0.

@export var wall_bounce_count : int = 3
@onready var wall_bounce_left : int = wall_bounce_count

@export_group("assists")
@export var coyote_time : float = .1
@onready var coyote_timer : float = 0.

@export var jump_buffer : float = .1
@onready var jump_buffer_timer : float = 0.

@export var slide_buffer : float = .1
@onready var slide_buffer_timer : float = 0.

enum State {
	WALKING,
	SLIDING,
	DASHING,
	SLAMMING,
	FALLING,
	WALL_CLIMBING,
	WALL_BOUNCING,
}

@onready var current_state = State.WALKING

func jump() -> bool:
	if jump_buffer_timer > 0. and coyote_timer > 0.:
		jump_buffer_timer = 0.
		_vertical_velocity = _jump_velocity
		if not Input.is_action_pressed("jump"):
			_vertical_velocity *= jump_cutoff_multiplier
		current_state = State.FALLING
		return true
	return false

func dash() -> bool:
	if Input.is_action_just_pressed("dash") and consume_stamina(1.):
		var horizontal_input = get_horizontal_input()
		if horizontal_input:
			_horizontal_velocity = horizontal_input * dashing_speed
		else:
			_horizontal_velocity = get_forward_direction() * dashing_speed
		dash_timer = dash_duration
		current_state = State.DASHING
		return true
	return false

func wall_bounce() -> bool:
	if wall_bounce_left > 0 and jump_buffer_timer > 0.:
		wall_bounce_left -= 1
		_vertical_velocity = _jump_velocity
		var wall_normal = get_wall_normal()
		_horizontal_velocity.x = wall_normal.x * walking_speed
		_horizontal_velocity.y = wall_normal.z * walking_speed
		wall_bounce_timer = 0
		current_state = State.WALL_BOUNCING
		return true
	return false

func slide() -> bool:
	if slide_buffer_timer > 0. and is_on_floor():
		current_state = State.SLIDING
		var horizontal_input = get_horizontal_input()
		if horizontal_input:
			_horizontal_velocity = horizontal_input * _horizontal_velocity.length()
		else:
			_horizontal_velocity = get_forward_direction() * _horizontal_velocity.length()
		return true
	return false

func slam() -> bool:
	if Input.is_action_just_pressed("slide"):
		current_state = State.SLAMMING
		return true
	return false

func walking_process(_delta: float) -> void:
	if not is_on_floor():
		current_state = State.FALLING
		return
	if jump():
		return
	if dash():
		return
	if slide():
		return
	_horizontal_velocity = get_horizontal_input() * walking_speed

func sliding_process(delta: float) -> void:
	if not Input.is_action_pressed("slide"):
		current_state = State.WALKING
		return
	if jump():
		return
	_vertical_velocity -= _gravity * delta
	if _horizontal_velocity:
		_horizontal_velocity = _horizontal_velocity.normalized() * maxf(_horizontal_velocity.length(), sliding_speed)
	else:
		_horizontal_velocity = get_forward_direction() * sliding_speed
	_horizontal_velocity = _horizontal_velocity.move_toward(_horizontal_velocity.normalized() * sliding_speed, sliding_decel * delta)

func dashing_process(delta: float) -> void:
	dash_timer = move_toward(dash_timer, 0., delta)
	if dash_timer <= 0.:
		_horizontal_velocity = _horizontal_velocity.normalized() * walking_speed
		current_state = State.FALLING
		return
	if jump():
		return

func slamming_process(_delta: float) -> void:
	if is_on_floor():
		current_state = State.WALKING
		return
	_vertical_velocity = -slamming_speed
	_horizontal_velocity = get_horizontal_input() * walking_speed

func falling_process(delta: float) -> void:
	if is_on_floor():
		current_state = State.WALKING
		return
	if is_on_wall():
		current_state = State.WALL_CLIMBING
		return
	var horizontal_input := get_horizontal_input()
	if jump():
		return
	if dash():
		return
	if slam():
		return
	_vertical_velocity -= _gravity * delta
	if Input.is_action_just_released("jump") and _vertical_velocity >= 0.:
		_vertical_velocity *= jump_cutoff_multiplier
	var updated_horizontal_velocity = _horizontal_velocity + horizontal_input * aerial_accel * delta
	if updated_horizontal_velocity.length() > maxf(_horizontal_velocity.length(), max_aerial_velocity):
		_horizontal_velocity = updated_horizontal_velocity.normalized() * maxf(_horizontal_velocity.length(), max_aerial_velocity)
	else:
		_horizontal_velocity = updated_horizontal_velocity

func wall_climbing_process(delta: float) -> void:
	if is_on_floor():
		current_state = State.WALKING
		return
	if not is_on_wall():
		current_state = State.FALLING
		return
	if wall_bounce():
		return
	if dash():
		return
	if slam():
		return
	_vertical_velocity -= _gravity * delta
	_vertical_velocity = maxf(_vertical_velocity, -wall_fall_speed)
	_horizontal_velocity = get_horizontal_input() * walking_speed * wall_friction_multiplier

func wall_bouncing_process(delta: float) -> void:
	wall_bounce_timer = move_toward(wall_bounce_timer, 0., delta)
	if wall_bounce_timer <= 0.:
		current_state = State.FALLING
		return

func consume_stamina(value: float) -> bool:
	if stamina < value:
		return false
	stamina -= value
	return true

func estimate_jump_and_gravity() -> void:
	# h = v * t - 0.5 * g * t^2
	_jump_velocity = 2. * jumping_height / jumping_duration
	# v = g * t
	_gravity = _jump_velocity / jumping_duration

func camera_process(delta: float) -> void:
	_mouse_rotation.x += _tilt_input * look_sensitivity * delta
	_mouse_rotation.y += _rotation_input * look_sensitivity * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, PI * -.5, PI * .5)

	head.transform.basis = Basis.from_euler(Vector3(_mouse_rotation.x, 0., 0.))
	head.rotation.z = .0

	# Camera Tilt
	global_transform.basis = Basis.from_euler(Vector3(0., _mouse_rotation.y, 0.))
	var lr_axis := Input.get_axis("move_left", "move_right")
	if lr_axis < 0.:
		camera.rotation.z = min(camera_max_tilt, camera.rotation.z+camera_tilt_speed*delta)
	elif lr_axis > 0.:
		camera.rotation.z = max(-camera_max_tilt, camera.rotation.z-camera_tilt_speed*delta)
	elif camera.rotation.z != 0.:
		var new_camera_tilt = camera.rotation.z-camera_tilt_speed*delta*sign(camera.rotation.z)
		camera.rotation.z = new_camera_tilt if sign(new_camera_tilt) == sign(camera.rotation.z) else 0. 

	_rotation_input = 0.
	_tilt_input = 0.

	if current_state == State.SLIDING:
		head.position.y = sliding_height
	else:
		head.position.y = walking_height

func get_horizontal_input() -> Vector2:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var local_direction := Vector3(input_vector.x, 0., input_vector.y)
	var transformed_direction : Vector3 = (transform.basis * local_direction).normalized()
	return Vector2(transformed_direction.x, transformed_direction.z)

func get_forward_direction() -> Vector2:
	var transformed_direction : Vector3 = (transform.basis * Vector3.FORWARD).normalized()
	return Vector2(transformed_direction.x, transformed_direction.z)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	estimate_jump_and_gravity()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode():
		_rotation_input = -event.relative.x
		_tilt_input = -event.relative.y

func _process(delta: float) -> void:
	camera_process(delta)

func _physics_process(delta: float) -> void:
	stamina = minf(move_toward(stamina, max_stamina, stamina_recovery_rate * delta), max_stamina)
	coyote_timer = move_toward(coyote_timer, 0., delta)
	jump_buffer_timer = move_toward(jump_buffer_timer, 0., delta)
	slide_buffer_timer = move_toward(slide_buffer_timer, 0., delta)

	_horizontal_velocity = Vector2(velocity.x, velocity.z)
	_vertical_velocity = velocity.y

	if is_on_floor():
		coyote_timer = coyote_time
		wall_bounce_left = wall_bounce_count

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer

	if Input.is_action_just_pressed("slide"):
		slide_buffer_timer = slide_buffer

	match current_state:
		State.WALKING:
			walking_process(delta)
		State.SLIDING:
			sliding_process(delta)
		State.DASHING:
			dashing_process(delta)
		State.SLAMMING:
			slamming_process(delta)
		State.FALLING:
			falling_process(delta)
		State.WALL_CLIMBING:
			wall_climbing_process(delta)
		State.WALL_BOUNCING:
			wall_bouncing_process(delta)

	velocity = Vector3(_horizontal_velocity.x, _vertical_velocity, _horizontal_velocity.y)

	move_and_slide()
