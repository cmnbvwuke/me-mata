# MEIO-TERMO SIMULATOR — Documento de Game Design (v0.1)

> **Este é um jogo de ficção satírica e dark comedy. Nenhuma ação real é incentivada. Todos os personagens e eventos são caricaturas exageradas.**

Paródia de dark comedy política sobre o gênero "simulador yandere", ambientada num meio político-intelectual brasileiro **inteiramente fictício**.

---

## 0. Nota de direção: por que os personagens são fictícios

O briefing original usava como base pessoas reais (um líder político real e uma influenciadora real) e áudios privados vazados. Este documento **troca tudo isso por arquétipos fictícios**, por três motivos práticos de design e de produção:

1. **A sátira fica mais forte quando mira o tipo, não o indivíduo.** "A intelectual do meio-termo que se apaixona pelo líder carismático" é um arquétipo reconhecível em qualquer movimento político. O jogador ri do comportamento, e não de uma pessoa específica.
2. **Retratar uma pessoa real identificável como alguém que "neutraliza" rivais, usando como matéria-prima um desabafo privado vazado, vira assédio, não paródia.** Também é um risco jurídico real (difamação, direito de imagem), coisa que o próprio jogo satiriza no medidor de *Risco Jurídico*.
3. **Personagens originais dão liberdade total.** Dá para exagerar, inventar e mudar a história sem se prender a fatos.

Por isso **não pesquisei o caso real nem uso material dele**. Tudo abaixo é inventado. O título provisório também mudou, porque "Espectro" aponta direto para a pessoa real. Se o nome final for outro, troque à vontade, só não deixe ele apontar para alguém real.

| Briefing original | Versão fictícia neste GDD |
|---|---|
| Espectro Cinza | **Dra. Moderata Ponderosa**, `@MeioTermo` |
| Renan (Senpai) | **Léo Vanguarda**, fundador do movimento |
| Movimento político | **MAL — Movimento Avante Lúcido** |
| Ex-professor de inglês (Confidente) | **Prof. Aurélio Gravatá**, ex-tutor de oratória do cursinho |

---

## 1. Visão geral

**Gênero:** simulação social + gestão de narrativa + stealth leve, com estrutura de semanas.
**Câmera e estilo:** 2.5D isométrico ou 2D top-down, arte estilo "charge política animada".
**Engine sugerida:** **Godot 4.x** (GDScript). Há notas para Unity na seção 9.6.
**Duração-alvo:** 6 a 10 horas na primeira run, com várias runs para ver os finais.

### 1.1 Pilares de design

1. **Contraste é a piada.** Tudo o que Moderata diz em público é sensato, ponderado e cheio de nuance. Tudo o que ela pensa é possessivo, melodramático e absurdo. O jogo mostra as duas coisas **na tela ao mesmo tempo**.
2. **A arma é a narrativa.** Não existe gore. Os "corpos" que o jogador precisa esconder são prints, áudios, threads e contradições.
3. **Todo segredo tem testemunha.** O Confidente é o "save file" da vilania dela. Quanto mais ela desabafa, mais poder ele ganha.
4. **O absurdo escala.** Quanto mais alta a Obsessão, mais teatral, surreal e cartunesco o jogo fica (visual, áudio, métodos). O alto nível nunca é realista. Ele é *ópera*.

### 1.2 Fantasia do jogador

"Sou a pessoa mais racional do debate público e vou usar toda essa racionalidade para garantir que **ninguém** fique a menos de três metros do Léo."

---

## 2. Elenco

### 2.1 Dra. Moderata Ponderosa (protagonista)
- **Público:** doutora em "Epistemologia Aplicada às Redes", tem 2,3 mi de seguidores e o bordão *"Calma, gente. Tudo tem tons de cinza."* Defende "honestidade intelectual", "conciliação" e "dados".
- **Privado:** monólogo interno de yandere clássica, com shoujo, pétalas e violinos. *"Ele disse 'bom dia' ao grupo. AO GRUPO. Mas eu estava no grupo. Logo, foi pra mim."*
- **Visual reativo:** começa em cinzas frios e dessaturados. Com a Obsessão, o cinza vira grafite, depois chumbo, depois "cinza cintilante" com um contorno rosa-neon que ela jura que é cinza.
- **Tique cômico:** usa linguagem acadêmica para racionalizar a obsessão. *"Não é ciúme, é uma análise de risco com viés de confirmação controlado."*

### 2.2 Léo Vanguarda (Senpai)
- Fundador do MAL e obcecado pela **Missão** (que nunca é explicada direito: "a Missão é a Missão").
- É educado, institucional e distante. Responde tudo com nota oficial: *"Agradeço o carinho. Nosso foco segue sendo a Missão."*
- **Não é vilão.** Não corresponde, e só. A piada é que ele nem percebe o caos ao redor.
- Mecânica: **Atenção do Léo** é um recurso distribuído entre os NPCs. Moderata quer 100% dela.

