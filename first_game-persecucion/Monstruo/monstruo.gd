extends CharacterBody2D

enum State { IDLE, CHASE, SEARCH }

@export var speed = 100
@export var detection_radius = 300 # Distancia máxima de visión
@export var fov_angle = PI / 2 # Campo de visión (en radianes)
@export var target: Node2D = null # Referencia al jugador

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var search_timer: Timer = $SearchTimer
@onready var wait_timer: Timer = $WaitTimer
@onready var raycast: RayCast2D = $RayCast2D

var state = State.IDLE
var last_known_position: Vector2 = Vector2.ZERO

func _ready():
	raycast.enabled = true
	nav_agent.max_speed = speed
	wait_timer.one_shot = true
	_start_patrol()

func _physics_process(delta):
	match state:
		State.IDLE:
			# Patrullaje aleatorio por el laberinto
			if can_see_player():
				state = State.CHASE
			else:
				# Si llegó al punto de patrulla y no está esperando, iniciar espera
				if nav_agent.is_navigation_finished() and wait_timer.is_stopped():
					wait_timer.start()
				else:
					_mover(delta)

		State.CHASE:
			# Perseguir mientras vea al jugador
			if can_see_player():
				nav_agent.target_position = target.global_position
				_mover(delta)
			else:
				# Perdió al jugador: ir a la última posición conocida
				last_known_position = target.global_position
				nav_agent.target_position = last_known_position
				state = State.SEARCH
				search_timer.start()
				_mover(delta)

		State.SEARCH:
			# Buscar en la última posición; si lo ve, volver a CHASE
			if can_see_player():
				search_timer.stop()
				state = State.CHASE
			elif nav_agent.is_navigation_finished():
				# No lo encontró, volver a patrullar
				state = State.IDLE
				_start_patrol()
			else:
				_mover(delta)

	# Rotar hacia la dirección de movimiento
	if velocity.length() > 0:
		rotation = velocity.angle()

# Función para mover según el pathfinding
func _mover(delta):
	var siguiente = nav_agent.get_next_path_position()
	var direccion = (siguiente - global_position).normalized()
	velocity = direccion * speed
	move_and_slide()

# Seleccionar punto aleatorio de patrulla dentro del navmesh
func _start_patrol():
	# Obtener RID del mapa de navegación del agente
	var nav_map: RID = nav_agent.get_navigation_map()
	if nav_map and nav_map != RID():
		var layers = nav_agent.navigation_layers
		var punto = NavigationServer2D.map_get_random_point(nav_map, layers, true)
		nav_agent.target_position = punto

# Chequeo de línea de visión: distancia, FOV y obstáculos
func can_see_player() -> bool:
	if not target:
		return false
	var to_player = target.global_position - global_position
	if to_player.length() > detection_radius:
		return false
	var ang_diff = abs(wrapf(to_player.angle() - rotation, -PI, PI))
	if ang_diff > fov_angle * 0.5:
		return false
	# Raycast para detectar muros
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self]
	var result = space.intersect_ray(query)
	return result and result.collider == target

# Al expirar el temporizador de patrulla, iniciar nuevo punto aleatorio
func _on_WaitTimer_timeout() -> void:
	if state == State.IDLE:
		_start_patrol()

# Al expirar el temporizador de búsqueda sin ver al jugador, volver a patrullar
func _on_SearchTimer_timeout() -> void:
	if state == State.SEARCH:
		state = State.IDLE
		_start_patrol()
