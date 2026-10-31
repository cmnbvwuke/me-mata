# Operation Black Tide — protótipo de FPS tático (Godot 4)

FPS tático em primeira pessoa, ambientado na fictícia **República de Valderrama**, no Caribe.
O país é governado há mais de uma década pelo **General Rodrigo Salcedo**, acusado de transformar
a nação em um hub do narcotráfico. Você integra a **Força-Tarefa TRIDENT**, uma unidade multinacional
de operações especiais encarregada de capturá-lo **vivo**.

A campanha tem **8 missões jogáveis** em 4 fases (veja "Campanha" abaixo), com checkpoints,
progresso salvo (✓ no menu) e o botão "Próxima missão" ao final de cada uma.

---

## Como rodar

1. Instale o **Godot 4.3** ou mais recente (versão *standard*, não precisa da .NET):
   <https://godotengine.org/download>
2. Abra o Godot → **Importar** → selecione `operation-black-tide/project.godot`.
3. Na primeira abertura o editor importa o projeto (gera a pasta `.godot/`). Aguarde.
4. Pressione **F5** (ou o botão ▶). O jogo abre no menu principal.
5. **Campanha → Absolute Resolve → Iniciar missão**.

> **Qualidade gráfica** (Configurações): Baixo / Médio / Alto. Na primeira execução o jogo
> escolhe sozinho (GPU integrada → Baixo). Também dá para ligar o contador de FPS.
>
> Renderizador: **Forward+** (precisa de GPU com Vulkan). Se a máquina for fraca, desligue a
> névoa volumétrica em `scripts/levels/absolute_resolve.gd` → `_setup_environment()`
> (`env.volumetric_fog_enabled = false`).

Para testar só o nível: abra `scenes/levels/absolute_resolve.tscn` e pressione **F6**.

### Instalador para Windows/Linux (Electron)

A pasta [`../electron-app`](../electron-app/README.md) gera um instalador `.exe` (Windows) e um
`.AppImage` (Linux). O Electron cuida do instalador e de um launcher, e o jogo roda como executável
nativo do Godot. Os presets de exportação estão em `export_presets.cfg`.

### Teste automatizado (headless)

```bash
godot --headless --path operation-black-tide --import     # só na primeira vez
godot --headless --path operation-black-tide res://tests/smoke_test.tscn
```

Ele percorre a missão inteira chamando os sistemas reais (intro, movimento, agachar, tiro automático,
recarga, troca de arma, ADS, detecção/alarme, apoio aéreo, objetivos, captura do HVT,
recarga de checkpoint, HVT seguindo pela navmesh, extração) e imprime `SMOKE TEST PASSED`.

As outras 7 missões têm um teste próprio que conclui cada objetivo de cada missão (alvos e
detonações, eliminação, defesa, resgate e escolta), testa a recarga de checkpoint e confere a vitória:

```bash
godot --headless --path operation-black-tide res://tests/missions_test.tscn            # todas
godot --headless --path operation-black-tide res://tests/missions_test.tscn -- m2_defector   # uma
```

---

## Controles

| Tecla | Ação |
|---|---|
| W A S D / mouse | Mover / olhar |
| Shift (segurar) | Correr (só para frente; não atira correndo) |
| C ou Ctrl | Agachar (alternar) — mais silencioso e menos visível |
| Espaço | Pular — diante de uma janela ou obstáculo baixo (sacos de areia, mesas, caixotes), **salta por cima/através** |
| Botão esquerdo | Atirar |
| Botão direito (segurar) | Mirar (ADS) |
| R | Recarregar (tática ou com a arma vazia, tempos diferentes) |
| B | Modo de disparo AUTO / SEMI (M4A1) |
| 1 / 2 / Q / roda do mouse | Trocar arma: M4A1 ↔ P226 SD suprimida |
| E (segurar) | Interagir: capturar o HVT, munição, inteligência |
| F | Lanterna (deixa você **mais visível**) |
| N | Visão noturna (NVG) |
| T | Designar apoio aéreo onde você está mirando |
| Enter | Pular a introdução |
| Esc / P | Pausar |

---

## Campanha

