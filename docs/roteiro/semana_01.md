# Semana 1 — “Dados São Fundamentais”

> Roteiro ficcional. Diálogos, pensamentos e situações são inventados (ver `docs/GDD.md`, seção 0). A versão jogável está em `data/weeks/week_01.json`.

## Rival: Júlia Planilha (personagem fictícia)

Estagiária de dados do Movimento. Fala em “insights”. Tem 14 abas abertas no Excel e um gráfico de pizza como foto de perfil.

**Ameaça:** O Renan elogiou o gráfico dela: “Dados são fundamentais para a Missão.”

- Atenção do Renan para ela começa em **30** e sobe **+7/dia**. Se chegar a **50** no domingo, ela ganha um Momento com o Renan (+15 de Obsessão).
- Ciúme diário: Obsessão + 5 % da atenção dela.
- **Epílogo se for neutralizada:** Júlia virou Head de Dados de um instituto de pesquisa em Lisboa. Hoje faz gráficos de pizza de pastel de nata. Está radiante.

## Loop diário

1. **Manhã:** evento do feed + Post do Dia
2. **Tarde:** 3 horários na Sede (13h, 15h, 17h)
3. **Noite:** Live com 3 perguntas
4. **Madrugada:** desabafo (ou não) com o Teacher
5. **Resolução:** ciúme, atenção da rival e avaliação do Confidente

## Feed (por dia)

- **Dia 1:** 📱 O Renan curtiu um post da Júlia: “Engajamento +4% 📊”. `[obsession +3]`
- **Dia 2:** 📱 A Júlia postou story: “Café com a equipe ☕”. O Renan aparece no canto, desfocado. Você dá zoom. Ainda desfocado. Você dá zoom de novo. `[obsession +4]`
- **Dia 3:** 📱 Trending: #PizzaChartGate. Ninguém sabe o que é. Você já tem opinião formada. `[narrative_control +2]`
- **Dia 4:** 📱 O Renan postou: “Foco na Missão.” Sem curtir nada de ninguém. Você se sente estranhamente em paz. `[obsession -3]`
- **Dia 5:** 📱 A Júlia marcou o Renan num meme de planilha. Ele respondeu com 👍. UM JOINHA. Você relê 41 vezes. `[obsession +6]`

## Post do Dia

- **Thread: “Por que o debate precisa de nuance (1/23)”**: “Fio sobre nuance. Vai ser longo. Como deve ser.” / *23 tweets. Ele lê até o fim. Ele PRECISA ler até o fim.* `[credibility +3]`
- **Indireta: “Gráfico de pizza não é argumento.”**: “Só uma reflexão metodológica, sem citar ninguém. 🍕❌” / *Citando alguém. Citando muito.* `[narrative_control +3 · suspicion +4 · obsession -4]`
- **Foto da caneca “NUANCE” com a legenda “segunda-feira produtiva”**: “Bom dia, gente. Café e equilíbrio.” / *Ângulo escolhido para aparecer o reflexo da sede do Movimento na caneca. Sutil.* `[internal_support +2 · credibility +1]`

## Sede: ações

- **Observar a Júlia de longe (com um livro de cabeça para baixo)**: “Só lendo aqui. Epistemologia.” / *Ela usa VLOOKUP. Em 2026. Anotado.* → Você aprendeu a rotina da Júlia: almoça às 12h, faz pausa no bebedouro às 15h, entra em pânico quando a planilha trava. `[suspicion +2]`
- **“Passar por acaso” perto da sala do Renan (pela 4ª vez)**: “Oi, Renan! Nossa, que coincidência.” / *Coincidência calculada com margem de erro de 3 minutos.* → O Renan acena sem tirar os olhos do documento “MISSÃO_v47_final_FINAL.docx”. `[obsession +5 · renan_attention +3]`
- **Ajudar a revisar o texto de um panfleto do Movimento**: “Posso sugerir uma vírgula? E uma nuance?” / *Ajudar o Movimento é ajudar o Renan. Ajudar o Renan é ajudar a gente.* → O panfleto agora tem 11 vírgulas a mais e a palavra “dialético” duas vezes. `[internal_support +5 · obsession -2]`
- **Yoga epistemológica no terraço (hobby saudável)**: “Inspira… tons de cinza… expira…” / *Inspira… Renan… expira… Júlia não…* → Você se sente 3% mais centrada. Uma pomba te observa com julgamento. `[obsession -5]`

## Sede: métodos (todos sociais nesta semana)

- **O Seminário Infinito** (chance-base 55 %, chance de testemunha 20 %): Puxar a Júlia para uma conversa de 2 horas sobre “a epistemologia dos gráficos de pizza”.
  - Fala: “Júlia, você já pensou na dimensão ontológica de um gráfico de pizza?” / *Ela não vai sair dessa conversa até o Renan ir embora.*
  - ✅ Duas horas depois, a Júlia sai com o olhar perdido e três livros recomendados. O Renan foi embora há 40 minutos. `[rival_attention -20 · credibility +1]`
  - ❌ A Júlia ADOROU. Pediu para continuar amanhã. E chamou o Renan para participar. Ele não foi, mas foi CHAMADO. `[obsession +4 · credibility -2]`