### 2.3 Prof. Aurélio Gravatá (o Confidente, papel de "Info-chan")
- Ex-tutor de oratória dela no cursinho. Está **totalmente fora** do movimento e vive num apartamento cheio de gravadores antigos, fitas cassete e um podcast com 11 ouvintes.
- Ela desabafa com ele por mensagens de voz de 14 minutos. Ele grava tudo "por preocupação pedagógica".
- Vende informações, favores e "consultorias" em troca de **Desabafos** (a moeda dele).
- Tem lealdade **ambígua**. Pode ser aliado fiel até o fim, ou soltar o *Arquivo Gravatá* no pior momento possível.
- Bordão: *"Eu só estou guardando isso pra você, querida. Pra caso você precise lembrar quem você é."*

### 2.4 Elenco de apoio
- **Coro do Grupo de WhatsApp:** NPCs que reagem a tudo com figurinhas.
- **Dr. Hélio Nota-de-Repúdio:** advogado do movimento. Aparece quando o Risco Jurídico passa de 60.
- **A Imprensa (três jornalistas fundidos num só sprite):** "Fontes ouvidas pela reportagem…"
- **Bancada dos Comentaristas:** NPCs de rede social que geram eventos aleatórios.

---

## 3. Estrutura e fluxo de jogo

### 3.1 Macroestrutura
```
Boot → Aviso de Ficção (obrigatório) → Menu → Prólogo (a Rejeição Institucional)
  → Semana 1 … Semana 10 (cada uma: 5 dias úteis + fim de semana de crise)
  → Avaliação de Final → Cutscene de Final → Créditos (com o aviso de novo)
```

### 3.2 Loop diário (dia útil)

| Fase | Duração | O que acontece |
|---|---|---|
| **Manhã: Feed** | menu | Ver métricas, notificações e trending topics. Escolher o "Post do Dia" (define o tom público). |
| **Tarde: Sede do MAL** | tempo real, cerca de 8 a 10 min | Exploração livre: seguir o Léo, observar rivais, coletar Evidências, conversar, sabotar, montar alianças. Relógio de jogo. |
| **Noite: Live** | minigame | Live de 3 perguntas. Responder com "tons de cinza" sobe a Credibilidade. Deixar o subtexto escapar sobe a Obsessão e a suspeita do chat. |
| **Madrugada: Desabafo** | diálogo | Opcional: mandar áudio ao Prof. Aurélio. Alivia a Obsessão, mas adiciona entradas ao **Arquivo Gravatá**. |
| **Resolução** | automática | Processa as métricas, os eventos atrasados e o "Diário Interno" (texto cômico). |

### 3.3 Fim de semana (crise)
- **Sábado:** Evento de Crise da semana (debate, congresso, vazamento, cancelamento).
- **Domingo:** Prazo do rival. Se ele não foi neutralizado, ganha um "Momento com o Léo" e a Obsessão dá um salto.
- **Cutscene de Monólogo Interno:** sempre no fim da semana, com estética shoujo e voice-over dramático.

### 3.4 Diagrama de cenas
```
scenes/
 ├─ Boot ──► FictionDisclaimer ──► MainMenu
 │                                   │
 │                     ┌─────────────┴─────────────┐
 │                  NewGame                    LoadGame
 │                     ▼                           ▼
 │                 Prologue ───────────────► WeekHub
 │                                              │
 │     ┌──────────┬──────────┬──────────┬───────┴──────┐
 │  MorningFeed  Headquarters  EveningLive  NightConfession  Resolution
 │                                              │
 │                              (dia 6) WeekendCrisis ─► WeekMonologue
 │                                              │
 │                              (semana 10) EndingEvaluator ─► Ending_X ─► Credits
```

---

## 4. Sistemas centrais

### 4.1 Obsessão (0 a 100)

**Sobe com:**
| Gatilho | Δ |
|---|---|
| Léo dá atenção a um rival (por evento) | +2 a +8 |
| Rejeição institucional ("Agradeço, mas a Missão…") | +5 |
| Ficar perto do Léo por mais de 30 s (proximidade) | +0,5/s, com teto diário |
| Rival ganha um Momento com o Léo | +15 |
| Ver foto do Léo com alguém no feed | +3 |

**Desce com:**
| Ação | Δ | Custo |
|---|---|---|
| Desabafo ao Prof. Aurélio | −10 a −20 | +1 Gravação no Arquivo |
| "Live de Racionalidade" (sem citar o Léo) | −5 | consome energia |
| Hobby saudável (yoga epistemológica) | −3 | gasta tempo da Tarde |
| Final de semana sem crise (raro) | −10 | — |

