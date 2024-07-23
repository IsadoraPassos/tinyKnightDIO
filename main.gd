extends Node

@export var game_ui: CanvasLayer

func _ready():
	GameManager.game_over.connect(trigger_game_over)

func trigger_game_over():
	#Deletar GamaUI
	if game_ui:
		game_ui.queue_free()
		game_ui = null
	
	#Criar GameOverUI
	var game_over_ui_template = preload("res://ui/game_over_ui.tscn")
	var game_over_ui: GameOverUI = game_over_ui_template.instantiate()
	add_child(game_over_ui)