- **O Elogio Constrangedor** (chance-base 60 %, chance de testemunha 100 %): Elogiar a Júlia na frente de todo mundo, com tanta intensidade que ela fica sem graça de aparecer.
  - Fala: “Gente, a Júlia é um GÊNIO. Uma visionária. A Simone de Beauvoir das tabelas dinâmicas!” / *Brilha, Júlia. Brilha até sumir.*
  - ✅ A Júlia fica vermelha, murmura “obrigada…” e passa o resto do dia escondida atrás do monitor. `[rival_attention -15 · internal_support +2]`
  - ❌ O Renan concorda: “Verdade, ela é ótima.” Você acabou de fazer marketing da rival. `[rival_attention +5 · obsession +3]`
- **A Vaga dos Sonhos** (chance-base 45 %, chance de testemunha 30 %): Apresentar a Júlia a um “contato” que oferece uma vaga de Head de Dados num instituto em Lisboa. Pré-requisito: flag:julia_cansada, intel:2, flag:ficha_julia.
  - Fala: “Júlia, conheço um pessoal em Lisboa que ia AMAR seu trabalho. Posso te apresentar?” / *Lisboa. 8 mil quilômetros. Fuso de 4 horas. Perfeito.*
  - ✅ Uma semana depois, a Júlia anuncia no LinkedIn: “Novo desafio! 🇵🇹📊”. O Renan comenta: “Sucesso. A Missão agradece.” Você também agradece. `[neutralize · credibility +2]`
  - ❌ A Júlia agradece mas recusa: “Meu lugar é na Missão!” Ela disse MISSÃO. Com M maiúsculo. Que ousadia. `[obsession +5 · suspicion +3]`
- **🔒 Thread “Uma reflexão sobre a Júlia (com nuance)”**: Liberado com Obsessão ≥ 50 (Dialética Possessiva). *Você ainda é ponderada demais para isso. Por enquanto.*
- **Pedir ao Teacher a “Ficha da Rival” (custa um áudio)**: “Oh, the girl with the pizza? I did a little research, dear. Ela sonha em morar em Portugal. Está tudo aqui. Também gravei este pedido, aliás. For your own good.” (+15 % nos métodos, gera uma gravação)

Bônus de chance: +10 % por observação (máximo de 2), +5 % por fraqueza explorada, +15 % com a Ficha do Teacher.

## Live: perguntas

Três tipos de resposta: **ponderada** (sobe a Credibilidade), **indireta** (Narrativa e Suspeita sobem, alivia a Obsessão) e **sincera** (só com Obsessão ≥ 40: derruba a Credibilidade e alivia muito a Obsessão).

**@racional_88: Qual sua opinião sobre gráficos de pizza?**
- *ponderada*: “Todo recurso visual tem méritos e limitações. Contexto é tudo.” `[credibility +2 · obsession +2]`
- *indireta*: “Digamos que quem usa gráfico de pizza tem… fome de atenção.” `[narrative_control +3 · suspicion +3 · obsession -2]`
- *sincera*: “Gráfico de pizza é a arma das estagiárias que querem roubar o que é dos outros.” `[credibility -6 · suspicion +6 · obsession -6]`

**@bot_do_debate: Você e o Renan são próximos?**
- *ponderada*: “Temos uma relação institucional de respeito mútuo.” `[credibility +2 · obsession +2]`
- *indireta*: “Próximos o suficiente para eu saber que ele prefere tabelas bem formatadas.” `[narrative_control +2 · suspicion +4]`
- *sincera*: “Próximos? Eu sei o horário em que ele toma café. Os três horários.” `[credibility -5 · suspicion +8 · obsession -5]`

**@duvidosa_cinza: Por que você fala tanto em “tons de cinza”?**
- *ponderada*: “Porque a realidade é complexa e o debate merece nuance.” `[credibility +1 · obsession +1]`
- *indireta*: “Porque algumas pessoas só enxergam fatias de pizza.” `[narrative_control +2 · suspicion +3 · obsession -2]`
- *sincera*: “Porque cinza é a cor da sala do Renan. Eu contei. São quatro tons.” `[credibility -5 · suspicion +7 · obsession -5]`

**@militante_lucido: O que você acha da Missão?**
- *ponderada*: “Um projeto relevante que merece análise crítica e construtiva.” `[credibility +1 · internal_support +2 · obsession +2]`
- *indireta*: “A Missão é linda. Pena que algumas pessoas só querem aparecer nela.” `[narrative_control +2 · suspicion +3]`
- *sincera*: “A Missão é minha rival número um. A Júlia é a número dois.” `[credibility -6 · suspicion +8 · obsession -6]`