**Faixas (cada uma muda UI, música, diálogos e métodos disponíveis):**
| Faixa | Nome | Efeitos |
|---|---|---|
| 0–24 | *Ponderada* | Diálogos sóbrios, só métodos Sociais. |
| 25–49 | *Ligeiramente Enviesada* | O monólogo começa a vazar em sussurros. Métodos Políticos liberados. |
| 50–74 | *Dialética Possessiva* | Pétalas na tela, a trilha ganha violinos. Métodos Narrativos liberados. NPCs percebem. |
| 75–89 | *Tese Final* | Visão em túnel no Léo, falas públicas "glitcham" (ela diz o pensamento em voz alta). |
| 90–100 | *Síntese Absoluta* | Modo ópera: cenário vira palco e métodos **Extremos (teatrais)** são liberados. O Risco Jurídico sobe sozinho. |

**Mecânica de "vazamento verbal":** com Obsessão ≥ 75, cada fala pública tem chance `(Obsessão − 70) × 1,5 %` de virar a versão interna. Exemplo: ela começa "Precisamos de diálogo entre os campos…" e termina "…e ELA precisa sair do campo de visão dele." Isso dá −Credibilidade e +Suspeita.

### 4.2 Reputação e Controle Narrativo

Quatro métricas (0 a 100) e um medidor oculto:

| Métrica | Representa | Se zerar/estourar |
|---|---|---|
| **Credibilidade Pública** (CP) | Quanto o público acredita na persona "tons de cinza" | 0 → Final *Exposição Total* |
| **Controle da Narrativa** (CN) | Quanto ela define a versão dos fatos | baixo deixa os vazamentos piores |
| **Risco Jurídico** (RJ) | Exposição a processos | 100 → Final *Processo* |
| **Apoio Interno** (AI) | Prestígio dentro do MAL | 0 → expulsa do movimento (Game Over parcial) |
| *Suspeita* (oculta) | Quanto os NPCs ligam os pontos | alimenta os eventos do Confidente |

**Ativos narrativos** (inventário): `Print`, `Áudio`, `Thread`, `Live Recortada`, `Aliança`, `Acusação`, `Nota Oficial`. Cada ativo tem **Peso**, **Veracidade** (real / editado / inventado) e **Rastro** (quanto liga a ela).

**Regra de ouro:** ativo **inventado** é forte e barato, mas cada uso soma `Rastro × 2` ao Risco Jurídico.

### 4.3 O Confidente: Arquivo Gravatá

O Prof. Aurélio tem três variáveis próprias:
- **Confiança** (0 a 100): quanto ela confia nele. Sobe a cada desabafo e libera serviços.
- **Lealdade** (0 a 100, oculta): quanto ele está do lado dela. Começa em 60.
- **Arquivo** (lista de `Recording`): cada desabafo gera uma gravação com **Gravidade** (1 a 5) baseada na Obsessão do momento.

**Serviços do Confidente** (pagos em Desabafos ou favores):
| Serviço | Efeito |
|---|---|
| "Ficha do Rival" | Revela fraquezas e rotinas do rival da semana |
| "Conselho Pedagógico" | −Obsessão, +Confiança |
| "Contato na Imprensa" | +Controle da Narrativa por 1 dia |
| "Revisão de Texto" | Reduz o Rastro de um ativo |

**Gatilho de traição** (avaliado toda noite):
```
pressao  = soma(gravidade do Arquivo) × 2 + RiscoJuridico × 0,5 + Suspeita × 0,3
protecao = Lealdade + (Confiança × 0,2) + (favores_pagos × 5)
se pressao > protecao e semana >= 4 → evento "O Pendrive" (ameaça de vazamento)
```
O evento "O Pendrive" abre três escolhas:
1. **Negociar:** paga um preço alto e a Lealdade sobe.
2. **Contra-narrativa preventiva:** "áudios fora de contexto, gerados por IA". Custa CN e soma RJ.
3. **Ignorar:** 50 % de chance de vazamento parcial (−30 CP).

Se o vazamento total acontecer, toca a cutscene *"O Podcast de 11 Ouvintes Vira 11 Milhões"*.

### 4.4 Como tudo se conecta

