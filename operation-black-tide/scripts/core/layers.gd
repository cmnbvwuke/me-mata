class_name Layers
extends RefCounted
## Constantes das camadas de física (ver project.godot > layer_names).
## Centralizar aqui evita "números mágicos" espalhados pelo código.

const WORLD := 1      # Geometria estática (paredes, chão, cobertura)
const PLAYER := 2     # Corpo do jogador
const ENEMY := 4      # Corpos dos inimigos
const HVT := 8        # Alvo de alto valor (General Salcedo)
const TRIGGER := 16   # Áreas de gatilho (objetivos)
const FOLIAGE := 32   # Vegetação: bloqueia VISÃO, mas não movimento nem balas

## Balas do jogador acertam mundo, inimigos e o HVT (cuidado!).
const PLAYER_SHOT_MASK := WORLD | ENEMY | HVT
## Balas inimigas acertam mundo e jogador.
const ENEMY_SHOT_MASK := WORLD | PLAYER
## Linha de visão dos inimigos é bloqueada também pela vegetação.
const SIGHT_MASK := WORLD | PLAYER | FOLIAGE
