class_name Player
extends CharacterBody2D

@export_category("Movement")
@export var speed: float = 3
@export_category("Sword")
@export var sword_damage: int = 2
@export_category("Ritual")
@export var ritual_damage: int = 1
@export var ritual_interval: float = 30
@export var ritual_scene: PackedScene
@export_category("Life")
@export var health: int = 100
@export var max_health: int = 100
@export var death_prefab: PackedScene

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sword_area: Area2D = $SwordArea
@onready var hitbox_area: Area2D = $HitboxArea
@onready var health_progress_bar: ProgressBar = $HealthProgressBar
@onready var powerup_marker = $PowerUpMarker

var increase_sword_damage_prefab: PackedScene
var decrease_ritual_time_prefab: PackedScene
var input_vector: Vector2 = Vector2(0,0)
var is_running: bool = false
var was_running: bool = false
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var hitbox_cooldown: float = 0.0
var ritual_cooldown: float = 0.0
var last_damage_increase_time = 0

signal meat_collected(value: int)

func _ready():
	GameManager.player = self
	meat_collected.connect(func(value: int): GameManager.meat_counter += 1)
	increase_sword_damage_prefab = preload("res://powerups/sword_damage.tscn")
	decrease_ritual_time_prefab = preload("res://powerups/decrease_ritual_time.tscn")

func _process(delta):
	GameManager.player_position = position
	
	#Ler input
	read_input()
	#Processar ataque
	update_attack_cooldown(delta)
	if Input.is_action_just_pressed("attack"):
		attack()
	#Processar animação e rotação do sprite
	play_run_idle_animation()
	if not is_attacking:
		rotate_sprite()
		
	#Processar dano
	update_hitbox_detection(delta)
	
	#Ritual
	update_ritual(delta)
	
	#Atualizar barra de vida
	health_progress_bar.max_value = max_health
	health_progress_bar.value = health
	
	#Aplicar powerups
	if (GameManager.time_elapsed - last_damage_increase_time) >= 60:
		# Gere um número aleatório entre 0 e 1
		var random_number = randi() % 2
		# Chame uma das funções com base no número aleatório
		if random_number == 0:
			increase_sword_damage()
		else:
			decrease_ritual_time()

func _physics_process(delta: float) -> void: 	
	# Modificar velocidade
	var target_velocity = input_vector * speed * 100.0
	#Modificar velocidade quando está atacando
	if is_attacking:
		target_velocity *= 0.25
	velocity = lerp(velocity, target_velocity, 0.05)
	move_and_slide()
	
func increase_sword_damage():
	if sword_damage >= 10: return
	# Execute a lógica para aumentar o dano da espada
	var increase_sword_damage = increase_sword_damage_prefab.instantiate()
	sword_damage += 2
	if powerup_marker:
		increase_sword_damage.global_position = powerup_marker.global_position
	else:
		increase_sword_damage.global_position = global_position
	get_parent().add_child(increase_sword_damage)
		
	# Atualize o tempo do último incremento de dano
	last_damage_increase_time = GameManager.time_elapsed

func decrease_ritual_time():
	if ritual_interval <= 10: return
	var decrease_ritual_time = decrease_ritual_time_prefab.instantiate()
	ritual_interval -= 2
	if powerup_marker:
			decrease_ritual_time.global_position = powerup_marker.global_position
	else:
		decrease_ritual_time.global_position = global_position
	get_parent().add_child(decrease_ritual_time)
	# Atualize o tempo do último incremento de dano
	last_damage_increase_time = GameManager.time_elapsed

func read_input() -> void:
	 # Obter o input vector
	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Apagar deaszone do input_vector -> controle
	var deadzone = 0.15
	if abs(input_vector.x) < deadzone:
		input_vector.x = 0.0
	if abs(input_vector.y) < deadzone:
		input_vector.y = 0.0
		
	# Atualizar o is_running, só está correndo se o valor for zero
	was_running = is_running
	is_running = not input_vector.is_zero_approx()
	
func attack() -> void:
	if is_attacking:
		return
	# Tocar animação	
	animation_player.play("attack_side_1")
	attack_cooldown = 0.6 # Duração da animação
	# Marcar ataque
	is_attacking = true

func deal_damage_to_enemies():
	var bodies = sword_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			var enemy: Enemy = body
			
			var direction_to_enemy = (enemy.position - position).normalized()
			var attack_direction:Vector2
			if sprite.flip_h:
				attack_direction = Vector2.LEFT
			else:
				attack_direction = Vector2.RIGHT
			var dot_product = direction_to_enemy.dot(attack_direction)
			if dot_product >= 0.3:
				enemy.damage(sword_damage)

func play_run_idle_animation() -> void:
	# Tocar animação, só se não tiver atacando
	if not is_attacking:
		if was_running != is_running :
			if is_running:
				animation_player.play("run")
			else: 
				animation_player.play("idle")
	
func rotate_sprite() -> void:
	# Girar sprite
	if input_vector.x > 0:
		sprite.flip_h = false
	elif input_vector.x < 0:
		sprite.flip_h = true
	
func update_attack_cooldown(delta: float) -> void:
	#Verifica se está atacando
	if is_attacking:
		# Atualizar temporizador do ataque 
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			is_attacking = false
			is_running = false
			animation_player.play("idle")	 
	
func update_hitbox_detection(delta: float)-> void:
	#Temporizador
	hitbox_cooldown -= delta
	if hitbox_cooldown > 0: return
	#Frequencia
	hitbox_cooldown = 0.5
	#Detectar inimigos
	var bodies = hitbox_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			var enemy: Enemy = body
			var damage_amount = 1
			damage(damage_amount)

func damage(amount: int) -> void:
	if health <= 0:
		return
		
	health -= amount
	
	#Piscar inimigo
	modulate = Color.RED
	var twenn = create_tween()
	twenn.set_ease(Tween.EASE_IN)
	twenn.set_trans(Tween.TRANS_QUINT)
	twenn.tween_property(self, "modulate", Color.WHITE, 0.3)
	
	#Processar morte
	if health <= 0:
		die()
		
func die():
	GameManager.end_game()
	if death_prefab:
		var death_object = death_prefab.instantiate()
		death_object.position = position
		get_parent().add_child(death_object)
		
	queue_free()
		
func heal(amount: int) -> int:
	health += amount
	if health > max_health:
		health = max_health
	print("cura de ", amount, " vida é ", health)
	return health 

func update_ritual(delta: float):
	ritual_cooldown -= delta
	if ritual_cooldown > 0: return
	ritual_cooldown = ritual_interval
	
	var ritual = ritual_scene.instantiate()
	ritual.damage_amount = ritual_damage
	add_child(ritual)
	
	