```
               ┌──────────────── Atenção do Léo a rivais ───────────────┐
               ▼                                                        │
        ┌────────────┐  libera métodos  ┌──────────────┐  ações geram  ┌─┴──────────┐
        │ OBSESSÃO   │ ───────────────► │ NEUTRALIZAÇÃO│ ────────────► │ REPUTAÇÃO  │
        └─────┬──────┘                  └──────┬───────┘               │ CP CN RJ AI│
              │ desabafo alivia                │ Suspeita              └─────┬──────┘
              ▼                                ▼                             │
        ┌────────────┐  arquivo cresce  ┌──────────────┐  RJ alto pressiona  │
        │ CONFIDENTE │ ◄─────────────── │  SUSPEITA    │ ◄───────────────────┘
        └─────┬──────┘                  └──────────────┘
              │ trai ou ajuda
              ▼
     Vazamento → −CP, −CN   |   Ajuda → fichas, contatos, menos Rastro
```

**A tensão central:** a Obsessão alta é poderosa (libera métodos), mas para baixá-la é preciso confessar, e confessar alimenta a bomba-relógio do Confidente. **Não existe jeito "limpo" de jogar.**

---

## 5. Métodos de Neutralização

Todos são caricaturais. O objetivo é **tirar o rival do campo de atenção do Léo**, nunca machucar. Os "Extremos" são teatro do absurdo: a cena vira palco, a cortina cai e o rival some por um alçapão cômico, aparecendo depois num destino ridículo.

| Categoria | Obsessão mín. | Exemplos | Custo/Risco típico |
|---|---|---|---|
| **Social** | 0 | Puxar o rival para uma conversa de 2 h sobre epistemologia · Apresentá-lo a um "contato" que o leva para outro grupo · Elogiar o rival tanto que ele fica constrangido e se afasta | Baixo RJ, pouco efeito |
| **Político** | 25 | Indicar o rival para uma "coordenação regional" em outro estado · Votação interna relâmpago · Montar uma comissão para "estudar" a proposta dele por 18 meses | −AI se falhar |
| **Narrativo** | 50 | Thread "Uma reflexão sobre [rival] (com nuance)" · Recortar a live dele · Plantar uma polêmica de 2014 · Organizar um "debate amigável" armado | +RJ, +Suspeita, alto efeito |
| **Extremo (teatral)** | 90 | **Exílio no Think Tank**: o rival é mandado para um instituto em Liechtenstein e reaparece nos créditos como "Pesquisador Sênior de Coisa Nenhuma" · **O Podcast Infinito**: preso num episódio de 9 h sem fim · **Comitê de Ética Fantasma**: vira réu de um tribunal feito de bonecos de papelão · **A Grande Nota de Repúdio**: uma nota de repúdio gigante cai em cima dele, estilo bigorna de desenho animado | RJ dispara, Suspeita máxima, cutscene operística |

**Regras de tom para os Extremos:** nada de sangue, armas realistas, passo a passo ou métodos replicáveis. A linguagem é de palco ("e assim, com um rufar de tambores, ele foi removido do segundo ato"). Os rivais **sempre** reaparecem bem no epílogo, numa vida absurda e feliz.

### 5.1 Requisitos de um método (dados)
Cada método define: pré-requisitos (Obsessão, itens, local, hora), janela de execução, testemunhas possíveis, efeitos nas métricas, falas de sucesso/falha e a "cena de palco" opcional.

---

## 6. Progressão das 10 semanas

Rivais são arquétipos do ecossistema político-intelectual (fictícios).

| Sem. | Rival / Crise | Por que ameaça | Mecânica nova introduzida | Crise do fim de semana |
|---|---|---|---|---|
| **1** | **Júlia Planilha**, estagiária de dados | Léo elogiou um gráfico dela | Loop básico, Social, Evidências | Reunião de pauta |
| **2** | **Caio Thread**, o "fio de 47 tweets" | Léo retuitou ele | Feed e Post do Dia, métrica CN | Thread viral |
| **3** | **Profa. Ágata Contraponto**, intelectual rival | Debate público com o Léo | Live da Noite, vazamento verbal | Debate na TV comunitária |
| **4** | **O Prof. Aurélio** (crise do Confidente) | Ele quer "conversar sobre os áudios" | Evento O Pendrive, Lealdade | Primeiro ultimato |
| **5** | **Gabi Militância**, influencer jovem | Faz vídeos com o Léo | Métodos Políticos, Apoio Interno | Convenção do MAL |
| **6** | **Dr. Hélio Nota-de-Repúdio** | Descobriu o Rastro e quer "blindar" o Léo dela | Risco Jurídico ativo, ativos inventados | Notificação extrajudicial (cômica) |
| **7** | **A Imprensa** (rival coletivo) | Reportagem "Bastidores do MAL" | Controle Narrativo avançado, contra-narrativa | Coletiva de imprensa |
| **8** | **A Ex-Namorada da Faculdade** do Léo | Reapareceu "só pra tomar um café" | Métodos Extremos (se Obs ≥ 90) | Casamento de um amigo em comum |
| **9** | **A Própria Missão** | Léo anuncia candidatura: "Agora a Missão é tudo" | Rival abstrato: sabotar a agenda vs. apoiar | Lançamento da campanha |
| **10** | **Moderata contra Moderata** | Confronto com a própria persona pública | Avaliação final, todas as métricas convergem | Cutscene de Final |