| Fase | Missão | Clima | Resumo |
|---|---|---|---|
| 1 — Sombra no Caribe | **Olhos no Horizonte** | Entardecer | Infiltração pela costa, marcar lanchas com laser, destruir o repetidor de rádio, extrair pela enseada |
| 1 | **Maré Baixa** | Noite | Abordagem a um cargueiro: limpar o convés entre contêineres, tomar a ponte, cortar as máquinas, segurar a proa |
| 1 | **Pacote Silencioso** | Noite | Porto de San Lázaro: coletar manifestos, celulares e HD (furtivo), fixar rastreador GPS, exfiltrar |
| 2 — Bloqueio e Pressão | **Linha Vermelha** | Amanhecer | Retomar o posto no píer, defender 2 min contra ondas por terra e mar, sabotar lanchas, limpar o porto |
| 2 | **Céu Cego** | Noite | Explodir a subestação (a base apaga), desligar o radar, fugir; torre com holofote |
| 2 | **Voz de Dentro** | Entardecer | Resgatar o desertor Coronel Ibarra num vilarejo e escoltá-lo até o carro sob emboscadas |
| 3 — Absolute Resolve | **Absolute Resolve** | Noite | A missão principal (abaixo) |
| 4 — Consequências | **Brasas** | Nublado | Destruir 3 laboratórios, eliminar o chefe "El Tiburón", segurar a zona de pouso |

## A missão principal: Absolute Resolve

1. **Infiltração** – helicóptero voando baixo sobre o mar até a zona de pouso. Daí você segue a pé
   pela selva até a **Hacienda El Mirador**. Duas torres com **holofotes** varrem a aproximação;
   há patrulhas, um posto de controle e uma brecha no muro sul.
2. **Eliminar a resistência no pátio** – guardas, milícia e um elite. O **apoio aéreo**
   (Viper 2-1, 2 cargas) é liberado aqui.
3. **Capturar o HVT** – CQB dentro da residência: hall, sala da guarda, cozinha, corredor, escritório,
   sala de estar, quarto e a **sala segura** blindada. Segure **E** para render o General.
   **Se ele morrer (até por fogo amigo), a missão falha.**
4. **Extração** – reforços do cartel entram pelo portão e saem do quartel. Proteja o HVT até o
   helicóptero pousar no heliponto e leve-o até lá.

Cada objetivo concluído é um **checkpoint**. Ao morrer, "Tentar novamente" recomeça dali.
Há 2 itens de **inteligência** opcionais (laptop do General e HD do CFTV) e 4 caixas de munição.

### Dicas de furtividade

- A barra no topo da tela mostra o estado: **OCULTO → SUSPEITO → DETECTADO / ALERTA GERAL**.
  Os inimigos também mostram **?** (desconfiado) ou **!** (em combate) sobre a cabeça.
- Agachado você é ~2× mais difícil de ver e quase não faz barulho. Correr faz barulho.
- **Moitas bloqueiam a visão** dos inimigos (mas não as balas).
- A **P226 SD** é suprimida (ouvida a ~6 m). Um disparo do **M4A1** alerta todos num raio de 60 m.
- Um guarda que te vê leva **~3 s para reportar pelo rádio**. Elimine-o antes e o alarme não toca.
- Guardas que encontram **corpos** disparam o alarme.
- Com o alarme: sirene, giroflex vermelhos e todo o complexo passa a te caçar.

---

## Estrutura do projeto

