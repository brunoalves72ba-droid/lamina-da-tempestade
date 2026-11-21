# GDD — Documento de Design

> **Título provisório:** "Lâmina da Tempestade" · **Plataforma:** PC (Windows), teclado + mouse · **Engine:** Godot 4.7.2
> **Status:** MVP sobre trilhos concluído em 20/11/2026 (commit `e00443a`) · **reescrito para movimento livre em 21/11/2026** (branch `mundo-livre`) · Regras de código em [CLAUDE.md](CLAUDE.md)
> **Referências de mecânicas:** duelos com parry e loja (estilo Iron Blade) + exploração linear em 3ª pessoa com câmera por cima do ombro e mira travada (estilo God of War). Só as **mecânicas** servem de referência: nome, personagens, arte, música e fases são **originais**.

Todos os números deste documento são **valores iniciais de balanceamento**. Eles moram nos `.tres` de `data/` e devem ser ajustados jogando; quando mudarem, atualize as tabelas aqui.

---

## 1. Visão

Um RPG de ação 3D medieval sombrio, de visual realista, em que o herói **percorre a pé** uma trilha por um vale de floresta morta até um santuário. No caminho há **clareiras de combate** fechadas por uma barreira de raios: só se sai delas vencendo. O foco é o **duelo**: ler o aviso do inimigo, defender ou esquivar no tempo certo e punir com o contra-ataque.

O protagonista é um guerreiro **conjurador de raios**: a espada conduz eletricidade, e cada defesa perfeita e cada combo acumulam **Carga Estática**, que alimenta seus poderes de tempestade. Inimigos derrotados dão **ouro e experiência**; quanto mais o herói evolui, **mais inimigos surgem e mais fortes eles ficam**.

**Pilares**
1. **Leitura e timing** — todo ataque inimigo é avisado e pode ser aparado, bloqueado ou esquivado.
2. **Impacto** — cada golpe tem peso (hitstop, faíscas, estalo elétrico, flash de luz, cambalear).
3. **A tempestade como recompensa** — jogar bem carrega o herói; descarregar a tempestade é o clímax da clareira.
4. **Jornada que cresce** — XP e níveis no caminho, ouro para o ferreiro, inimigos que acompanham a sua força.

## 2. Escopo atual

**Dentro**
- 1 percurso (`trail_01`, ~250 m) com 5 clareiras, 4 fogueiras de checkpoint, patrulhas e um santuário final.
- Herói conjurador de raios com movimento livre, corrida, esquiva, bloqueio, combo, parry, Dardo de Raio, Passo Relâmpago, 3 poderes e Carga Estática.
- 3 tipos de inimigo comum (Esqueleto, Vampira, Parasita) e 3 chefões com poderes (Grom, Mutante do Bosque, Guardião do Santuário), com perseguição, cerco, reações e os 3 elementos.
- Personagens reais da Mixamo (herói Paladino), efeitos visuais de poderes, impactos e desintegração; sons gravados e trilha sonora (exploração, combate, chefão).
- XP e níveis (persistentes), escala de inimigos pelo nível **e pelo equipamento comprado**, loja (Espada, Armadura), save em JSON, menus, pausa com qualidade gráfica, export para Windows.

**Fora (backlog, ver §13)**
- Mais percursos, itens equipáveis, troca de elemento em combate, gamepad, localização.

## 3. Controles

| Ação | Teclas | Observação |
|---|---|---|
| Andar | WASD | relativo à câmera |
| Câmera | mouse | gira em volta do herói (por cima do ombro) |
| Correr | Shift | não funciona com alvo travado |
| Esquivar | Espaço | invencível nos primeiros 0,3 s; também cancela a recuperação de um golpe |
| Travar alvo | Q / botão do meio | trava no inimigo mais perto do centro da tela; de novo destrava |
| Trocar alvo travado | Tab / roda do mouse | esquerda ↔ direita na tela |
| Atacar | LMB / J | combo de 3 golpes; com alvo travado e distante: Dardo de Raio + Passo Relâmpago |
| Parry / Bloquear | RMB / K | toque no tempo certo = parry (§6.2); segurado = bloqueio |
| Poderes de raio | 1 / 2 / 3 | 1 e 2 com recarga; 3 exige Carga cheia |
| Pausa | Esc / P | continuar, gráficos, som, recomeçar, sair |

## 4. Loop de jogo

```
Menu principal → Escolha do elemento → Trilha
   Trilha: andar → patrulhas → Clareira (barreira, ondas) → Fogueira (cura, guarda ouro, salva) → ... → Santuário
→ Tela de resultado (ouro) → Ferreiro (loja) → Jogar de novo / Menu
```