**Semana 10:** a persona "tons de cinza" vira um chefe de diálogo. Um debate interno entre a Moderata pública e a Moderata obsessiva, com argumentos montados a partir das escolhas da run.

---

## 7. Finais

Avaliados em ordem de prioridade (o primeiro que bater ganha):

| # | Final | Condição | Tom |
|---|---|---|---|
| 1 | **Processo** | RJ ≥ 100 a qualquer momento | Tribunal-musical. Ela se defende citando a si mesma. |
| 2 | **Exposição Total** | CP ≤ 0 ou Arquivo Gravatá vazado completo | Os áudios viram meme, remix e ópera-funk. Epílogo: ela abre um curso "Como Sobreviver ao Cancelamento". |
| 3 | **Yandere Clássico** | ≥ 3 métodos Extremos usados e Obs ≥ 90 no fim | O palco final: só ela e o Léo num teatro vazio. Ele diz "…e a Missão?". Fade para cinza. |
| 4 | **Redenção** | Obs ≤ 30 nas semanas 9 e 10, nenhum Extremo, Confiança alta no Confidente **e** ele não vazou | Ela sai do MAL, faz terapia de verdade e lança o livro *Tons de Cinza Também Incluem Eu Mesma*. O Prof. Aurélio apaga as fitas (ou diz que apagou). |
| 5 | **Conquista** | Todos os rivais neutralizados, CP ≥ 60, AI ≥ 70, Suspeita < 40 | Léo finalmente nota ela… e oferece **o cargo de Vice-Coordenadora da Missão**. Ela aceita, chorando. Ambíguo de propósito. |
| 6 | **Ele Nunca Soube** | Fallback: nenhum outro bateu | Tudo funcionou, ninguém percebeu, e o Léo continua sem perceber. Ela narra o próprio arquivo de vitórias para uma sala vazia. |
| 7 | *(secreto)* **O Confidente Era o Protagonista** | Arquivo ≥ 30 gravações e Lealdade ≤ 10 | Revelação: o jogo inteiro era o podcast do Prof. Aurélio. Créditos na voz dele. |

---

## 8. Avisos de ficção e direção de tom

### 8.1 Avisos (implementação)
1. **Tela de boot obrigatória** (`FictionDisclaimer.tscn`), que não dá para pular na primeira execução. Ela fica 4 s com o texto e só depois mostra o botão "Entendi".
2. **Texto canônico** num único recurso localizado (`DISCLAIMER_MAIN`), para que ninguém altere o texto por acidente:
   > *"Este é um jogo de ficção satírica e dark comedy. Nenhuma ação real é incentivada. Todos os personagens e eventos são caricaturas exageradas."*
3. **Rodapé persistente** no menu de pausa e na tela de save.
4. **Antes de cada cutscene de método Extremo:** card curto estilo teatro, "🎭 Isto é uma encenação absurda. Ninguém se machuca. Todos voltam no epílogo."
5. **Créditos:** aviso de novo, mais a linha "Qualquer semelhança com pessoas reais é coincidência e, sinceramente, preocupante."
6. **Página na loja e README:** mesmo texto.
7. Registro em save de que o aviso foi visto (`settings.cfg → disclaimer_ack=true`). Ele reaparece se a versão do texto mudar.

### 8.2 Bíblia de tom (para roteiristas)
- **Regra do Contraste:** toda cena-chave tem uma **fala pública** e um **pensamento** em balões diferentes (cinza contra rosa).
- **Alvo da piada:** a hipocrisia, o jargão, a cultura de lacração e de nota oficial, a vaidade intelectual, a obsessão. **Nunca** grupos vulneráveis, aparência física ou saúde mental como ofensa. A Obsessão é tratada como trope de anime, não como diagnóstico.
- **Sem nomes reais**, sem partidos reais, sem logos reais. O MAL e os outros movimentos são invenção.
- **Escalada visual, não de violência:** quanto mais extremo, mais *teatral* (cortinas, holofotes, coro grego de comentaristas).
- **O Léo nunca é humilhado de verdade.** Ele é o "eixo imóvel" da comédia.
- **Teste do absurdo:** se uma cena poderia funcionar como instrução no mundo real, reescreva até ficar ridícula.