**@estudante_de_dados: Dica para quem está começando na política?**
- *ponderada*: “Leia muito, ouça os dois lados e desconfie de certezas.” `[credibility +1 · obsession +1]`
- *indireta*: “Não confie em quem tem 14 abas de Excel abertas.” `[narrative_control +2 · suspicion +4 · obsession -2]`
- *sincera*: “Fique longe do Renan. Ele é comprometido. Com a Missão. E comigo, um dia.” `[credibility -6 · suspicion +9 · obsession -6]`

**Vazamento verbal** (Obsessão ≥ 75): “…e por isso o diálogo é tão import— ELA PRECISA SAIR DO CAMPO DE VISÃO DELE. Quer dizer. Próxima pergunta.”

## Madrugada: Arquivo Wellington (transcrições fictícias)

- Gravidade 1: “Teacher, ele respondeu ‘ok’ com ponto final. Com PONTO FINAL. Isso é passivo-agressivo ou institucional?”
- Gravidade 2: Áudio de 17 minutos analisando o 👍 que o Renan deu num meme da Júlia. Com bibliografia.
- Gravidade 3: “Montei uma matriz SWOT do nosso relacionamento. Ameaça: a Missão. Fraqueza: a Missão. Oportunidade… a Missão.”
- Gravidade 4: “Se a Júlia aparecer de novo no story dele, eu solto uma thread COM NUANCE sobre gráficos de pizza. Com nuance, Teacher.”
- Gravidade 5: 41 minutos, parte deles cantados, terminando em “mas eu sou uma pessoa racional, né?”.

Respostas do Teacher:
- “Oh, dear. Só uma correção: é “I’m fine”, não “I am very fine”. Continue.”
- “Fica tranquila. Isso fica só entre nós. *clique* *clique* *clique*”
- “Very interesting. Você poderia repetir a parte da planilha? O áudio cortou. Para eu… entender melhor.”
- “I’m just worried about you. Por isso eu fiz backup. Três backups.”

Sem desabafo: Você não manda áudio. Fica olhando o teto e ensaiando o que diria. A Obsessão sobe de tanto ruminar.

## Sábado: A Reunião de Pauta

O Renan precisa de alguém para apresentar os dados da semana na reunião geral do Movimento.

**Se a Júlia já saiu:** Sem a Júlia, ele olha em volta. “Espectro Cinza, você pode apresentar? Você sempre traz… nuance.”
- “Claro, Renan. Será uma honra institucional.” / *ELE DISSE MEU NOME. EM VOZ ALTA. NA FRENTE DE TODOS. ISSO É PRATICAMENTE UM NOIVADO.*

**Se ela continua:** “Júlia, apresenta você? Seu gráfico de pizza ficou ótimo.” A Júlia sorri. Você também. Por fora.
- **Pedir para “complementar com uma visão qualitativa”**: “Posso só complementar com uma visão qualitativa?” / *Vou complementar até sobrar só eu na tela.* `[internal_support +3 · rival_attention -10 · suspicion +3]`
- **Aplaudir de pé (sozinha)**: “Bravo! Bravíssimo! Dados são fundamentais!” / *Aplaudindo por fora. Por dentro também, mas com sarcasmo.* `[credibility -2 · obsession +4 · rival_attention +5]`
- **Respirar fundo e deixar passar**: “Ótimo, Júlia.” / *Tons de cinza. Tons de cinza. Tons de cinza.* `[credibility +2 · obsession +6]`

## Domingo

- **Momento (atenção ≥ 50):** Domingo. Você vê no story da Júlia: ela e o Renan, cinco minutos olhando juntos para uma planilha. Legenda: “Trabalho de domingo 💪📊”.
- **Calmo:** Domingo. O Renan passa o dia offline. “Retiro estratégico da Missão.” Você também passa o dia offline. Estrategicamente.

## Monólogo (Júlia neutralizada)

> Palco. Holofote cinza. Uma fatia de pizza solitária desce do teto num fio dourado. É um lustre. Um lustre de pizza.

*Júlia, vá em paz. Lisboa é linda nesta época do ano. Todas as épocas, aliás. Fique em todas elas.*

*Eu não fiz nada errado. Eu fiz networking. Networking é ciência.*

*Uma a menos. Agora é só eu, o Renan… e a Missão.*

> A palavra “MISSÃO” acende em neon atrás dela. Ela estreita os olhos.

## Monólogo (Júlia continua)

> Palco. Holofote cinza. Uma pizza inteira gira no teto, como uma bola de espelhos.

*Ela ainda está lá. Com os gráficos dela. Com as fatias dela.*

*Tudo bem. Tudo bem. A ciência é feita de tentativas. A próxima tentativa vai ser… mais científica.*

> As pétalas cinza começam a cair com um leve tom de rosa. Ninguém percebe. Ela percebe.

🎭 SEMANA 2 — “O Fio de 47 Tweets” (em breve)