- **XP:** cada inimigo dá XP; subir de nível cura por completo e aumenta vida (+8) e ATK (+1).
- **Ouro:** o ouro coletado fica "no bolso" até a próxima fogueira (ou o santuário), onde é guardado.
- **Morte:** o herói volta à última fogueira acesa (ou ao início), com vida cheia; guarda **50%** do ouro do bolso. A clareira em andamento recomeça.
- **Vitória (santuário):** guarda o ouro do bolso + **50** de bônus.

## 5. Movimento livre e câmera

- **Herói:** CharacterBody3D com gravidade. Andar **4,2 m/s**, correr **6,8 m/s**, aceleração/frenagem suaves, giro do corpo para a direção do movimento (12 rad/s). Nas ações de combate, vira na hora para o alvo próximo (até **3,5 m**, "mira suave"). Golpes avançam **0,6 m** se o alvo não estiver colado.
- **Esquiva:** **4 m** em 0,42 s (impulso que desacelera), invencível por **0,3 s**, intervalo mínimo 0,15 s.
- **Bloqueio:** segurar o botão de defesa depois da janela de parry. Anda a **1,8 m/s** e recebe só **30%** do dano, sem cambalear.
- **Atingido:** empurrão para trás (4 m/s, desacelerando) e 0,3 s sem agir.
- **Câmera:** `ThirdPersonCamera` por cima do ombro direito, braço de **3,6 m** com `SpringArm3D` (encurta em paredes), inclinação de −55° a 35°. Com alvo travado, gira sozinha para enquadrar herói e alvo. O WASD é relativo à rotação da câmera.
- **Alvos (`Targeting`):** sem travar, o alvo é o inimigo mais perto até **10 m** (anel azul). Travado (anel vermelho), vale até **20 m**; se o alvo morre, trava no próximo mais perto.

## 6. Combate

### 6.1 Ataque (combo)
- Corrente simples de **3 golpes**. Apertar `attack` durante a janela final de um golpe encadeia o próximo; parar reseta o combo após **0,6 s**.
- **Buffer de input:** **0,2 s**.
- **Tempos de cada golpe:** preparação **0,1 s** → ativo **0,1 s** → recuperação **0,3 s** (**0,45 s** no 3º golpe). Encadear o próximo golpe é possível durante a recuperação.
- **Atingido:** ao tomar dano o herói fica **0,3 s** sem agir (inputs feitos nesse tempo ficam no buffer).
- Multiplicadores de dano: golpe 1 = **1,0×**, golpe 2 = **1,0×**, golpe 3 = **1,6×** (conta como **golpe forte**).
- Atacar pode ser interrompido por `parry` a qualquer momento (prioridade ao parry).

### 6.2 Aviso e Parry
- Todo ataque inimigo tem um **aviso (telegraph) de 0,8 s** antes do impacto: ícone/brilho acima do inimigo na cor do aviso + som característico.
- **Janela de parry:** os últimos **0,25 s** antes do impacto.
- **Parry certo (Descarga):** dano bloqueado; a espada libera uma descarga que **atordoa o inimigo por 1,5 s** (ele fica envolto em arcos elétricos), com estalo, flash de luz e hitstop curto. Gera Carga (§6.6). O próximo golpe do jogador em um inimigo atordoado é um **contra-ataque**: **2,0×** de dano, conta como **golpe forte**.
- **Parry cedo (fora da janela):** o jogador fica **0,4 s** em recuperação sem poder defender de novo (anti-spam) e toma o dano normalmente se o golpe vier.
- **Sem parry:** dano integral (menos a redução da armadura).
- Projéteis do Besteiro também podem ser defendidos (mesma janela); o parry **anula o virote**, mas não atordoa o atirador.

### 6.3 Token de ataque
- Apenas **um inimigo ataca por vez**. Um gerenciador (`AttackTokenManager`) concede o token; o inimigo que o recebe faz o aviso e ataca, depois devolve o token.
- Intervalo entre ataques consecutivos (de qualquer inimigo): **1,0–2,0 s** (aleatório).
- Inimigos sem token ficam em guarda, mantendo a distância de combate do herói e se afastando uns dos outros. Só recebe o token quem está em posição (corpo a corpo: perto o bastante; Besteiro: longe o bastante).
- O intervalo fica em `data/combat/attack_tokens.tres`.