```
operation-black-tide/
├── project.godot                  # Config, autoloads, camadas de física nomeadas
├── icon.svg
├── scenes/
│   ├── menus/      main_menu.tscn, mission_end.tscn
│   ├── player/     player.tscn            # CharacterBody3D + Head/Camera3D/WeaponManager/Lanterna
│   ├── enemies/    enemy.tscn             # CharacterBody3D + NavigationAgent3D + indicador ?/!
│   ├── characters/ hvt.tscn               # General Salcedo
│   ├── levels/     absolute_resolve.tscn  # Ambiente, navmesh, player, HUD, pausa, objetivos
│   │               missions/*.tscn        # As outras 7 missões da campanha
│   └── ui/         hud.tscn, pause_menu.tscn
├── scripts/
│   ├── autoload/   game_manager.gd        # Estado global, input map, checkpoints, stats, cenas
│   │               audio_manager.gd       # Síntese procedural de TODOS os sons
│   │               stealth_system.gd      # Barramento de ruído, alarme global, suspeita
│   ├── core/       layers.gd, damage_info.gd
│   ├── data/       campaign.gd            # Fases 1–4, missões e briefings
│   ├── player/     player.gd
│   ├── weapons/    weapon_data.gd (Resource), weapon.gd, weapon_manager.gd
│   ├── enemies/    enemy.gd (IA), enemy_profile.gd (Resource), cover_point.gd
│   ├── characters/ hvt.gd
│   ├── levels/     level_builder.gd, absolute_resolve.gd,
│   │               mission_level.gd (base data-driven) + missions/ (7 missões)
│   ├── objectives/ objective_manager.gd
│   ├── support/    air_support.gd, helicopter.gd, searchlight.gd, pickups.gd
│   ├── fx/         fx.gd                  # Impacto, sangue, decals, traçantes, explosões
│   └── ui/         hud.gd, crosshair.gd, damage_indicator.gd, waypoint_marker.gd,
│                   main_menu.gd, pause_menu.gd, mission_end.gd, settings_panel.gd, ui_style.gd
├── resources/
│   ├── weapons/    m4a1.tres, p226_sd.tres
│   └── enemies/    guard.tres, elite.tres, militia.tres
├── shaders/        nvg.gdshader, damage_vignette.gdshader, menu_background.gdshader
└── tests/          smoke_test.tscn/.gd, missions_test.tscn/.gd
```

Quase tudo é gerado em código: geometria (greybox), armas em primeira pessoa, helicóptero, efeitos
e sons. Os únicos assets externos são personagens animados em `assets/characters/`:
- `general_salcedo.fbx` — General Salcedo (ajoelhado ao ser encontrado, andando algemado).
- `soldier.fbx` + `soldier_anims.res` — soldado raso usado pelos guardas (`use_soldier_model` no
  perfil `guard.tres`; lógica em `scripts/characters/soldier_model.gd`). Animações Mixamo:
  andar com fuzil, atirar andando, girar 45° para cada lado, morrer; pose parada/mira e
  agachamento (procedural, `SkeletonModifier3D`) derivados delas. O fuzil é preso às mãos em código.
- `elite.fbx` + `elite_anims.res` + `elite_cor/normal/rugosidade/metal.png` — soldado de elite
  (variante `"elite"` em `SoldierModel.VARIANTS`, material PBR montado em código).
- `militia.fbx` + `militia_anims.res` + `militia_cor.jpg` — miliciano (bandana vermelha); a caminhada
  foi recortada de um "Rifle Walk To Stop".
- `assets/weapons/ak47.glb` — AK-47 nas mãos de todos os inimigos (Blend Swap #94134, licença CC0;
  convertida no Blender 4.0, reduzida para ~6 mil triângulos e 88 cm).
Para um modelo novo:
`tools/extract_character_anims.gd` gera as animações e imprime os valores da variante.

---

## Sistemas implementados

### Jogador (`scripts/player/player.gd`, `scripts/weapons/`)
- Movimento com aceleração, sprint, agachar (com checagem de teto antes de levantar), pulo,
  balanço de câmera, aterrissagem com tremor.
- **Armas** definidas por `WeaponData` (.tres): dano, multiplicador de headshot, cadência, pente,
  reserva, recarga tática/vazia, dispersão (quadril/ADS/movimento/por disparo), recuo, FOV de ADS,
  posições da viewmodel e **raio de ruído**.
- **ADS** real: a mira red dot (M4A1) e o trítio (P226) se alinham ao centro da tela.
- Hitscan com dispersão em cone, headshots, recuo de câmera com recuperação, coice da arma,
  sway, balanço, animação procedural de recarga/equipar/corrida, clarão de cano.
- Vida 100 com **regeneração** após 4,5 s sem dano.
- Interação "segure E" genérica (qualquer objeto com `can_interact()/interact()`).

### Inimigos (`scripts/enemies/enemy.gd`)
Máquina de estados **PATROL → ALERT → COMBAT**:
- **Visão**: cone + alcance + raycast (bloqueado por paredes e vegetação). A suspeita sobe mais
  rápido de perto, com o jogador em pé, correndo ou com lanterna.
