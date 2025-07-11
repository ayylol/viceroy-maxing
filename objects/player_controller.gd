extends CharacterBody3D

@export var sensitivity : float = .5

@export var tilt_lower_limit : float = deg_to_rad(-90)
@export var tilt_upper_limit : float = deg_to_rad(90)

@onready var camera : Camera3D = $Camera3D

var _mouse_rotation : Vector3
var _camera_rotation : Vector3
var _player_rotation : Vector3

var _rotation_input : float
var _tilt_input : float


const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode():
		_rotation_input = -event.relative.x
		_tilt_input = -event.relative.y

func _process(delta: float) -> void:
	_mouse_rotation.x += _tilt_input * sensitivity * delta
	_mouse_rotation.y += _rotation_input * sensitivity * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, tilt_lower_limit, tilt_upper_limit)

	_camera_rotation = Vector3(_mouse_rotation.x, 0., 0.)
	_player_rotation = Vector3(0., _mouse_rotation.y, 0.)

	camera.transform.basis = Basis.from_euler(_camera_rotation)
	camera.rotation.z = 0
	global_transform.basis = Basis.from_euler(_player_rotation)

	_rotation_input = 0
	_tilt_input = 0

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
