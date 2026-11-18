# Ponto de Ruptura

Jogo de estratégia em tempo real sobre dissuasão nuclear, feito para o navegador do celular (também roda no computador). É uma obra original do gênero "guerra fria em tempo real": mapa, facções, regras e visual são próprios.

## Como jogar

Abra `index.html` no navegador. Não precisa de instalação nem de servidor.

- Você comanda uma de quatro potências num planeta gerado a cada partida, mostrado como um globo 3D (WebGL). Arraste para girar, use pinça ou a roda do mouse para zoom, e o botão ⌖ para voltar à sua nação. As distâncias, o alcance dos mísseis e os escudos são medidos sobre a esfera.
- **Silos** guardam até 3 mísseis e recarregam sozinhos. **Escudos** já nascem com 1 míssil de defesa, guardam até 2 (recarga de 10 s) e disparam contra mísseis estrangeiros que passam por perto.
- **Anexe** regiões neutras ou em ruínas que façam fronteira com as suas. Cada território coletado rende na hora ¤4 por milhão de habitantes, além de aumentar a renda contínua.
- A **tensão** sobe com o tempo e a cada provocação. Lançamentos só ficam liberados a partir de 50.
- Cada ataque alimenta o **Inverno**, que escurece o mapa e deixa os rivais mais cautelosos. Ele não encerra a partida.
- **Pesquisa**: Economia (+¤0,6/s fixos por nível, que bombas não reduzem), Alcance, Propulsão, Escudos e Ogivas, três níveis cada.
- **Modo Cúpula**: vence quem tiver a maior população quando a Cúpula de Paz se reunir (10 minutos de jogo) ou a última nação de pé.
- **Modo Sobrevivência**: sem relógio. A partida só acaba quando sobrar uma única nação. Depois de 8 minutos a guerra escala: o alcance dos mísseis e a agressividade de todos crescem com o tempo, e ruínas com radiação acima de 30% não podem ser reocupadas.

- **Rota do míssil**: ao mirar num alvo, escolha reta, curva leve ou forte para cada lado, ou **Ponto** (toque no globo por onde o míssil deve passar). A prévia mostra em vermelho os trechos que cruzam escudos inimigos prontos. Rotas mais longas demoram mais.

Controles: arraste para girar o globo; toque/clique numa região para agir. Setas do teclado também giram o globo. Botões no topo: Pesquisa, velocidade (1×/2×/3×) e pausa. No teclado, espaço pausa e Esc fecha o painel.