### 6.4 Seleção de alvo, Dardo de Raio e Passo Relâmpago
- Sempre existe um **alvo atual** (marcador no chão sob ele). Ao entrar no encontro, o alvo é o inimigo mais próximo do centro da tela.
- `target_prev` / `target_next` percorrem os inimigos vivos ordenados pela posição horizontal na tela.
- Quando o alvo morre, seleciona automaticamente o inimigo vivo mais próximo do jogador.
- **Alcance corpo a corpo:** **2,5 m**. Se `attack` for apertado com o alvo além disso:
  1. Se o **Dardo de Raio** estiver pronto, lança um raio da mão livre que atinge o alvo na hora (dano **0,5×**, cooldown **1,5 s**) e em seguida
  2. faz o **Passo Relâmpago**: avança até o alvo deixando um rastro elétrico (dash de **0,3 s**, até 12 m), terminando no golpe 1 do combo.
  Se o Dardo estiver em recarga, apenas faz o Passo Relâmpago.

### 6.5 Poderes de raio (teclas 1, 2, 3)

| # | Nome provisório | Efeito | Dano | Custo | Golpe forte? |
|---|---|---|---|---|---|
| 1 | Lâmina Voltaica | a espada se eletrifica num corte único no alvo; quebra a guarda (interrompe o aviso dele) | 2,5× | cooldown 6 s | sim |
| 2 | Corrente em Cadeia | raio que sai do alvo e salta para até **3** outros inimigos (até 6 m entre saltos) | 1,5× → 1,2× → 1,0× → 0,8× | cooldown 10 s | não |
| 3 | Fúria da Tempestade | invoca um raio do céu sobre o alvo, com choque em área de 3 m em volta | 4,0× no alvo, 1,5× na área | **Carga 100** (consome toda) | sim |

- O dano dos poderes escala com o ATK da espada e usa o **elemento da espada** (§7). Em inimigo atordoado, o poder também vale como contra-ataque.
- Cooldowns e Carga visíveis no HUD. Não há MP.
- Só a **Lâmina Voltaica** precisa estar ao alcance da espada: longe do alvo, ela faz o Passo Relâmpago antes. Corrente e Fúria são lançadas à distância.
- Tempos: preparação (parry cancela, recarga não começa) → efeito → recuperação. Lâmina 0,15 s / 0,25 s · Corrente 0,2 s / 0,3 s · Fúria 0,4 s / 0,4 s.
- Também podem ser usados na recuperação de um golpe do combo.

### 6.6 Carga Estática
- Recurso de **0 a 100**, com barra no HUD. Começa cada fase em 0 e **é mantido** entre os encontros.

| Ação | Carga |
|---|---|
| Golpe de combo que acerta | +4 |
| Parry certo | +20 |
| Contra-ataque | +10 |
| Poder 1 ou 2 que acerta | +5 |
| Receber dano | −10 |

- **Carga cheia:** herói e espada ficam envoltos em arcos elétricos e o ícone do poder 3 acende, deixando claro que a Fúria da Tempestade está disponível.
- Perder Carga ao tomar dano reforça o pilar de leitura: defender bem é o caminho para a tempestade.

### 6.7 Game feel
- **Hitstop:** golpe normal **0,05 s**; golpe forte **0,10 s** (via `Engine.time_scale`).
- **Finisher:** quando o **último inimigo de uma onda** morre por um **golpe forte**, a escala de tempo vai a **0,2** por **0,6 s reais**, a câmera aproxima do impacto e volta suavemente. Se o último golpe não for forte, não há finisher.
- Números de dano flutuantes; cor diferente para vantagem/desvantagem elemental.
- Golpes elétricos (Descarga, poderes, Dardo, Passo Relâmpago) acendem um flash curto de luz (`OmniLight3D`) e desenham arcos elétricos procedurais na cor do elemento.
- **Hitstop do parry:** 0,08 s. Golpe recebido: hitstop curto + tremor de câmera. Golpe forte dado: tremor leve. Fúria: tremor forte + clarão do céu.
- Inimigos e números de dano colados na câmera são escondidos para não tapar a visão.
- Valores em `data/combat/game_feel.tres`.

### 6.8 Status base do jogador

| Status | Valor |
|---|---|
| HP | 100 |
| ATK (dano base da espada) | 10 |
| Redução de dano (armadura) | 0% |

Sem regeneração de HP durante a fase no MVP; recupera **20% do HP máximo** ao limpar cada encontro.

## 7. Sistema elemental

Ciclo: **Divino > Demoníaco > Heroico > Divino**.

| Atacante → Defensor | Multiplicador |
|---|---|
| Vantagem | **1,5×** |
| Neutro (mesmo elemento) | **1,0×** |
| Desvantagem | **0,75×** |