### 8.3 Exemplos de voz
| Contexto | Fala pública | Pensamento |
|---|---|---|
| Léo elogia a Júlia | "Ótimo trabalho, Júlia! Dados são fundamentais." | *"Fundamental vai ser a tua transferência pra filial de Roraima."* |
| Live, pergunta sobre ciúmes | "Ciúme é uma emoção humana que merece análise sem julgamento." | *"Análise feita. Julgamento: culpada."* |
| Rejeição do prólogo | "Claro, Léo! Super entendo. A Missão primeiro." | *"A Missão primeiro. Eu segundo. Todo o resto… em lugar nenhum."* |
| Desabafo com o Prof. Aurélio | — | "Professor, posso te mandar um áudio rapidinho?" *(áudio de 23 min)* |

---

## 9. Arquitetura técnica (Godot 4)

### 9.1 Estrutura de pastas
```
res://
├─ addons/                      # dialogic (opcional), gut (testes)
├─ assets/
│  ├─ art/{characters,environments,ui,stage_fx}
│  ├─ audio/{music,sfx,voice}
│  └─ fonts/
├─ data/                        # TODOS os .tres (conteúdo desacoplado do código)
│  ├─ characters/               # CharacterData
│  ├─ rivals/                   # RivalData
│  ├─ methods/{social,political,narrative,extreme}/
│  ├─ weeks/                    # WeekData (week_01.tres … week_10.tres)
│  ├─ events/                   # GameEvent (crises, aleatórios)
│  ├─ assets_narrative/         # NarrativeAssetData (modelos de print/áudio/thread)
│  ├─ endings/                  # EndingData
│  ├─ obsession_tiers/          # ObsessionTier
│  └─ dialogue/                 # .dialogue / .dtl por semana
├─ localization/                # pt_BR.csv, en.csv (disclaimer incluso)
├─ scenes/
│  ├─ boot/   (Boot, FictionDisclaimer)
│  ├─ menus/  (MainMenu, Pause, SaveLoad, Settings)
│  ├─ phases/ (MorningFeed, Headquarters, EveningLive, NightConfession, Resolution)
│  ├─ weekly/ (WeekHub, WeekendCrisis, WeekMonologue)
│  ├─ endings/(EndingEvaluator, Ending_*.tscn, Credits)
│  ├─ world/  (Player, NPC, Leo, InteractionZone, StageOverlay)
│  └─ ui/     (HUD, MetricsPanel, ObsessionMeter, DualSpeechBubble, Inventory, Phone)
├─ scripts/
│  ├─ autoload/   # singletons
│  ├─ resources/  # classes Resource (data models)
│  ├─ systems/    # lógica pura, testável
│  ├─ ai/         # rotinas de NPC, percepção, testemunhas
│  └─ ui/
└─ tests/
```

### 9.2 Autoloads (singletons)
| Autoload | Responsabilidade |
|---|---|
| `EventBus` | Sinais globais (`obsession_changed`, `metric_changed`, `rival_neutralized`, `recording_added`, `leak_triggered`, `phase_started`…) |
| `GameState` | Estado da run: semana, dia, fase, métricas, flags, inventário. Serializável. |
| `ObsessionSystem` | Aplica deltas, calcula a faixa e emite a troca de faixa |
| `ReputationSystem` | CP/CN/RJ/AI/Suspeita, com clamp, decay diário e limites que disparam finais |
| `ConfidantSystem` | Arquivo, Confiança, Lealdade e avaliação noturna de traição |
| `NeutralizationSystem` | Valida pré-requisitos, executa métodos, resolve testemunhas |
| `TimeManager` | Relógio de jogo, fases e transições de dia/semana |
| `WeekDirector` | Carrega o `WeekData`, agenda eventos, controla prazos de rival |
| `EndingEvaluator` | Avalia os `EndingData` em ordem de prioridade |
| `SaveManager` | JSON versionado em `user://saves/` |
| `ToneDirector` | Troca paleta, trilha, pós-processamento e "stage mode" conforme a faixa de Obsessão |

### 9.3 Data models (Resources)

```gdscript
# scripts/resources/metric_delta.gd
class_name MetricDelta extends Resource
@export var obsession := 0.0
@export var credibility := 0.0       # CP
@export var narrative_control := 0.0 # CN
@export var legal_risk := 0.0        # RJ
@export var internal_support := 0.0  # AI
@export var suspicion := 0.0
@export var leo_attention_to_player := 0.0
```

```gdscript
# scripts/resources/character_data.gd
class_name CharacterData extends Resource
@export var id: StringName
@export var display_name: String
@export var portrait: Texture2D
@export var public_voice_tags: PackedStringArray   # p/ geração de falas
@export var routine: Array[RoutineStep]            # onde está a cada hora
@export var perception_radius := 6.0               # testemunha
```

