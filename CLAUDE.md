# CLAUDE.md — Regras do projeto

RPG de ação 3D para PC (medieval sombrio) com combate rítmico de ataque/parry, movimentação sobre trilhos entre encontros e um herói conjurador de raios (poderes elétricos alimentados por Carga Estática).
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
- **Testes automáticos de combate** (código de saída 0 = passou):
  ```bash
  "$GODOT" --headless --path . --fixed-fps 60 res://tests/auto_combat_test.tscn
  "$GODOT" --headless --path . --fixed-fps 60 res://tests/auto_rail_test.tscn
  "$GODOT" --headless --path . --fixed-fps 60 res://tests/auto_meta_test.tscn
  ```
  `auto_meta_test` cobre loja, save, upgrades, ouro e pausa. **Todo teste começa com `SaveManager.persist = false` e `GameState.reset()`**, para nunca gravar no save do jogador.
  `auto_combat_test` cobre as mecânicas no sandbox; `auto_rail_test` joga a `arena_01` inteira com um piloto automático. Rode os dois depois de qualquer mudança em combate, inimigos ou fase. Toda mecânica nova ganha checagens num deles (ou num irmão em `tests/`).
- **Gerar o .exe do Windows** (templates 4.7.2 já instalados em `%APPDATA%/Godot/export_templates/4.7.2.stable`):
  ```bash
  "$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/LaminaDaTempestade.exe
  ```
  `build/` está no `.gitignore`. Builds oficiais não aceitam abrir uma cena pela linha de comando; para testar uma cena do pacote exportado use `"$GODOT" --main-pack build/windows/LaminaDaTempestade.exe res://caminho/cena.tscn`.
- **Cena principal:** `scenes/main/main_menu.tscn` (F5). Fase: `scenes/levels/arena_01.tscn`. Sandbox de combate: `tests/sandbox_combat.tscn` (F6). Troque de cena só por `Scenes.go()` (`scripts/main/scenes.gd`), que também despausa e zera o hitstop.
- Nos testes, espere sempre em **tempo de jogo** (`create_timer(t, true, true)`), porque o hitstop desacelera o tempo. Conecte ou desligue `auto_attack` *antes* de esperar um sinal que pode disparar durante outra espera; os dois bugs intermitentes do M3 vieram de avisos perdidos assim.
- `--script` **não carrega autoloads**: para rodar algo que usa `Events`/`GameState`, rode uma cena (`res://...tscn`), não um script solto.
- Os avisos "ObjectDB instances were leaked" ao sair vêm do cache de sons sintetizados (`SfxLibrary`) e são esperados.
- Nunca edite nada dentro de `.godot/` nem arquivos `*.import`; são gerados pelo editor.
- O projeto está dentro do OneDrive. Se aparecerem erros de arquivo travado ou de import, a primeira suspeita é a sincronização do `.godot/`.

## Estrutura de pastas

