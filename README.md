# Espectro Simulator

> Este é um jogo de ficção satírica e dark comedy. Nenhuma ação real é incentivada. Todos os personagens e eventos são caricaturas exageradas baseadas em drama público já noticiado.

Projeto em **Godot 4.3+** (GDScript).

- Design: [`docs/GDD.md`](docs/GDD.md) (a seção 0 traz as diretrizes de sátira)
- Roteiro do Prólogo: [`docs/roteiro/prologo.md`](docs/roteiro/prologo.md) (a versão jogável é `data/dialogue/prologo.json`)
- Cenário da sede: [`docs/cenario.md`](docs/cenario.md)

## Rodar
Abra a pasta no editor do Godot (o primeiro import gera as traduções) e aperte F5.
Fluxo atual: Aviso de Ficção → Menu → Prólogo → Semana 1 (a Tarde acontece no mapa explorável da sede; o resto ainda é texto) → save automático.

Controles no mapa: **WASD/setas** andar · **E** interagir · **C** celular · **Esc** fechar.

Roteiros: [`docs/roteiro/prologo.md`](docs/roteiro/prologo.md) e [`docs/roteiro/semana_01.md`](docs/roteiro/semana_01.md).

## Teste de fumaça
```
godot --headless --path . --import
godot --headless --path . res://tests/smoke_test.tscn   # imprime "OK"
```

## Estrutura
```
scripts/autoload/   EventBus, GameState, ObsessionSystem, ReputationSystem,
                    ConfidantSystem, EndingEvaluator, SaveManager
scripts/resources/  modelos de dados (MetricDelta, Recording, RivalData,
                    NeutralizationMethod, NarrativeAsset, Condition, GameEvent,
                    WeekData, EndingData…)
scripts/systems/    WeekRunner (lógica da semana, guiada por data/weeks/*.json)
scripts/ui/         FictionDisclaimer, MainMenu, DialoguePlayer, WeekHub
scripts/world/      HQMap (sede explorável), MapGraph (planta/caminhos), WorldNPC, WorldPlayer
data/maps/          planta, NPCs, rotinas e eventos da sede
scenes/             boot/, menus/, story/
data/dialogue/      roteiros JSON
localization/       strings.csv (texto canônico do aviso)
```