```gdscript
# scripts/resources/rival_data.gd
class_name RivalData extends CharacterData
@export var week: int
@export var threat_reason: String                  # "Léo elogiou o gráfico dela"
@export var attention_gain_per_day := 5.0
@export var weaknesses: Array[StringName]          # tags que métodos exploram
@export var resistances: Array[StringName]
@export var neutralized_epilogue: String           # destino absurdo e feliz
```

```gdscript
# scripts/resources/neutralization_method.gd
class_name NeutralizationMethod extends Resource
enum Category { SOCIAL, POLITICAL, NARRATIVE, EXTREME_THEATRICAL }
@export var id: StringName
@export var display_name: String
@export var category: Category
@export var min_obsession := 0
@export var required_items: Array[StringName]
@export var required_location: StringName
@export var time_window := Vector2i(13, 18)        # horas
@export var exploits_tags: Array[StringName]       # casa com weaknesses
@export var base_success := 0.6
@export var on_success: MetricDelta
@export var on_fail: MetricDelta
@export var on_witnessed: MetricDelta
@export var stage_cutscene: PackedScene            # só EXTREME
@export var stage_disclaimer := true
```

```gdscript
# scripts/resources/narrative_asset.gd
class_name NarrativeAsset extends Resource
enum Kind { PRINT, AUDIO, THREAD, LIVE_CLIP, ALLIANCE, ACCUSATION, OFFICIAL_NOTE }
enum Veracity { REAL, EDITED, FABRICATED }
@export var kind: Kind
@export var veracity: Veracity
@export var weight := 1.0      # impacto
@export var trace := 0.0       # 0..1, rastro até a protagonista
@export var target: StringName
```

```gdscript
# scripts/resources/recording.gd
class_name Recording extends Resource
@export var week: int
@export var day: int
@export var severity := 1                 # 1..5, derivada da Obsessão
@export var transcript_key: String        # chave de localização (cômico)
@export var mentions: Array[StringName]   # rivais/Léo citados
```

```gdscript
# scripts/resources/week_data.gd
class_name WeekData extends Resource
@export var number: int
@export var title: String
@export var rival: RivalData              # pode ser nulo em semanas abstratas
@export var unlocks: Array[StringName]    # sistemas/métodos novos
@export var scheduled_events: Array[GameEvent]
@export var weekend_crisis: GameEvent
@export var monologue_timeline: String    # diálogo da cutscene final
```

```gdscript
# scripts/resources/game_event.gd
class_name GameEvent extends Resource
@export var id: StringName
@export var day := -1                     # -1 = aleatório
@export var conditions: Array[Condition]
@export var choices: Array[EventChoice]
```

```gdscript
# scripts/resources/condition.gd   (reutilizado por eventos e finais)
class_name Condition extends Resource
enum Op { GTE, LTE, EQ, FLAG_SET, COUNT_GTE }
@export var key: StringName               # "obsession", "legal_risk", "flag:pendrive_paid"…
@export var op: Op
@export var value: float
func evaluate(state: GameState) -> bool: return state.check(key, op, value)
```

```gdscript
# scripts/resources/ending_data.gd
class_name EndingData extends Resource
@export var id: StringName
@export var priority: int                 # menor = avaliado primeiro
@export var all_of: Array[Condition]
@export var any_of: Array[Condition]
@export var scene: PackedScene
@export var is_secret := false
```

```gdscript
# scripts/resources/obsession_tier.gd
class_name ObsessionTier extends Resource
@export var min_value: int
@export var name_key: String
@export var palette: Gradient
@export var music_layer: AudioStream
@export var verbal_leak_chance := 0.0
@export var unlocked_categories: Array[int]
@export var stage_mode := false
```

### 9.4 Sistemas: lógica de referência

```gdscript
# scripts/systems/confidant_system.gd (trecho)
func evaluate_night(s: GameState) -> void:
    var pressure := _archive_severity() * 2.0 + s.legal_risk * 0.5 + s.suspicion * 0.3
    var protection := s.confidant_loyalty + s.confidant_trust * 0.2 + s.favors_paid * 5.0
    if s.week >= 4 and pressure > protection and not s.flags.has(&"pendrive_active"):
        EventBus.confidant_ultimatum.emit()

func record_confession(s: GameState) -> void:
    var rec := Recording.new()
    rec.week = s.week; rec.day = s.day
    rec.severity = clampi(int(s.obsession / 20.0) + 1, 1, 5)
    archive.append(rec)
    s.confidant_trust = minf(s.confidant_trust + 4, 100)
    EventBus.recording_added.emit(rec)
```