- Aplica-se ao **dano do jogador** (elemento da espada vs. afinidade do inimigo). No MVP, ataques inimigos não usam elemento.
- O elemento da espada é **escolhido antes da fase** (os três disponíveis desde o início, tela com clique ou teclas 1/2/3) e não muda durante a fase.
- O elmo de cada inimigo brilha na cor da sua afinidade. Números de dano: vantagem em verde e maior, desvantagem em cinza e menor.
- Valores e cores em `data/combat/elements.tres`.
- A eletricidade é a **forma** do poder do herói; o elemento é a **afinidade**. Os raios assumem a cor do elemento da espada: raio dourado (Divino), roxo-avermelhado (Demoníaco) ou azul-aço (Heroico).
- **Cores-guia:** Divino = dourado/branco · Demoníaco = vermelho-escuro/roxo · Heroico = azul-aço. Inimigos usam a cor do elemento no material/contorno para leitura rápida.

## 8. Inimigos

| Tipo (dados) | Modelo Mixamo | HP | Dano | Comportamento | Ouro / XP |
|---|---|---|---|---|---|
| Esqueleto (`soldier`) | Skeletonzombie | 40 | 12 | corpo a corpo com espada e escudo, 1 golpe por token; é o que aparece de extra nas ondas | 10 / 20 |
| Vampira (`crossbowman`) | Vampire | 30 | 9 | mantém distância (~8 m), lança esfera de sangue (aviso de 0,7 s) | 12 / 25 |
| Parasita (`elite`) | Parasite | 150 | 25 | garras, golpe duplo (dois avisos seguidos), postura | 40 / 90 |

- Ciclo de ataque: aviso **0,7 s** → golpe ativo **0,1 s** → recuperação **0,45 s** (Vampira e Parasita: **0,6 s**) → guarda.
- Surgem em **0,8 s**; correm a ~4,5–4,8 m/s e circulam a ~1,8 m/s.
- Morte: animação de queda e, depois de ~1 s, o corpo **se desintegra** em brasas e cinzas na cor do elemento.

### 8.1 Chefões (`data/enemies/boss_*.tres`, poderes em `BossData`)

| Chefão | Modelo | Onde | HP | Poderes |
|---|---|---|---|---|
| Grom, o Quebra-Pontes | Warrok | última onda da clareira 3 (Ponte de Pedra) | 520 | Golpe no chão |
| Mutante do Bosque | Mutant (1,35×) | última onda da clareira 4 (Bosque Morto), com 1 Esqueleto | 680 | Salto e Golpe no chão; golpe duplo |
| Guardião do Santuário | Maw | última onda da clareira 5 (Portão do Santuário) | 950 | Rajada, Golpe no chão e Salto |

- **Rugido de entrada:** ao perceber o herói, o chefão ruge (onda de choque, tremor) e aparece a **barra de vida do chefão** no alto da tela; a música muda para o tema de chefão.
- **Poderes** (a cada 5,5–7 s, no lugar de um golpe normal; não podem ser aparados): círculo vermelho no chão que se enche até o impacto.
  - *Golpe no chão:* bate com as duas mãos; onda de choque de 4,2–5 m em volta dele. Saia do círculo ou esquive na hora do impacto (o bloqueio reduz o dano).
  - *Salto:* agacha, salta e cai onde o herói estava (círculo de ~3,6 m).
  - *Rajada:* 6 esferas de energia seguidas; cada uma pode ser aparada como o projétil da Vampira.
- **Fúria:** abaixo de 50% de vida ruge de novo, ganha contorno brilhante e usa poderes 40% mais rápido.
- Golpes normais continuam defendíveis por parry (atordoa o chefão por ~1,2 s). Chefões têm postura (não cambaleiam).
- Atordoado (após parry) recebe dano normalmente e não ataca; ao fim do atordoamento devolve o token.
- Cada inimigo tem `EnemyData` (status) + elemento definido na onda.

## 9. O percurso: `trail_01`

Vale de floresta morta à noite: céu estrelado (HDRI), lua com sombras suaves, neblina volumétrica, paredões de rocha, trilha de lama, troncos secos, tocos, samambaias e rochas reais (assets CC0 do Poly Haven em `assets/environment/`). O terreno é gerado pela trilha (`TrailTerrain`): fundo do vale plano, clareiras largas e paredões que guiam o jogador.

| Distância | O quê |
|---|---|
| 16 m | patrulha |
| 34 m | Clareira 1 — Clareira dos Corvos: 2 Soldados |
| 57 m | Fogueira 1 |
| 64 m | patrulha |
| 82 m | Clareira 2 — Vale das Cinzas: 2 Soldados + 1 Besteiro |
| 105 m | Fogueira 2 |
| 112 m | patrulha |
| 130 m | Clareira 3 — Ponte de Pedra: 2 Soldados, depois 1 Soldado + 2 Besteiros |
| 153 m | Fogueira 3 |
| 160 m | patrulha |
| 178 m | Clareira 4 — Bosque Morto: Elite + 2 Soldados |
| 200 m | Fogueira 4 |
| 205 m | patrulha |
| 222 m | Clareira 5 — Portão do Santuário: 3 Soldados + 1 Besteiro, depois Elite + 2 Soldados |
| ~250 m | Santuário (estátua gótica, ruínas de tijolo): vitória se todas as clareiras foram vencidas |

