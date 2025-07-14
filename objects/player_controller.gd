extends CharacterBody3D

@export_group("camera")
@export_range(.1, 1., .05) var look_sensitivity : float = .3
@export var head_height : float = .5
@export var lower_height : float = -.5

@onready var camera : Camera3D = $Camera3D

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

@export_group("jump")
@export var jumping_height : float = 4.
@export var jumping_duration : float = .5

## if jump is released early, we can cutoff the upward velocity to fall down faster
@export var jump_cutoff_multiplier : float = .5

var _jump_velocity : float
var _gravity : float

@export_group("dash")
@export var dashing_speed : float = 24.
@export var dashing_distance : float = 4.

@onready var dash_duration : float = dashing_distance / dashing_speed
@onready var dash_timer : float = 0.
@onready var dash_direction : Vector3

@export_group("slide")
@export var sliding_speed : float = 12.

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

@export var coyote_time : float = .2
@onready var coyote_timer : float = 0.

@export var jump_buffer : float = .2
@onready var jump_buffer_timer : float = 0.

func consume_stamina(value: float) -> bool:
	if stamina < value:
		return false
	stamina -= value
	return true


func state_process(delta: float) -> void:
	coyote_timer = move_toward(coyote_timer, 0., delta)
	jump_buffer_timer = move_toward(jump_buffer_timer, 0., delta)
	wall_bounce_timer = move_toward(wall_bounce_timer, 0., delta)
	dash_timer = move_toward(dash_timer, 0., delta)
	stamina = minf(move_toward(stamina, max_stamina, stamina_recovery_rate * delta), max_stamina)

	if is_on_floor() or is_on_wall():
		coyote_timer = coyote_time

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer

func estimate_jump_and_gravity() -> void:
	# h = v * t - 0.5 * g * t^2
	_jump_velocity = 2. * jumping_height / jumping_duration
	# v = g * t
	_gravity = _jump_velocity / jumping_duration

func camera_process(delta: float) -> void:
	_mouse_rotation.x += _tilt_input * look_sensitivity * delta
	_mouse_rotation.y += _rotation_input * look_sensitivity * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, PI * -.5, PI * .5)

	camera.transform.basis = Basis.from_euler(Vector3(_mouse_rotation.x, 0., 0.))
	camera.rotation.z = 0.

	global_transform.basis = Basis.from_euler(Vector3(0., _mouse_rotation.y, 0.))

	_rotation_input = 0.
	_tilt_input = 0.

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
	state_process(delta)

	if dash_timer > 0.:
		velocity = (transform.basis * dash_direction).normalized() * dashing_speed
	else:
		if is_on_floor():
			wall_bounce_left = wall_bounce_count

		var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var input_direction := Vector3(input_vector.x, 0., input_vector.y)

		if Input.is_action_just_pressed("dash") and consume_stamina(1.):
			if input_direction:
				dash_direction = Vector3(input_vector.x, 0., input_vector.y)
			else:
				dash_direction = Vector3.FORWARD
			dash_timer = dash_duration
			return
		elif wall_bounce_timer <= 0.:
			var running_direction : Vector3 = (transform.basis * input_direction).normalized()
			velocity.x = running_direction.x * walking_speed
			velocity.z = running_direction.z * walking_speed

		if not is_on_floor():
			velocity.y -= _gravity * delta
			if Input.is_action_just_released("jump") and velocity.y >= 0.:
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
			else:
				velocity.y = _jump_velocity
			if not Input.is_action_pressed("jump"):
				velocity.y *= jump_cutoff_multiplier
		
		if is_on_wall() and velocity.dot(get_wall_normal()) < 0.:
				velocity.x *= wall_friction_multiplier
				velocity.z *= wall_friction_multiplier
				velocity.y = maxf(velocity.y, -wall_fall_speed)

	move_and_slide()