- **Audição**: passos, quedas e tiros via `StealthSystem`; paredes abafam o som.
- **Combate**: procura **pontos de cobertura** seguros (o jogador não vê a cabeça agachada),
  alterna agachar/expor e atirar em rajadas, **flanqueia** buscando um ponto lateral com linha de tiro,
  avança sobre a última posição conhecida e volta a procurar quando perde o contato.
- Precisão melhora com o tempo de mira; tiros erram mais com o jogador em movimento.
- **Tipos** (perfis `.tres`):
  | Tipo | Vida | Colete | Precisão | Comportamento |
  |---|---|---|---|---|
  | Guarda Presidencial | 100 | — | média | usa cobertura, lanterna |
  | Guarda Negra (Elite) | 120 | 25% | alta | cobertura, flanqueia muito, NVG (sem lanterna), ouve melhor |
  | Milícia do Cartel | 85 | — | baixa | agressiva, sem cobertura, rajadas longas |

### Furtividade (`scripts/autoload/stealth_system.gd`)
Ruído com raio, alarme global (com atraso de rádio), descoberta de corpos, holofotes de torre
que detectam e perseguem o jogador, vegetação que bloqueia a visão, lanterna e postura que mudam
a visibilidade.

### HUD e UI
Mira dinâmica (abre com a dispersão real), hitmarker (vermelho = abate), barra de vida com cores,
munição/arma/modo de disparo, aviso de recarga, objetivo atual + progresso, **marcador de objetivo
na tela com distância**, indicador de furtividade, **indicador direcional de dano**, vinheta vermelha
e batimento cardíaco com vida baixa, visão noturna, legendas de rádio, banners de objetivo/checkpoint.
Menu principal (campanha com briefings, configurações, controles), pausa e tela de resultado com
estatísticas (tempo, abates, headshots, precisão, alarmes, inteligência).

### Efeitos e áudio
Faíscas e poeira de impacto, buracos de bala (decals), sangue + poça, traçantes, clarão de cano,
explosões com luz/fogo/fumaça/estilhaços. Sons sintetizados: disparos com eco, pistola suprimida,
recarga em etapas, cápsulas, passos, balas zunindo perto da cabeça, impactos, explosões,
rotor de helicóptero, sirene, rádio.

---

## Como expandir

- **Nova arma**: duplique `resources/weapons/m4a1.tres`, ajuste os valores e adicione o caminho em
  `WeaponManager.loadout` (no Inspector do nó `Player/Head/Camera3D/WeaponManager`).
  Para um modelo novo, adicione um `model_type` em `Weapon._build_model()` ou troque por uma cena `.glb`.
- **Novo tipo de inimigo**: novo `.tres` de `EnemyProfile` em `resources/enemies/` e registre no
  dicionário `PROFILES` do nível.
- **Nova missão**: crie um script que estende `MissionLevel` (`scripts/levels/mission_level.gd`) e
  sobrescreva `build_world()`, `define_objectives()` e `spawn_enemies()` — os objetivos são dados
  (`reach`, `kill`, `interact` com cargas/terminais, `defend`, `rescue`, `escort`); checkpoints,
  ondas de reforço, explosões, alarme e vitória/derrota já vêm prontos. Copie uma cena de
  `scenes/levels/missions/`, troque o script e preencha `"scene"` em `scripts/data/campaign.gd`.
  Use `scripts/levels/missions/m1_recon.gd` como exemplo.
- **Sons reais**: `AudioManager.register("rifle_shot", load("res://audio/m4.ogg"))` substitui o som
  procedural mantendo todas as chamadas.
- **Objetivos**: `ObjectiveManager.setup([...])` + `complete("id")` a partir de qualquer gatilho;
  cada conclusão já grava checkpoint.
- **Interativos**: qualquer `StaticBody3D`/`CharacterBody3D` com `can_interact()`,
  `get_interact_prompt()`, `get_interact_hold_time()` e `interact(player)` funciona com o "segure E".

## Limitações conhecidas do protótipo

- Cenários "greybox" procedurais.
- Checkpoints recriam o nível e só fazem nascer os inimigos das etapas ainda não superadas.
- Um único andar na residência; sem inclinação lateral (lean) ou granadas.
