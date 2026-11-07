# Cenário — A Sede do Movimento

> Ficção satírica. Os espaços, NPCs e rotinas são inventados. Ver `docs/GDD.md`, seção 0.

A Tarde de cada dia acontece na **Sede do Movimento**, explorável em visão de cima. É o equivalente à escola do gênero: um lugar fechado, cheio de gente com rotina, onde tudo o que você faz pode ter testemunha.

Dados: `data/maps/sede.json` · Código: `scripts/world/` · Cena: `scenes/world/hq_map.tscn`

## Planta

```
┌──────────────┬──────────────┬───────────┬──────────────────┐
│ SALA DA      │ SALA DE      │ JURÍDICO  │ TERRAÇO          │
│ MISSÃO       ├┤ REUNIÃO     │ Dr. Hélio │ yoga, pomba      │
│ (Renan)      │              │           │                  │
├────[ ]───────┴─────[ ]──────┴───[ ]─────┴───────[ ]────────┤
│ CORREDOR                       💧 bebedouro (fofoca)        │
├────[ ]─────────────────[ ]──────┬──[ ]────┬──[ ]──┬──[ ]────┤
│ REDAÇÃO (open space)            │ COPA    │ ALMOX.│RECEPÇÃO │
│ Júlia · Kleber · Thiago         │ café    │ totem │ D.Neusa │
│ (todo mundo vê todo mundo)      │         │ Renan │ 🚪saída  │
└─────────────────────────────────┴─────────┴───────┴─────────┘
```
`[ ]` = porta · `├┤` = porta interna entre a Sala da Missão e a Sala de Reunião

## Função de cada sala

| Sala | Para que serve no jogo | Piada visual |
|---|---|---|
| **Sala da Missão** | Onde o Renan passa a maior parte do dia. Ficar na porta dá Obsessão. | Um quadro branco escrito só "MISSÃO". |
| **Sala de Reunião** | Às 16h30 o Renan se reúne com a rival. Se você não estiver lá, ela ganha atenção. | O projetor só funciona com o cabo do Renan. |
| **Jurídico** | Sala do Dr. Hélio, que vê longe (visão 300). Mais tarde reage ao Risco Jurídico. | Notas de repúdio pré-impressas. |
| **Terraço** | Yoga epistemológica: baixa a Obsessão e é isolado. | A pomba julgadora. |
| **Corredor** | Liga tudo. No bebedouro, rival e fofoqueiros passam. | — |
| **Redação** | Open space. Muita plateia: péssimo para o discreto, ótimo para o "Elogio Constrangedor". | Mesas coladas. |
| **Copa** | O Renan toma café às 15h30, o lugar ideal para "coincidências". | Aviso passivo-agressivo na geladeira. |
| **Almoxarifado** | Ninguém entra. Futuro esconderijo de provas. | O **totem do Renan** em tamanho real. |
| **Recepção** | Entrada e saída. Ir embora encerra a tarde. | A Dona Neusa "não vê nada". |

## Personagens e rotina (Semana 1)

| NPC | 13h | 14h | 15h | 16h | 17h |
|---|---|---|---|---|---|
| **Renan Santos** | sua mesa | reunião (14h–14h45) | café na copa (15h30) | **reunião com a rival (16h30)** | sua mesa (17h15) |
| **Júlia Planilha** (rival) | sua mesa | sua mesa | **bebedouro (15h–15h20)** | **reunião (16h30)** | sua mesa (17h15) |
| Dr. Hélio | jurídico | copa (14h30) | jurídico (15h15) | — | — |
| Kleber Figurinha | mesa | cafeteira (14h–14h20) | mesa | bebedouro (16h–16h15) | mesa |
| Thiago Pauta | fundo da redação | reunião (14h–14h45) | fundo | copa (16h–16h20) | fundo |
| Dona Neusa | balcão o dia todo | | | | |

**As janelas que interessam:**
- **15h–15h20:** a Júlia sozinha no bebedouro. Boa hora para métodos discretos.
- **13h–14h na Redação:** há plateia para o Elogio.
- **16h30:** ou você entra na reunião ("sem querer") ou ela ganha +8 de atenção.

## Mecânicas do espaço

- **Relógio:** a tarde vai das 13h às 18h, e cada segundo real equivale a 2 minutos de jogo. As ações gastam tempo (Seminário Infinito = 2 horas), e o relógio pula.
- **Visão e testemunhas:** cada NPC enxerga dentro de um raio e as paredes bloqueiam. O 👁 aparece sobre quem está te vendo. Num método, quem estiver olhando vira **testemunha nomeada** e soma Suspeita.
- **Plateia:** alguns métodos precisam de gente por perto (o Elogio pede 2 pessoas).
- **Observar:** a rival precisa estar à vista, nem perto nem longe demais.
- **Proximidade do Renan:** a menos de ~2 m (220 px) e à vista, a Obsessão sobe devagar, com teto de 8 por dia, e surge um pensamento rosa.
- **Celular [C]:** os serviços do Teacher e a atenção da rival.
- **Saída:** pela recepção dá para encerrar a tarde mais cedo.

## Direção de arte (o que falta substituir)

Hoje tudo é provisório: personagens são círculos e móveis são retângulos. Direção para a arte final:
- **Estilo:** charge política animada em visão de cima, 3/4 levemente inclinada.
- **Paleta:** cinzas frios para a sede. A cada faixa de Obsessão, o pós-processamento puxa para rosa (vinheta, pétalas no canto da tela).
- **Placas e cartazes** como fonte de piada ("A MISSÃO É A MISSÃO", "Reunião às 14h — Pauta: marcar a próxima reunião").
- **Modo palco** (Obsessão ≥ 90): holofote seguindo a protagonista e cortinas nas bordas.

## Próximos cenários
1. **Apartamento da Espectro Cinza:** live da noite e desabafo de madrugada, com cenário 100% cinza e caneca NUANCE.
2. **Apartamento do Teacher Wellington:** gravadores, fitas e o podcast de 11 ouvintes. Visitável na semana 4 (crise do Confidente).
3. **Convenção do Movimento (semana 5):** mapa maior, com palco, plateia e bastidores.
4. **Estúdio de TV comunitária (semana 3):** debate com a Profa. Ágata Contraponto.
