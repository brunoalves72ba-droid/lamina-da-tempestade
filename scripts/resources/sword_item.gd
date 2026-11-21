class_name SwordItem
extends Resource
## Uma espada do herói (GDD §10.1). O herói começa com a do Paladino; as outras são compradas no
## Ferreiro ou ganhas ao derrotar um chefão (EnemyData.sword_drop). Valores em data/swords/*.tres.

@export var id: StringName = &"paladin"
@export var display_name: String = "Espada do Paladino"
@export_multiline var description: String = ""
## Modelo 3D. Vazio = a espada que já vem no modelo do Paladino.
@export var model: PackedScene
## Material que substitui o do modelo (quando as texturas vêm separadas do .fbx).
@export var material: Material
## Comprimento total na mão (m); o modelo é escalado e alinhado sozinho (Equipment.fit_sword).
@export var length: float = 1.1
## Gira o modelo em volta da lâmina (graus) para o fio ficar no plano certo.
@export var roll_degrees: float = 0.0
## Ataque base (a Afiação do Ferreiro soma por cima).
@export var attack: float = 10.0
## Preço no Ferreiro; 0 = não está à venda.
@export var price: int = 0
## Quanto esta espada pesa no nível de ameaça dos inimigos (GameState.threat_level).
@export var threat: float = 0.0
## Ordem na loja (mais fraca primeiro).
@export var tier: int = 0