- **Clareiras:** ao entrar (até 14 m do centro) ergue-se uma barreira de raios com raio de 17 m; os inimigos surgem à frente, na direção da trilha. Vencer cura **25%** da vida.
- **Fogueiras:** acendem ao chegar perto ou ao passar por elas na trilha; curam tudo, guardam o ouro e salvam.
- **Escala pelo nível do herói** (`data/progression/progression.tres`): +0,5 inimigo extra por onda por nível (máx. +6), +6% de vida e +4% de dano dos inimigos por nível; patrulhas de 1 a 3 Soldados.
- **XP:** Soldado 20, Besteiro 25, Elite 90. Nível 2 pede 60 XP; cada nível seguinte pede 30% a mais (máx. nível 30).
- **Qualidade gráfica:** Baixo / Médio / Alto na pausa. GPU integrada começa no Baixo (medido numa Intel Iris Xe: ~42 FPS no Baixo, ~26 no Médio).

> A arena sobre trilhos (`arena_01`) foi aposentada em 21/11/2026; está no commit `e00443a`.

## 10. Progressão e loja

Dois upgrades lineares, **5 níveis** cada:

| Nível | Custo | Espada (ATK) | Armadura (HP máx. / redução de dano) |
|---|---|---|---|
| 0 | — | 10 | 100 / 0% |
| 1 | 50 | 12 | 120 / 3% |
| 2 | 100 | 14 | 140 / 6% |
| 3 | 175 | 16 | 160 / 9% |
| 4 | 275 | 18 | 180 / 12% |
| 5 | 400 | 20 | 200 / 15% |

- A loja aparece após a tela de resultado e também é acessível pelo menu principal.
- **Os inimigos acompanham o herói:** nível de ameaça = nível do herói + 0,5 × níveis de equipamento comprados (`GameState.threat_level()`). Cada nível de ameaça acima de 1 dá +6% de vida e +4% de dano aos inimigos e +0,5 inimigo extra por onda (máx. 6).
- Ouro total necessário para maximizar tudo: **2.000** (≈ 8–10 partidas vitoriosas — ajustar jogando).

## 11. Interface e áudio

**HUD:** barra de HP (canto superior esquerdo) · ouro · barra de **Carga Estática** · 3 ícones de poder com cooldown radial (o 3º acende com a Carga cheia) e o ícone do Dardo de Raio (canto inferior direito) · marcador do alvo atual · indicador de aviso sobre o inimigo que vai atacar · números de dano.

**Telas:** menu principal (Jogar, Loja, Sair) · escolha de elemento · pausa (Continuar, Som on/off, Sair para o menu) · resultado · loja.

**Áudio:** sons gravados com variações sorteadas e leve variação de tom (`SfxLibrary`), e trilha sonora com transição suave (autoload `Music`): exploração (menu e trilha), combate (clareira ativa) e chefão (introdução + loop). Créditos e licenças em §16.

**Save:** `user://save.json` com `version`, ouro, níveis de upgrade e último elemento escolhido. Salva ao sair da loja e ao fim de cada fase.

## 12. Milestones

### M1 — Núcleo do combate (sandbox) ✅ concluído em 20/11/2026
- [x] InputMap, camadas de colisão e autoloads (`Events`, `GameState`) configurados
- [x] Jogador placeholder com máquina de estados (`Idle`, `Attack`, `Parry`, `Hurt`, `Dead`)
- [x] Combo de 3 golpes com buffer de input
- [x] Inimigo de treino com aviso de 0,8 s (anel que se fecha + "!" + som) e ataque
- [x] Parry: certo bloqueia e atordoa; cedo gera recuperação; ausente toma dano
- [x] Contra-ataque 2× em inimigo atordoado
- [x] `HealthComponent`, `Hitbox`, `Hurtbox`, `DamageInfo`; barras de HP
- **Aceite:** em `tests/sandbox_combat.tscn`, as três situações de parry se comportam como no §6.2. Verificado por `tests/auto_combat_test.tscn` (14 checagens).
- Ficou para o M3 (game feel): hitstop e flash de luz da Descarga.

