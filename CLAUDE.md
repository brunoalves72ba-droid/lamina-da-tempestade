# CLAUDE.md — Regras do projeto

RPG de ação 3D para PC (medieval sombrio, visual realista) com movimento livre em 3ª pessoa, combate de ataque/parry/bloqueio/esquiva, um percurso com clareiras de combate e um herói conjurador de raios (poderes elétricos alimentados por Carga Estática). XP e níveis fazem surgir mais inimigos.
O design completo está em [GDD.md](GDD.md). **Leia o GDD antes de implementar qualquer sistema** e mantenha-o atualizado quando uma decisão de design mudar.

## Ambiente

- **Engine:** Godot **4.7.2 stable**, somente **GDScript** (sem C#, sem GDExtension no MVP).
- **Renderizador:** Forward+ · driver D3D12 (Windows) · física **Jolt**.
- **Executável (console, para validação):**
  `C:/Users/Noteb/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
- **Validar o projeto após mudanças** (erros de parse, recursos quebrados):
  ```bash
  "$GODOT" --headless --path . --import --quit
  "$GODOT" --headless --path . --quit-after 120
  ```
  Para checar um script isolado: `"$GODOT" --headless --path . --check-only --script res://caminho/script.gd`
- **Testes automáticos** (código de saída 0 = passou):
  ```bash
  "$GODOT" --headless --path . --fixed-fps 60 res://tests/auto_combat_test.tscn
  "$GODOT" --headless --path . --fixed-fps 60 res://tests/auto_trail_test.tscn
  "$GODOT" --headless --path . --fixed-fps 60 res://tests/auto_meta_test.tscn
  ```
  - `auto_combat_test`: mecânicas no sandbox (parry, contra-ataque, combo, Besteiro, Dardo/Passo, elementos, Carga, poderes, Elite, andar, esquiva, bloqueio).
  - `auto_trail_test`: piloto automático percorre `trail_01` inteira (clareiras, fogueiras, XP, santuário). Dirige o herói por `Player.use_scripted_input`/`scripted_move_input`, relativo a `view_yaw`.
  - `auto_meta_test`: loja, save, XP/níveis, upgrades + nível no herói, morte com volta à fogueira, pausa.
  - Rode os três depois de qualquer mudança em combate, inimigos, progressão ou fase. **Todo teste começa com `SaveManager.persist = false` e `GameState.reset()`**, para nunca gravar no save do jogador.
- **Gerar o .exe do Windows** (templates 4.7.2 já instalados em `%APPDATA%/Godot/export_templates/4.7.2.stable`):
  ```bash
  "$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/LaminaDaTempestade.exe
  ```
  `build/` está no `.gitignore`. Builds oficiais não aceitam abrir uma cena pela linha de comando; para testar uma cena do pacote exportado use `"$GODOT" --main-pack build/windows/LaminaDaTempestade.exe res://caminho/cena.tscn`.
- **Cena principal:** `scenes/main/main_menu.tscn` (F5). Fase: `scenes/levels/trail_01.tscn`. Sandbox de combate: `tests/sandbox_combat.tscn` (F6). Troque de cena só por `Scenes.go()` (`scripts/main/scenes.gd`), que também despausa e zera o hitstop.
- Nos testes, espere sempre em **tempo de jogo** (`create_timer(t, true, true)`), porque o hitstop desacelera o tempo. Conecte ou desligue `auto_attack` *antes* de esperar um sinal que pode disparar durante outra espera; os dois bugs intermitentes do M3 vieram de avisos perdidos assim.
- `--script` **não carrega autoloads**: para rodar algo que usa `Events`/`GameState`, rode uma cena (`res://...tscn`), não um script solto.
- Os avisos "ObjectDB instances were leaked" ao sair vêm do cache de sons sintetizados (`SfxLibrary`) e são esperados.
- Nunca edite nada dentro de `.godot/` nem arquivos `*.import`; são gerados pelo editor.
- O projeto está dentro do OneDrive. Se aparecerem erros de arquivo travado ou de import, a primeira suspeita é a sincronização do `.godot/`.
- **Desempenho:** a máquina de desenvolvimento tem GPU integrada (Intel Iris Xe; o D3D12 a reporta como "dedicada", por isso `GameState.is_integrated_gpu()` também olha o nome). Meça FPS na janela (não headless) antes de aceitar efeito novo. O gargalo histórico foi o shader do terreno (texturas por pixel): mantenha `shaders/terrain.gdshader` com poucas leituras e desvio por peso.
- **Git:** repositório local. `main` = MVP sobre trilhos (commit `e00443a`); `mundo-livre` = reescrita atual. Faça commits só quando o usuário pedir.

## Estrutura de pastas

```
assets/      environment/ (CC0 Poly Haven: hdri, textures, models), characters/mixamo/ (nada de lógica)
data/        recursos .tres com TODOS os números de balanceamento
scenes/      main/, levels/, player/, enemies/, combat/, vfx/, camera/
scripts/     autoload/, components/, player/, enemies/, world/, camera/, combat/, resources/, audio/, vfx/, main/
shaders/     shaders próprios (terreno)
ui/          hud/, menus/, upgrade_shop/, theme/ (cena + script juntos)
tests/       sandbox e testes automáticos
```

- Scripts de gameplay ficam em `scripts/` espelhando a pasta da cena em `scenes/`. Exceção: UI mantém `.tscn` e `.gd` juntos em `ui/`.
- Toda nova mecânica ganha (ou reaproveita) uma cena em `tests/` que permite testá-la sozinha com F6.

## Estilo de GDScript

- **Tipagem estática obrigatória** em variáveis, parâmetros, retornos e arrays (`Array[Enemy]`). Use `:=` só quando o tipo é óbvio pelo lado direito.
- Nomes: arquivos e pastas `snake_case`; `class_name` e nós em `PascalCase`; funções/variáveis `snake_case`; constantes e valores de enum `SCREAMING_SNAKE_CASE`; privados com prefixo `_`.
- Sinais no particípio passado: `died`, `attack_telegraphed`, `parry_succeeded`.
- **Identificadores em inglês**; comentários e textos de UI em **português**.
- Ordem dentro do script (guia oficial do Godot): `class_name` → `extends` → doc comment → sinais → enums → constantes → `@export` → variáveis públicas → privadas → `@onready` → `_init/_ready/_process/_physics_process` → métodos públicos → privados.
- Referências a nós filhos via `@onready var x: Tipo = %NomeUnico` (Unique Name) — evite caminhos longos `$A/B/C`.
- Funções curtas; um script = uma responsabilidade. Prefira **composição** (nós componentes) a herança profunda. Herança só para variantes de cena (`enemy_base.tscn` → variantes).
- Sem `get_node` por string dinâmica, sem `find_child` em `_process`, sem alocação dentro de `_physics_process` quando evitável.
- `assert()` para pré-condições de desenvolvimento; `push_warning`/`push_error` para estados inesperados em runtime. Nada de `print` esquecido — use `print_debug` atrás de uma flag de debug.

## Arquitetura

- **"Call down, signal up":** pais chamam métodos dos filhos; filhos avisam os pais por sinais. Irmãos nunca se referenciam diretamente.
- **Signal bus** `Events` (autoload) apenas para eventos globais entre sistemas desacoplados (`enemy_died`, `wave_cleared`, `gold_changed`, `encounter_started`). Eventos locais usam sinais do próprio nó.
- **Autoloads permitidos:** `Events`, `AudioManager` (canais de efeitos com limite e voice stealing), `GameState` (ouro, nível, upgrades, espadas, reputação, história, mira, New Game+), `Music` (trilha sonora com transição: `Music.play_track(&"explore"|&"combat"|&"boss")`), `Pools` (Object Pooling), `SaveManager` (save v2 + `autosave()`). Novo autoload só com justificativa no GDD (§17).
- **Object Pooling:** nó criado e destruído com frequência (efeito, projétil, número de dano) vem de `Pools.acquire(chave, fábrica, pai)` e volta com `Pools.release(nó)`/`Pools.release_after(nó, s)`; tweens desses nós via `Pools.tween(nó)`. Nunca `queue_free()` num nó do pool.
- **Física do raio e gore:** dano de poder sai de `Player.build_power_info()` (marca `is_power` e `shock_time`; a tempestade soma bônus). Condução só por `Conduction.discharge()`; sangue/desmembramento só por `Gore` (respeita `GameState.gore_enabled`). Clima e hora: `Weather` (cria a `WorldLevel`); leia `GameState.storm_intensity`/`night_factor`, nunca o nó.
- **Mundo aberto:** eventos só pelo `EventDirector` (a `WorldLevel` cria; `dynamic_events` desliga) e NPCs `WorldNpc` (têm `HealthComponent`/`Hurtbox` com esses nomes, então `Enemy.set_target(npc)` funciona). Chances de IA vêm do `EnemyData` (grupos "Visual demoníaco" e "IA"); testes usam `block_chance_override`.
- **Fluxo de telas:** menus trocam de cena com `Scenes.go()`; fases carregam com `LoadingScreen.go()` (carregamento em segundo plano). O modo da partida vem de `GameState.launch_mode` (&"story"/&"arena") e a introdução de `GameState.play_intro`. Cutscenes só pelo `Cutscene` da fase (`cinematics` desliga nos testes); slow-motion delas via `Hitstop`.
- **Espadas e loja:** espadas são `SwordItem` em `data/swords/` (troca: `Player.equip_sword`, aplicada pela fase a partir de `GameState.equipped_sword`); evolução de poderes são `UpgradeData` `power_*` lidas pelo `PowerCaster`.
- **Capturas/cenas de depuração** que abrem a trilha devem pôr `SaveManager.persist = false` antes, senão gravam no save real do jogador.
- **Lambdas em timers:** capture o `get_instance_id()` e use `instance_from_id()`, nunca o próprio nó (ele pode ser liberado antes).
- **História:** objetivos e falas ficam em `data/story/arc_N.tres` (`StoryArc`/`StoryObjective`); o `StoryDirector` só escuta `Events` (`zone_cleared`, `checkpoint_reached`, `boss_defeated`, `shrine_reached`). Sempre deve haver um objetivo na HUD.
- **Dados fora do código:** dano, HP, cooldowns, janelas de tempo, custos e composição de ondas vivem em `Resource`s customizados (`WeaponData`, `EnemyData`, `WaveData`, `UpgradeData`, `SkillData`) salvos em `data/`. Nenhum número mágico de balanceamento no script.
- **Máquinas de estado** para jogador e inimigos: um nó `StateMachine` com estados como nós filhos (`Idle`, `Attack`, `Parry`, `Block`, `Dodge`, `Stunned`, `Stagger`…). Transições explícitas, nunca booleanos soltos (`is_attacking`, `is_parrying`…).
  - Estados herdam de `PlayerState`/`EnemyState` e acessam o dono pelo `owner`. Golpes recebidos passam por `PlayerState.handle_hit()` (é assim que o Parry intercepta o dano).
  - Não troque de estado de dentro de um callback de colisão de *outra* máquina; marque um flag e deixe o próprio estado transicionar no `physics_update` (ex.: `Enemy.strike_was_parried`).
- **Parry e Hitbox:** a `Hitbox` monitora sempre e resolve o acerto no mesmo frame em que é armada, para a janela de parry ser exata. O atacante passa `DamageInfo.on_parried` (Callable); o defensor chama ao aparar, sem um conhecer o tipo do outro.
- **Movimento do herói:** estados pedem movimento a cada frame com `Player.locomote(speed)` (WASD relativo à câmera) ou `Player.push(velocidade)` (avanço, esquiva, empurrão); o `Player` aplica aceleração, gravidade, `move_and_slide` e o giro do corpo. A câmera (`ThirdPersonCamera`) escreve `Player.view_yaw` todo frame.
- **Mira:** `Targeting` (filho do Player) tem alvo suave (mais perto) e travado (`locked`). `set_target()` e `cycle()` travam. Dardo/Passo Relâmpago só saem com alvo travado.
- **Fase de percurso:** `WorldLevel` monta a trilha (curva dos `waypoints`), `TrailTerrain` (terreno + colisão por heightmap + `height_at`), `PropScatter` (cenário a partir de `PropEntry`), `CombatZone` (barreira + ondas, herda `Encounter`), `Checkpoint` (fogueiras), patrulhas, XP, morte/volta e vitória. `WaveSpawner` cria ondas a partir de `WaveData`/`SpawnEntry` e aplica a escala do nível (`ProgressionData`); `AttackTokenManager` garante um ataque por vez (inimigos revividos precisam de `register()` de novo).
- **Inimigos:** movimento em `Enemy._desired_velocity()` (perceber → correr → cercar de lado; avançar durante o aviso; empurrão ao cambalear). Golpe forte faz cambalear (`Stagger`) quem não tem `has_poise`.
- **Golpes à distância** (Dardo de Raio, virote) acertam chamando `Hurtbox.receive_hit()` diretamente no fim do voo, sem Area3D, para o tempo de impacto ser exato.
- **Progresso:** `GameState` guarda ouro, nível/XP (`add_xp`, `leveled_up`), níveis de upgrade (`level_of`, `try_buy`), elemento e qualidade gráfica; `SaveManager` grava/lê JSON versionado. A fase aplica os upgrades no herói com `Player.apply_stats()`; nunca altere os `.tres` em tempo de execução.
- **Menus** (pausa, resultado, loja, menu principal) são montados em código com `MenuKit` (`ui/theme/menu_kit.gd`), para manter o mesmo visual. Telas que funcionam com o jogo pausado usam `process_mode = ALWAYS`.
- **Sons** via `SfxLibrary.play(node, &"nome")` (ou `Events.sfx_requested`): quem toca é o `AudioManager` (20 canais, limite de cópias e prioridade por som, voice stealing). Tabela em `SfxLibrary.SOUNDS` (arquivos, volume, cópias, prioridade). Áudio novo só CC0, com crédito no GDD §16 — e só quando o usuário pedir (áudio está em espera).
- **Componentes reutilizáveis** em `scripts/components/`: `HealthComponent`, `Hitbox`, `Hurtbox`, `Cooldown`. Dano sempre trafega como um objeto `DamageInfo` (quantidade, elemento, se é golpe forte, origem).
- **Efeitos elétricos:** todo raio visual sai de uma cena reutilizável `scenes/vfx/lightning_arc.tscn` que recebe origem, destino, cor e duração. Poderes, Descarga do parry, Dardo e Passo Relâmpago só instanciam essa cena; nenhum sistema desenha raio por conta própria. A cor vem do elemento da espada.
- **Outros efeitos:** use `Vfx` (`scripts/vfx/vfx.gd`, funções estáticas "dispara e esquece": `sparks`, `shockwave`, `lightning_strike`, `slash_arc`, `scorch`, `ground_warning`, `charge_crackle`, `ash_burst`, `flash_light`). Luzes (`flash_light`) só em impactos importantes — a GPU de referência é integrada. Rastro da espada: `WeaponTrail`; imagens residuais e desintegração: `AnimatedBody.afterimage()`/`disintegrate()`.
- **Tempo:** hitstop e câmera lenta alteram `Engine.time_scale` exclusivamente via `Hitstop.apply()` (`scripts/combat/hitstop.gd`, classe estática, não é autoload). Efeitos sobrepostos usam a menor escala. Timers/Tweens de UI devem ignorar a escala de tempo (`Timer.ignore_time_scale`, `Tween.set_ignore_time_scale`).
- **Game feel** (hitstop, tremor, finisher, Descarga visual) fica no nó `GameFeel` da fase, que só reage a sinais do `Events`. Sistemas de combate não chamam efeitos diretamente; emitem o evento.
- **Poderes de raio:** dados em `PowerData` (`data/powers/`), execução em `PowerCaster` (filho do Player), estado `Power` para preparação/recuperação. A Carga fica em `StaticCharge`. Elementos: `Element.multiplier()` e `Element.color()`, aplicados pelo defensor no `DamageInfo.element_multiplier`.

## Entrada

Use **somente ações do InputMap**, nunca teclas cruas no código.

| Ação | Teclas |
|---|---|
| `attack` | Botão esquerdo do mouse, J |
| `parry` | Botão direito do mouse, K |
| `move_forward` / `move_back` / `move_left` / `move_right` | W / S / A / D |
| `sprint` | Shift |
| `dodge` | Espaço |
| `lock_on` | Q, botão do meio do mouse |
| `target_prev` | roda do mouse para cima |
| `target_next` | Tab, roda do mouse para baixo |
| `interact` | E (reservado) |
| `skill_1` / `skill_2` / `skill_3` | 1 / 2 / 3 |
| `pause` | Esc, P |
| `debug_reset` | R (só em cenas de teste) |
| `ui_accept` / `ui_cancel` | padrões do Godot |

Input de combate usa **buffer** (o aperto vale por uma janela curta definida em dados) — nunca descarte um input porque chegou alguns frames cedo.

## Camadas de colisão (Física 3D)

| # | Nome | Uso |
|---|---|---|
| 1 | `world` | chão, paredes, cenário |
| 2 | `player_hurtbox` | área que recebe dano do jogador |
| 3 | `enemy_hurtbox` | área que recebe dano dos inimigos |
| 4 | `player_hitbox` | golpes/projéteis do jogador (máscara: 3) |
| 5 | `enemy_hitbox` | golpes/projéteis dos inimigos (máscara: 2) |

Nomeie as camadas em *Project Settings → Layer Names* e use esses nomes nos comentários.

## Cenas (.tscn) escritas como texto

- Pode criar/editar `.tscn` e `.tres` como texto, mas mantenha-os simples e válidos: **não invente `uid://`** (omita; o Godot regenera) e não deixe `ext_resource` órfão.
- Depois de criar ou editar cenas, rode a validação headless acima e corrija qualquer erro antes de seguir.
- **Personagens animados:** `AnimatedBody` (`scripts/characters/animated_body.gd`, nó `%Body` dentro de `%Model`) carrega o modelo da Mixamo (herói: `model_scene` no .tscn; inimigos: `EnemyData.model`, via `setup()`) e a biblioteca `assets/characters/animations/combat_library.res`. Locomoção por `update_locomotion()`; ações por `play_action*` (use `play_action_hit_at` para golpes, com o instante de impacto em `AnimatedBody.IMPACT_TIME`). Armas em `Equipment` (presas a ossos `mixamorig_*`; na mão direita a lâmina sai em +X). Brilho por `flash()`/`set_rim()` (shader `shaders/rim_overlay.gdshader`). Papel do inimigo em `EnemyData.model_variant` (SOLDIER/CROSSBOWMAN/ELITE/BOSS) e golpe em `strike_animation`; chefões têm `EnemyData.boss` (`BossData`) e ganham um `BossBrain` (estado `Power`).
- **Mudou a seleção de animações?** Os `.fbx` ficam em `assets/characters/animations/` (com o nome lógico); refaça a biblioteca com `"$GODOT" --headless --path . --script res://tools/build_animation_library.gd` (tira o root motion e marca loops). Os `.fbx` de animação e `tools/` ficam fora do `.exe`.
- **Cenário realista:** assets CC0 do Poly Haven em `assets/environment/` (glTF 1k, texturas 2k). Mapas `*_nor_gl_*` são importados como normal map. Prefira modelos com poucos polígonos (a GPU é integrada) e use `visibility_range_end` em objetos espalhados.

## Fluxo de trabalho

- Trabalhe **um milestone por vez** (ver GDD §12). Cada um termina com sua cena de teste e todos os critérios de aceite marcados.
- Ao concluir uma tarefa, diga como testar (cena + teclas) e o que **não** foi verificado.
- Mudou um número de balanceamento ou uma regra? Atualize o `.tres` **e** a tabela correspondente no GDD.
- Não adicione plugins/addons da Asset Library sem aprovação.
- **Originalidade:** jogos citados como referência (ex.: Iron Blade, God of War) inspiram só mecânicas. Nunca use nomes, personagens, arte, modelos, música, sons ou layout de fases deles.
