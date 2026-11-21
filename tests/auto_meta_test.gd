extends Node
## Teste automático da progressão: loja, save/load, XP e níveis, upgrades + nível aplicados ao herói
## na trilha, morte (volta à fogueira guardando metade do ouro) e pausa. Na pasta do projeto:
##   godot --headless --path . --fixed-fps 60 res://tests/auto_meta_test.tscn
## Sai com código 0 se tudo passar e 1 se algo falhar. Usa um arquivo de save próprio.

const SWORD: UpgradeData = preload("res://data/upgrades/sword.tres")
const ARMOR: UpgradeData = preload("res://data/upgrades/armor.tres")
const TRAIL_SCENE: PackedScene = preload("res://scenes/levels/trail_01.tscn")
const PAUSE_SCENE: PackedScene = preload("res://ui/menus/pause_menu.tscn")
const TEST_SAVE_PATH := "user://test_save.json"

var _failures: int = 0


func _ready() -> void:
	SaveManager.persist = false
	GameState.reset()
	_test_shop()
	_test_save_roundtrip()
	_test_levels()
	_test_save_v2()
	await _test_pools()
	_test_audio_voices()
	_test_story()
	await _test_upgrades_applied()
	await _test_death_respawn()
	await _test_pause()
	await _test_world_events()
	GameState.reset()
	print("\n%s — %d falha(s)" % ["META OK" if _failures == 0 else "META FALHOU", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_shop() -> void:
	print("\n[Loja]")
	GameState.reset()
	GameState.add_gold(60)
	_check(GameState.try_buy(SWORD), "compra o nível 1 da Espada com 60 de ouro")
	_check(GameState.level_of(SWORD) == 1 and GameState.gold == 10, "nível 1, sobram 10 de ouro")
	_check(not GameState.try_buy(SWORD), "sem ouro suficiente, não compra o nível 2 (custa 100)")
	GameState.add_gold(10000)
	while GameState.try_buy(SWORD):
		pass
	_check(GameState.level_of(SWORD) == SWORD.max_level(), "para no nível máximo (%d)" % SWORD.max_level())
	_check(SWORD.cost_for_next(GameState.level_of(SWORD)) == -1 and not GameState.can_buy(SWORD), "no máximo, não há próximo custo")
	var spent := 0
	for cost: int in SWORD.costs:
		spent += cost
	_check(GameState.gold == 60 + 10000 - spent, "gasto total da Espada = %d" % spent)


func _test_save_roundtrip() -> void:
	print("\n[Save em JSON]")
	SaveManager.save_path = TEST_SAVE_PATH
	SaveManager.persist = true
	GameState.reset()
	GameState.add_gold(321)
	GameState.add_gold(1000)
	GameState.try_buy(ARMOR)
	GameState.try_buy(ARMOR)
	GameState.sword_element = Element.Type.HEROIC
	var gold_before := GameState.gold
	_check(SaveManager.save_game(), "grava o arquivo")
	GameState.reset()
	_check(SaveManager.load_game(), "lê o arquivo")
	_check(GameState.gold == gold_before, "ouro preservado (%d)" % GameState.gold)
	_check(GameState.level_of(ARMOR) == 2, "nível da Armadura preservado")
	_check(GameState.sword_element == Element.Type.HEROIC, "elemento preservado")
	SaveManager.delete_save()
	_check(not FileAccess.file_exists(TEST_SAVE_PATH), "apaga o arquivo de teste")
	SaveManager.persist = false
	SaveManager.save_path = SaveManager.DEFAULT_PATH


## Save v2: espadas, reputação, história, mira, New Game+ e posição; save v1 ainda carrega.
func _test_save_v2() -> void:
	print("\n[Save v2 e auto-save]")
	SaveManager.save_path = TEST_SAVE_PATH
	SaveManager.persist = true
	GameState.reset()
	GameState.grant_sword(&"cimitarra")
	GameState.equip_sword(&"cimitarra")
	GameState.change_reputation(&"ordem_grifo", 30)
	GameState.story_arc = 2
	GameState.complete_objective(&"a3_mutante")
	GameState.aim_mode = GameState.AimMode.FREE
	GameState.checkpoint_progress = 153.0
	GameState.new_game_plus = 1
	_check(SaveManager.save_game(), "grava o save v2")
	GameState.reset()
	_check(SaveManager.load_game(), "lê o save v2")
	_check(GameState.owns_sword(&"cimitarra") and GameState.equipped_sword == &"cimitarra", "espada comprada e equipada preservadas")
	_check(GameState.reputation_of(&"ordem_grifo") == 30, "reputação preservada")
	_check(GameState.story_arc == 2 and GameState.is_objective_done(&"a3_mutante"), "arco e objetivos preservados")
	_check(GameState.aim_mode == GameState.AimMode.FREE, "modo de mira preservado")
	_check(is_equal_approx(GameState.checkpoint_progress, 153.0) and GameState.new_game_plus == 1, "fogueira e New Game+ preservados")
	var v1 := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	v1.store_string(JSON.stringify({"version": 1, "state": {"gold": 77, "level": 3, "xp": 5, "upgrades": {}}}))
	v1.close()
	_check(SaveManager.load_game() and GameState.gold == 77 and GameState.story_arc == 0, "save antigo (v1) carrega com a história no começo")
	_check(GameState.owns_sword(GameState.STARTING_SWORD), "save antigo começa com a espada básica")
	var threat := GameState.threat_level()
	GameState.start_new_game_plus()
	_check(GameState.threat_level() > threat and GameState.story_arc == 0, "New Game+ reinicia a história com inimigos mais fortes")
	SaveManager.delete_save()
	SaveManager.persist = false
	SaveManager.save_path = SaveManager.DEFAULT_PATH
	GameState.reset()


func _test_pools() -> void:
	print("\n[Object Pooling]")
	var factory := func() -> Node: return Node3D.new()
	var first := Pools.acquire(&"test_node", factory, self)
	Pools.release(first)
	_check(first.get_parent() != self and Pools.free_count(&"test_node") == 1, "nó devolvido sai da cena e fica guardado")
	var second := Pools.acquire(&"test_node", factory, self)
	_check(second == first, "o mesmo nó é reutilizado")
	Pools.release_after(second, 0.1)
	await get_tree().create_timer(0.2).timeout
	_check(Pools.free_count(&"test_node") == 1, "devolução agendada funciona")
	var arcs_before: Array = Pools.stats().get(&"lightning_arc", [0, 0])
	for i: int in 30:
		LightningArc.spawn(self, Vector3.ZERO, Vector3.UP, Color.WHITE, 0.05)
	await get_tree().create_timer(0.3).timeout
	for i: int in 30:
		LightningArc.spawn(self, Vector3.ZERO, Vector3.UP, Color.WHITE, 0.05)
	var arcs: Array = Pools.stats().get(&"lightning_arc", [0, 0])
	_check(arcs[0] - arcs_before[0] <= 30 and arcs[1] - arcs_before[1] >= 30, "raios reutilizados (%d criados, %d reutilizados)" % [arcs[0] - arcs_before[0], arcs[1] - arcs_before[1]])
	await get_tree().create_timer(0.3).timeout


func _test_audio_voices() -> void:
	print("\n[Áudio: canais limitados]")
	AudioManager.stop_all()
	for i: int in 12:
		AudioManager._last_played.clear()
		AudioManager.play(&"thunder")
	var thunders := 0
	for i: int in AudioManager.MAX_VOICES:
		if AudioManager._voices[i].playing and AudioManager._voice_sound[i] == &"thunder":
			thunders += 1
	_check(thunders <= 2, "no máximo 2 trovões ao mesmo tempo (%d)" % thunders)
	for i: int in 60:
		AudioManager._last_played.clear()
		AudioManager.play([&"zap", &"hit", &"swing", &"parry", &"roar"][i % 5])
	_check(AudioManager.active_voices() <= AudioManager.MAX_VOICES, "nunca passa de %d canais" % AudioManager.MAX_VOICES)
	_check(AudioManager.stats()[1] > 0, "voice stealing entra em ação quando satura")
	AudioManager.stop_all()


func _test_story() -> void:
	print("\n[Arcos de história]")
	GameState.reset()
	var director := StoryDirector.new()
	add_child(director)
	_check(director.arcs.size() >= 4, "campanha com %d arcos" % director.arcs.size())
	var objective_texts: Array[String] = []
	var on_objective := func(_arc: String, text: String) -> void: objective_texts.append(text)
	Events.objective_changed.connect(on_objective)
	director.begin()
	_check(not objective_texts.is_empty() and objective_texts[-1] != "", "sempre há um objetivo na HUD")
	Events.zone_cleared.emit("Clareira dos Corvos")
	_check(GameState.is_objective_done(&"a1_corvos"), "vencer a clareira cumpre o objetivo")
	Events.checkpoint_reached.emit(57.0)
	Events.zone_cleared.emit("Vale das Cinzas")
	Events.checkpoint_reached.emit(105.0)
	_check(GameState.story_arc == 1 and GameState.reputation_of(&"vilarejo_cinzas") > 0, "arco 1 concluído dá reputação com o vilarejo")
	Events.boss_defeated.emit(&"boss_warrok")
	Events.checkpoint_reached.emit(153.0)
	Events.boss_defeated.emit(&"boss_mutant")
	Events.checkpoint_reached.emit(200.0)
	Events.boss_defeated.emit(&"boss_maw")
	Events.shrine_reached.emit()
	_check(GameState.game_completed and GameState.story_arc == director.arcs.size(), "campanha concluída depois do santuário")
	Events.objective_changed.disconnect(on_objective)
	director.queue_free()
	GameState.reset()


func _test_levels() -> void:
	print("
[XP e níveis]")
	GameState.reset()
	var progression := GameState.progression
	var first := progression.xp_to_next(1)
	_check(GameState.add_xp(first - 1) == 0 and GameState.level == 1, "abaixo de %d XP continua no nível 1" % first)
	_check(GameState.add_xp(1) == 1 and GameState.level == 2 and GameState.xp == 0, "com %d XP sobe para o nível 2" % first)
	var big := progression.xp_to_next(2) + progression.xp_to_next(3) + 5
	_check(GameState.add_xp(big) == 2 and GameState.level == 4 and GameState.xp == 5, "XP de sobra sobe vários níveis de uma vez")
	_check(progression.extra_enemies(1) == 0 and progression.extra_enemies(5) == 2, "nível 5 traz 2 inimigos extras por onda")
	_check(progression.enemy_health_scale(5) > 1.0, "inimigos ficam mais fortes com o nível do herói")
	var threat_before := GameState.threat_level()
	GameState.add_gold(10000)
	GameState.try_buy(SWORD)
	GameState.try_buy(ARMOR)
	_check(GameState.threat_level() > threat_before, "comprar equipamento também fortalece os inimigos (ameaça %.1f → %.1f)" % [threat_before, GameState.threat_level()])


func _test_upgrades_applied() -> void:
	print("
[Upgrades e nível aplicados ao herói]")
	GameState.reset()
	GameState.add_gold(10000)
	GameState.try_buy(SWORD)
	GameState.try_buy(SWORD)
	GameState.try_buy(ARMOR)
	GameState.add_xp(GameState.progression.xp_to_next(1))
	var level := _spawn_trail()
	await get_tree().physics_frame
	var bonus := GameState.level - 1
	var expected_damage := SWORD.value_at(2) + bonus * GameState.progression.damage_per_level
	var expected_health := ARMOR.value_at(1) + bonus * GameState.progression.health_per_level
	_check(is_equal_approx(level.player.base_damage, expected_damage), "Espada nv 2 + nível 2 → ATK %.0f" % expected_damage)
	_check(is_equal_approx(level.player.health.max_health, expected_health), "Armadura nv 1 + nível 2 → vida %.0f" % expected_health)
	_check(is_equal_approx(level.player.damage_reduction, ARMOR.secondary_at(1)), "Armadura nv 1 → redução %.0f%%" % (ARMOR.secondary_at(1) * 100.0))
	level.queue_free()
	await get_tree().physics_frame


func _test_death_respawn() -> void:
	print("
[Morte: volta à fogueira]")
	GameState.reset()
	var level := _spawn_trail()
	await get_tree().physics_frame
	var start := level.player.global_position
	level.player.global_position = start + Vector3(0.0, 0.5, -6.0)
	level.run_gold = 35
	var info := DamageInfo.new()
	info.amount = 9999.0
	level.player.hurtbox.receive_hit(info)
	_check(level.player.health.is_dead, "golpe fatal mata o herói")
	await level.player_respawned
	var expected := floori(35 * level.rewards.death_keep_fraction)
	_check(GameState.gold == expected and level.run_gold == 0, "guarda %d de 35 de ouro não guardado (50%%)" % expected)
	_check(not level.player.health.is_dead and is_equal_approx(level.player.health.current_health, level.player.health.max_health),
			"volta com a vida cheia")
	_check(level.player.global_position.distance_to(start) < 1.5, "volta ao ponto de partida (sem fogueira acesa)")
	level.queue_free()
	await get_tree().physics_frame


func _test_pause() -> void:
	print("\n[Pausa]")
	var menu := PAUSE_SCENE.instantiate() as PauseMenu
	add_child(menu)
	_check(get_tree().paused, "abrir a pausa congela o jogo")
	menu._resume()
	_check(not get_tree().paused, "Continuar descongela")
	await get_tree().process_frame


## Eventos dinâmicos: socorro ao cavaleiro (salvar dá reputação e ouro), mundo aberto e preços.
func _test_world_events() -> void:
	print("
[Mundo aberto, eventos e reputação]")
	GameState.reset()
	var level := _spawn_trail()
	level.dynamic_events = false
	level.events.enabled = false
	await get_tree().create_timer(1.0).timeout
	_check(level.side_areas.size() == 4, "4 vales laterais abertos para explorar")
	var area := level.side_areas[0]
	var floor_height := level.terrain.height_at(area.x, area.z)
	var route_height := level.route_point(level.progress_of(area)).y
	_check(absf(floor_height - route_height) < 6.0, "área lateral é chão andável, não penhasco (%.1f m)" % (floor_height - route_height))
	_check(level.events.start_event(EventDirector.Kind.RESCUE_KNIGHT), "começa um pedido de socorro")
	var npc := level.get_node_or_null(^"Npc") as WorldNpc
	_check(npc != null and npc.is_alive(), "o cavaleiro aparece no lugar do evento")
	var attackers := level.events._enemies.duplicate()
	_check(attackers.size() >= 3 and (attackers[0] as Enemy).target == npc, "inimigos cercam o cavaleiro")
	await get_tree().create_timer(1.6).timeout  # terminam de surgir (invulneráveis até lá)
	var gold := GameState.gold
	for enemy: Enemy in attackers:
		var info := DamageInfo.new()
		info.amount = 99999.0
		info.source = level.player
		enemy.hurtbox.receive_hit(info)
	await get_tree().create_timer(0.3).timeout
	_check(not level.events.is_active() and GameState.reputation_of(&"ordem_grifo") == 12, "salvar o cavaleiro dá reputação com a Ordem (+12)")
	_check(GameState.gold > gold, "e ouro de recompensa")
	GameState.change_reputation(&"guilda_mercadores", 100)
	_check(GameState.price_of(SWORD) < SWORD.cost_for_next(GameState.level_of(SWORD)), "reputação alta com a Guilda baixa os preços")
	GameState.change_reputation(&"guilda_mercadores", -200)
	_check(GameState.price_of(SWORD) > SWORD.cost_for_next(GameState.level_of(SWORD)), "reputação baixa encarece")
	GameState.change_reputation(&"ordem_grifo", -100)
	var kinds := {}
	for i: int in 40:
		kinds[level.events._pick_kind()] = true
	_check(not kinds.has(EventDirector.Kind.RESCUE_KNIGHT), "Ordem hostil não pede mais ajuda")
	level.queue_free()
	await get_tree().process_frame
	GameState.reset()


func _spawn_trail() -> WorldLevel:
	var level := TRAIL_SCENE.instantiate() as WorldLevel
	level.show_element_select = false
	level.capture_mouse = false
	level.cinematics = false
	add_child(level)
	return level


func _check(condition: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		_failures += 1