### M2 — Trilhos, ondas e alvos ✅ concluído em 20/11/2026
- [x] `Path3D` + `RailController` com estado `Travel` e câmera de viagem/combate (`CameraRig`)
- [x] `Encounter` + `WaveSpawner` lendo `WaveData` (`data/waves/arena01_e*.tres`)
- [x] Soldado, Besteiro (virote que pode ser aparado) e Elite básica; `AttackTokenManager`
- [x] Seleção de alvo (A/D, roda) e auto-seleção ao morrer
- [x] Dardo de Raio automático + Passo Relâmpago até alvo distante
- [x] Cura de 20% ao vencer cada encontro
- **Aceite:** atravessar `arena_01` com os 3 encontros, do início ao fim, sem travar. Verificado por `tests/auto_rail_test.tscn` (piloto automático, ~35 s de jogo) e pelas novas checagens em `tests/auto_combat_test.tscn` (24 no total).
- Ajustes pós-teste: atordoado agora é amarelo elétrico (não se confunde com o herói); câmera de combate mais alta (3,3 m) e afastada (4,8 m); inimigos em guarda do lado da câmera contornam o herói para a frente; ruínas do encontro 2 afastadas da área de combate.
- Pendência para o M4 (passe de arte da arena): dar colisão ao cenário e fazer a câmera desviar de paredes (spring arm). Logo após um Passo Relâmpago, um inimigo ainda pode passar perto da câmera por um instante enquanto contorna o herói.

### M3 — Habilidades, elementos e game feel ✅ concluído em 20/11/2026
- [x] 3 poderes de raio (Lâmina Voltaica, Corrente em Cadeia, Fúria da Tempestade) com HUD
- [x] Carga Estática: ganho, perda, barra e visual de Carga cheia (arcos em volta do herói, relâmpagos mais frequentes)
- [x] VFX de raio procedural (arcos, flash de luz) na cor do elemento
- [x] Ciclo elemental e escolha de elemento pré-fase
- [x] Elite com golpe duplo; variantes elementais com cor (elmo)
- [x] Hitstop, finisher em câmera lenta, camera shake, números de dano, SFX provisórios
- **Aceite:** dano com vantagem/desvantagem visivelmente diferente; a Corrente salta entre até 3 inimigos; a Fúria só fica disponível com Carga 100; finisher só no último inimigo morto por golpe forte. Verificado por `tests/auto_combat_test.tscn` (48 checagens) e `tests/auto_rail_test.tscn` (piloto automático usa os poderes e confere o finisher em cada onda).
- Ícones de poder com recarga radial ficaram como texto no HUD; viram ícones no passe de arte do M4.

### M4 — Loop completo e progressão ✅ concluído em 20/11/2026
- [x] Ouro por inimigo + bônus; regra de 50% na morte (`data/combat/rewards.tres`, `gold_reward` em cada `EnemyData`)
- [x] Tela de resultado e loja (Ferreiro) com os upgrades do §10 (`data/upgrades/`)
- [x] Save/load em JSON (`user://save.json`); menu principal e pausa (Esc/P: continuar, som, recomeçar, sair)
- [x] Ícones dos poderes com recarga radial no HUD; contador de ouro
- [x] Ruínas com colisão; câmera desvia de paredes (braço de mola)
- [x] Ambientação da arena (neblina, tochas, relâmpagos)
- [x] Troca dos placeholders por arte feita com primitivas do Godot (decidido em 20/11/2026): herói com couraça, ombreiras, capa, elmo e espada (viseira, crista e lâmina brilham na cor do elemento); Soldado com espada e escudo, Besteiro com besta, Elite com chifres; colunas com capitel e base, colunas quebradas e arcos de pedra sobre o trilho
- [x] Export Windows: `build/windows/LaminaDaTempestade.exe` (preset "Windows Desktop", pacote embutido, sem a pasta `tests/`)
- **Aceite:** jogar → vencer ou morrer → comprar upgrade → fechar o jogo → reabrir e o progresso continuar lá. A parte de código está verificada por `tests/auto_meta_test.tscn` (loja, save, upgrades aplicados, ouro na derrota, pausa) e por `tests/auto_rail_test.tscn` (ouro da vitória = 134 dos inimigos + 50 de bônus = 184).