```
assets/      modelos, texturas, materiais, áudio, fontes (nada de lógica)
data/        recursos .tres com TODOS os números de balanceamento
scenes/      main/, levels/, player/, enemies/, combat/, vfx/
scripts/     autoload/, components/, player/, enemies/, rail/, combat/, resources/, audio/
ui/          hud/, menus/, upgrade_shop/, theme/ (cena + script juntos)
tests/       cenas sandbox para testar sistemas isolados
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
- **Autoloads permitidos:** `Events`, `GameState` (ouro, níveis de upgrade, elemento escolhido), `SaveManager`. Novo autoload só com justificativa no GDD.
- **Dados fora do código:** dano, HP, cooldowns, janelas de tempo, custos e composição de ondas vivem em `Resource`s customizados (`WeaponData`, `EnemyData`, `WaveData`, `UpgradeData`, `SkillData`) salvos em `data/`. Nenhum número mágico de balanceamento no script.
- **Máquinas de estado** para jogador e inimigos: um nó `StateMachine` com estados como nós filhos (`Idle`, `Attack`, `Parry`, `Stunned`, `Travel`…). Transições explícitas, nunca booleanos soltos (`is_attacking`, `is_parrying`…).
  - Estados herdam de `PlayerState`/`EnemyState` e acessam o dono pelo `owner`. Golpes recebidos passam por `PlayerState.handle_hit()` (é assim que o Parry intercepta o dano).
  - Não troque de estado de dentro de um callback de colisão de *outra* máquina; marque um flag e deixe o próprio estado transicionar no `physics_update` (ex.: `Enemy.strike_was_parried`).
- **Parry e Hitbox:** a `Hitbox` monitora sempre e resolve o acerto no mesmo frame em que é armada, para a janela de parry ser exata. O atacante passa `DamageInfo.on_parried` (Callable); o defensor chama ao aparar, sem um conhecer o tipo do outro.
- **Fase sobre trilhos:** `Level` orquestra `RailController` (move o herói pela curva), `WaveSpawner` (cria ondas a partir de `WaveData`/`SpawnEntry`) e `AttackTokenManager` (um ataque por vez). Inimigos ficam no grupo `Enemy.GROUP`; `Targeting` (filho do Player) escolhe o alvo a partir dele.
- **Golpes à distância** (Dardo de Raio, virote) acertam chamando `Hurtbox.receive_hit()` diretamente no fim do voo, sem Area3D, para o tempo de impacto ser exato.
- **Progresso:** `GameState` guarda ouro, níveis de upgrade (`level_of`, `try_buy`) e elemento; `SaveManager` grava/lê JSON versionado. A fase aplica os upgrades no herói com `Player.apply_stats()`; nunca altere os `.tres` em tempo de execução.
- **Menus** (pausa, resultado, loja, menu principal) são montados em código com `MenuKit` (`ui/theme/menu_kit.gd`), para manter o mesmo visual. Telas que funcionam com o jogo pausado usam `process_mode = ALWAYS`.
- **Sons placeholder** via `SfxLibrary.play(node, &"nome")` (síntese, sem arquivos) até o M4.
- **Componentes reutilizáveis** em `scripts/components/`: `HealthComponent`, `Hitbox`, `Hurtbox`, `Cooldown`. Dano sempre trafega como um objeto `DamageInfo` (quantidade, elemento, se é golpe forte, origem).
- **Efeitos elétricos:** todo raio visual sai de uma cena reutilizável `scenes/vfx/lightning_arc.tscn` que recebe origem, destino, cor e duração. Poderes, Descarga do parry, Dardo e Passo Relâmpago só instanciam essa cena; nenhum sistema desenha raio por conta própria. A cor vem do elemento da espada.
- **Tempo:** hitstop e câmera lenta alteram `Engine.time_scale` exclusivamente via `Hitstop.apply()` (`scripts/combat/hitstop.gd`, classe estática, não é autoload). Efeitos sobrepostos usam a menor escala. Timers/Tweens de UI devem ignorar a escala de tempo (`Timer.ignore_time_scale`, `Tween.set_ignore_time_scale`).
- **Game feel** (hitstop, tremor, finisher, Descarga visual) fica no nó `GameFeel` da fase, que só reage a sinais do `Events`. Sistemas de combate não chamam efeitos diretamente; emitem o evento.
- **Poderes de raio:** dados em `PowerData` (`data/powers/`), execução em `PowerCaster` (filho do Player), estado `Power` para preparação/recuperação. A Carga fica em `StaticCharge`. Elementos: `Element.multiplier()` e `Element.color()`, aplicados pelo defensor no `DamageInfo.element_multiplier`.

## Entrada

Use **somente ações do InputMap**, nunca teclas cruas no código.

| Ação | Teclas |
|---|---|
| `attack` | Botão esquerdo do mouse, J |
| `parry` | Botão direito do mouse, K |
| `target_prev` | A, roda do mouse para cima |
| `target_next` | D, roda do mouse para baixo |
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
- **Arte com primitivas:** personagens e cenário são compostos de `MeshInstance3D` com primitivas (cilindros, esferas, cápsulas, caixas) dentro do nó `Model`. Scripts só acessam partes com nome único (`%BodyMesh`, `%SwordPivot`, `%Helmet`, `%Shield`...). As variações de inimigo saem de `EnemyData.model_variant`. Peças dentro de `Ruins` ganham colisão automática ao carregar a fase.

## Fluxo de trabalho

- Trabalhe **um milestone por vez** (ver GDD §12). Cada um termina com sua cena de teste e todos os critérios de aceite marcados.
- Ao concluir uma tarefa, diga como testar (cena + teclas) e o que **não** foi verificado.
- Mudou um número de balanceamento ou uma regra? Atualize o `.tres` **e** a tabela correspondente no GDD.
- Não adicione plugins/addons da Asset Library sem aprovação.
- **Originalidade:** jogos citados como referência (ex.: Iron Blade) inspiram só mecânicas. Nunca use nomes, personagens, arte, modelos, música, sons ou layout de fases deles.
