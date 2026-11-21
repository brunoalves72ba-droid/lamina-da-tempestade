class_name StoryArc
extends Resource
## Um arco da campanha (GDD §4.1): narração de abertura, objetivos em sequência (sempre há um
## objetivo claro na HUD), narração de encerramento e recompensas. Arquivos em data/story/.

@export var title: String = ""
## Falas de abertura: "Quem|Texto". Sem "|" = Narrador.
@export_multiline var intro_lines: Array[String] = []
@export var objectives: Array[StoryObjective] = []
@export_multiline var outro_lines: Array[String] = []
## Reputação ganha ao concluir: facção (GameState.FACTIONS) -> pontos.
@export var reputation_rewards: Dictionary[StringName, int] = {}
@export var gold_reward: int = 0