### M5 — Movimento livre, percurso e realismo (em andamento, 21/11/2026)
- [x] Controle livre em 3ª pessoa: andar, correr, esquiva com invencibilidade, bloqueio, avanço nos golpes
- [x] Câmera por cima do ombro (mouse, braço de mola, enquadramento com alvo travado) e mira travada
- [x] Inimigos fluidos: percepção, corrida, cerco lateral, avanço durante o aviso, cambalear/empurrão, passos procedurais
- [x] XP e níveis persistentes; inimigos extras e mais fortes conforme o nível
- [x] Percurso `trail_01`: terreno gerado, texturas fotográficas, vegetação/rochas reais, 5 clareiras com barreira, 4 fogueiras, patrulhas, santuário
- [x] Iluminação noturna realista (HDRI, lua, neblina volumétrica, SSAO) com presets de qualidade
- [x] Personagens animados com animações da Mixamo (29 movimentos escolhidos de 107), espada/escudo/besta presos aos ossos
- [x] Personagens reais da Mixamo: herói Paladino (espada e escudo do próprio modelo), 3 inimigos comuns e 3 chefões
- [x] Chefões com poderes (golpe no chão, salto, rajada), rugido, fúria e barra de vida
- [x] Efeitos dos poderes e de destruição: rastro da espada, imagens residuais na esquiva/Passo Relâmpago, raios do céu, cortes elétricos, ondas de choque, faíscas, marcas no chão, desintegração
- [x] Ritmo de ação mais rápido (herói 5,6 m/s / 8,6 m/s correndo, esquiva de 0,3 s, golpes e magias 1,4× mais rápidos, inimigos mais ágeis)
- [x] Sons e músicas reais (CC0), inimigos escalam também com o equipamento comprado
- **Aceite:** `tests/auto_trail_test.tscn` — piloto automático percorre a trilha inteira, vence as 5 clareiras, acende as 4 fogueiras, sobe de nível e chega ao santuário (~110 s de jogo).

## 13. Backlog pós-MVP

Upgrade dos poderes de raio (ex.: +dano elétrico, +1 salto na Corrente, Carga inicial) · inimigos resistentes ou que absorvem raio · esquiva com invencibilidade · combo rítmico (bônus por acertar o tempo) · chefe com fases · mais fases e trilhos com bifurcação · itens equipáveis e armas com elemento próprio · elemento nos ataques inimigos · troca de elemento em combate · suporte a gamepad · localização · opções de gráfico.

## 14. Questões em aberto

- Título do jogo (no menu está o provisório "Lâmina da Tempestade", em `scenes/main/main_menu.gd`), nome/aparência do protagonista e a origem dos seus poderes de raio.
- Animação: hoje tudo é animado por código (poses e tweens). Animação esquelética de verdade exigiria modelos riggados.
- Recuperação de 20% de HP entre encontros: validar no M2 se a fase fica fácil ou difícil demais.

## 15. Personagens animados (Mixamo)

Personagens (pasta original `Documentos\Amimacoes`, todos com o esqueleto `mixamorig_*`):

| Papel | Modelo | Arquivo no projeto |
|---|---|---|
| Herói | Paladin W/ Prop J Nordstrom (espada e escudo fazem parte do modelo) | `assets/characters/hero/paladin.fbx` |
| Esqueleto / Vampira / Parasita | Skeletonzombie T Avelange / Vampire A Lusth / Parasite L Starkie | `assets/characters/enemies/` |
| Chefões | Warrok W Kurniawan / Mutant / Maw J Laygo | `assets/characters/bosses/` |

Não usados: Ch05 (114 MB, 48 mil triângulos — pesado demais para a GPU integrada), Demon e Pumpkinhulk (ficam para futuros chefões).

Animações: 32 escolhidas dos pacotes "Pro Sword and Shield" e "Pro Magic" medindo duração, deslocamento e o instante do golpe (pico de velocidade da mão):

| Uso | Animação (arquivo original) |
|---|---|
| Parado / andar / correr / costas | sword and shield idle, walk, run, walk (2), run (2) |
| Sprint (Shift) e esquiva relâmpago | Standing Sprint Forward (magia; na esquiva, 1,8× com imagens residuais) |
| Andar/correr de lado (travado) | strafe (2)/strafe (esq./dir.), strafe (3)/(4) correndo |
| Combo 1-2-3 | slash → attack (4) → attack (3) (golpe forte) |
| Parry / bloqueio / golpe no escudo | block, block idle, block (2) |
| Atingido / morte | impact (3), death |
| Dardo de Raio / Corrente / Fúria | 1H Magic Attack 02, 1H Cast Spell 01, 2H Magic Area Attack 01 |
| Lâmina Voltaica | slash (4) |
| Inimigo: golpe / golpe duplo / magia | slash, attack (2), 1H Magic Attack 01 (sincronizados com o aviso) |
| Inimigo: surgir / atordoado / cambalear | Crouch To Standing Idle, React Large From Front, impact (2) |
| Chefão: golpe no chão / rugido / rajada / salto | sword and shield casting, sword and shield power up, 2H Magic Attack 01, Standing Jump |

- O deslocamento das animações é removido (o código move os personagens); a velocidade de andar/correr é ajustada à velocidade real para os pés não deslizarem. Golpes e magias do herói correm 1,4× depois do impacto.
- No arquivo do Paladino os nomes das malhas vêm trocados: a espada é a malha `Paladin_J_Nordstrom` (a base e a ponta da lâmina são calculadas da própria malha).
- O Esqueleto carrega espada e escudo redondo presos aos ossos; os outros lutam com garras e magia. Inimigos têm contorno na cor do elemento; o herói tem um contorno suave para não sumir na noite.
- Desempenho medido (Iris Xe, preset Baixo, janela 1280×720): mediana ~52 FPS no percurso completo com chefões e efeitos (mín. ~35 no carregamento).