```gdscript
# scripts/systems/neutralization_system.gd (trecho)
func try_execute(m: NeutralizationMethod, rival: RivalData, s: GameState) -> Result:
    if s.obsession < m.min_obsession: return Result.locked()
    var chance := m.base_success
    for t in m.exploits_tags:
        if t in rival.weaknesses: chance += 0.15
        if t in rival.resistances: chance -= 0.2
    var witnessed := Perception.any_witness(s.player_pos, s.hour)
    var ok := randf() < clampf(chance, 0.05, 0.95)
    ReputationSystem.apply(m.on_success if ok else m.on_fail)
    if witnessed: ReputationSystem.apply(m.on_witnessed)
    if ok and m.category == NeutralizationMethod.Category.EXTREME_THEATRICAL:
        StageDirector.play(m.stage_cutscene, m.stage_disclaimer)
    return Result.new(ok, witnessed)
```

### 9.5 Componentes de UI essenciais
- **DualSpeechBubble:** balão público (cinza, sans-serif) e balão interno (rosa, manuscrito, tremido). No vazamento verbal, o texto interno "escorre" para o balão público.
- **ObsessionMeter:** um coração cinza que vai se enchendo de rosa, rachando e pegando fogo.
- **Phone:** feed, DMs, gravador e contato do Prof. Aurélio (que mostra "digitando…" de forma suspeita).
- **MetricsPanel:** 4 barras, com a Suspeita representada só por um "olho" que abre aos poucos.
- **StageOverlay:** cortinas, holofotes e coro, usado nos Extremos e nos finais.

### 9.6 Notas para Unity
`Resource` → `ScriptableObject`; Autoloads → `MonoBehaviour` singletons em uma cena `Bootstrap` com `DontDestroyOnLoad`, ou um container DI (VContainer/Zenject); `EventBus` → `ScriptableObject` event channels; diálogos → Yarn Spinner ou Ink; save → `JsonUtility`/Newtonsoft com versão.

### 9.7 Save e versionamento
```json
{
  "save_version": 1,
  "week": 4, "day": 2, "phase": "HEADQUARTERS",
  "metrics": { "obsession": 63, "cp": 58, "cn": 41, "rj": 37, "ai": 66, "suspicion": 29 },
  "confidant": { "trust": 72, "loyalty": 44, "favors_paid": 2, "archive": [ { "w":1,"d":3,"sev":2 } ] },
  "rivals": { "julia_planilha": "neutralized:transfer_roraima" },
  "flags": ["pendrive_active"],
  "inventory": [ { "kind":"PRINT","veracity":"EDITED","trace":0.4,"target":"caio_thread" } ]
}
```

### 9.8 Testes automatizados (GUT)
- Faixas de Obsessão: limites 24/25, 49/50, 74/75, 89/90.
- `EndingEvaluator`: cada final alcançável com um estado mínimo, e a prioridade respeitada.
- Gatilho de traição: tabela de casos (pressão contra proteção).
- Clamp das métricas e disparo dos finais por limite (RJ 100, CP 0).

---

## 10. Pipeline de conteúdo
- **Diálogos** em arquivos por semana (`data/dialogue/week_03.dtl`), sempre com duas trilhas: `public:` e `inner:`.
- **Chaves de localização** desde o dia 1 (pt-BR primeiro, en depois). O humor de jargão precisa de tradução adaptada, não literal.
- **Planilha de balanceamento** (CSV, importada como `.tres` por um script de editor) para os deltas dos métodos.
- **Checklist de revisão de tom** em toda PR de conteúdo: sem nomes reais? os Extremos são teatrais? há contraste público/interno? passa no teste do absurdo?

---

## 11. Roadmap sugerido

| Marco | Escopo | Critério de pronto |
|---|---|---|
| **M0: Protótipo cinza** | Aviso de ficção, loop de 1 dia, Obsessão, 2 métricas, 1 rival, 2 métodos Sociais | Dá para jogar um dia inteiro e ver as métricas mudarem |
| **M1: Vertical slice** | Semana 1 completa, DualSpeechBubble, Live, Desabafo, cutscene de monólogo | Uma semana jogável do começo ao fim |
| **M2: Sistemas completos** | 4 métricas, Confidente com traição, as 4 categorias de método, 3 finais | Semanas 1 a 4 jogáveis |
| **M3: Conteúdo** | Semanas 5 a 10, todos os finais, StageOverlay | Run completa |
| **M4: Polimento** | Arte final, áudio, localização, balanceamento, acessibilidade (legenda, sem flashes) | Build de release |

---

## 12. Próximos passos imediatos
1. Fechar o título e os nomes definitivos (todos fictícios).
2. Montar o projeto Godot com a estrutura de pastas e os autoloads vazios.
3. Implementar `GameState`, `ObsessionSystem` e `FictionDisclaimer`.
4. Escrever o roteiro do Prólogo e da Semana 1 nas duas trilhas (pública e interna).
5. Fazer playtest de "papel e caneta" com os números das tabelas da seção 4 antes de codar o balanceamento.