## 16. Créditos de áudio (todos CC0 — domínio público, OpenGameArt.org)

| Uso | Obra (autor) |
|---|---|
| Lâminas, metal, pedras, moedas, rugidos e mortes de criaturas | "80 CC0 RPG SFX" (rubberduck) |
| Rosnados, gemidos, rugidos | "80 CC0 creature SFX" (rubberduck) |
| Choques elétricos, impacto no chão, esquiva, carga, explosão | "Electricity Game Sound Pack" (faxcorp) |
| Magia elétrica | "Spell sounds" (HaelDB; CC0 ou OGA-BY 3.0, usado como CC0) |
| Trovão | "Rain + Long Thunder" (WuxiaScrub) |
| Música de exploração e menu | "Dark Shrine Loop" (qubodup, remix de yd) |
| Música de combate | "Determined Pursuit (epic orchestra loop)" (Emma_MA) |
| Música de chefão | "Boss Battle #2 [Symphonic Metal]" (nene) |

Os arquivos foram convertidos para OGG e os longos foram cortados (`assets/audio/sfx/`, `assets/audio/music/`).

## 17. Rumo: RPG de ação sombrio em mundo aberto (plano técnico, 21/11/2026)

Objetivo: transformar o percurso linear num **mundo aberto medieval sombrio** (liberdade de exploração e eventos dinâmicos), com combate visceral, história em arcos e poderes de raio cinematográficos. Só mecânicas podem ser inspiradas em outros jogos; nomes, arte, música e fases são originais.

| Fase | Conteúdo | Situação |
|---|---|---|
| A. Base | Object Pooling (`Pools`), `AudioManager` com canais limitados, save v2 com auto-save e Continuar da última fogueira, arcos de história com objetivo e narração na HUD, mira híbrida (assistida/livre, tecla **T**), reputação (dados), New Game+ (dados) | ✅ feito |
| B. Visual e combate | Shaders de raio/plasma, luzes pulsantes, bloom/distorção, clima (chuva/tempestade potencializa o raio), dia/noite, status Eletrocutado, condução por água/metal, crateras e fumaça, choque de espadas, gore estilizado e finalização em câmera lenta | a fazer |
| C. IA e mundo | Inimigos demoníacos (shader de corrupção, olhos brilhantes, aura), IA de flanco/investida/defesa/contra-ataque, hordas por arco, mapa aberto, eventos dinâmicos (emboscadas, mercadores pedindo socorro, patrulhas), efeito da reputação em NPCs/missões/preços | a fazer |
| D. Fluxo e loja | Menu título (Novo Jogo, Continuar, Configurações, Sair), tela de carregamento com progresso real e dicas, introdução e cutscenes de marco, encerramento, loja unificada (espadas, armaduras, poderes), Arena de Hordas | a fazer |

**Campanha (Fase A):** 4 arcos em `data/story/` — *A Trilha dos Corvos*, *A Ponte de Pedra* (Grom), *O Bosque Morto* (Mutante), *O Santuário das Tempestades* (Guardião). Cada arco narra a abertura, mostra um objetivo por vez e, ao terminar, narra o encerramento, dá ouro e reputação e salva. Protagonista: Kael, último cavaleiro da Ordem do Grifo de Prata; inimigo: a Mácula.

**Facções (reputação −100 a 100):** Ordem do Grifo de Prata, Guilda dos Mercadores (preços −15% a +15%), Vilarejo de Pedra-Cinza.

**Mira (GDD §6.4):** *Assistida* — o inimigo mais perto é destacado e o herói vira para ele nos golpes, sem prender a câmera (Q ainda trava). *Livre* — só o inimigo no círculo da mira (centro da tela) vira alvo; golpes saem para onde a câmera aponta; aparece a mira "+".

**Save v2 (`user://save.json`):** ouro, nível/XP, upgrades, elemento, espadas (tem/equipada), reputação, arco e objetivos, fim de jogo, New Game+, metro da última fogueira, qualidade gráfica e mira. Gravado em arquivo temporário e trocado no fim. Auto-save em fogueiras, compras, objetivos/arcos e fim de partida. Saves v1 continuam carregando.

**Espadas (em andamento):** Cimitarra, Lâmina Rúnica e Espada Celeste importadas em `assets/weapons/` com encaixe automático na mão (`Equipment.fit_sword`); falta a loja unificada e os drops dos chefões (Fase D). A espada "Halo" veio só em `.blend` (precisa de FBX/glTF). Licenças das espadas a confirmar na página de origem.
