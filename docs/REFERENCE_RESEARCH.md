# Pesquisa de referência — Snowboard Kids 1 e 2 (N64)

Objetivo: entender **sistemas de design** para um sucessor espiritual original. Nada de nomes, personagens, arte, música,
mapas ou interface é copiado. Limitação: as páginas não puderam ser abertas (domínios bloqueados pela rede da sessão);
o conteúdo vem de trechos de resultados de busca e precisa de verificação antes de virar regra.

## Mecânicas relatadas
- Cada volta é uma descida; teleférico leva ao topo e protege de ataques. Voltas variam por pista (2–9, típico 3).
- Dinheiro vem de moedas e sobretudo de manobras (150–500 por manobra); item custa 100. SBK1 derrubava quem entrava
  na caixa sem dinheiro; SBK2 removeu a punição.
- Dois slots (ataque / suporte). Caixas de duas cores. O item seguia sequência fixa por cor e posição (explorável).
- Itens incluem congelar, transformar em boneco sem direção, lançar ao alto, bomba, fantasma teleguiado ao líder,
  pedra, ventilador (impulso), invisibilidade; SBK2: frigideira em área, pena (mais tempo no ar), furacão (rouba inventário).
- Salto carregado sem poder virar durante a carga; manobras próprias por personagem; manobra em terreno irregular derruba.
- Modos: corrida, skill games (coleta de impulsos, tiro ao alvo, manobras), time attack; SBK2 com hub, história e chefes.
- Atributos em 3 eixos (velocidade, curva, manobra); pranchas em 3 linhas com upgrades.
- Crítica recorrente: ritmo lento e rubber-banding forte da IA.

## Já coberto pela nossa implementação
Descidas + teleférico com invulnerabilidade (fila FIFO, 1 s de invulnerabilidade na saída); moedas de pista e de manobra;
estações a 20 moedas sem punição (alinhado ao SBK2); 2 slots; sorteio **ponderado por posição** (não previsível);
salto carregado com curva reduzida a 35 % durante a carga; recuperação curta após golpe (cooldown 2 s, queda 0,8–1,4 s);
assistência da IA limitada a 5 %.

## Lacunas candidatas (soluções originais, não implementadas)
1. Descidas por pista (equilibrar duração) em vez de 5 fixas.
2. Item teleguiado ao líder e item que faz o rival perder o inventário.
3. Item de tempo no ar que aumenta o ganho das manobras.
4. Manobra-assinatura por piloto.
5. Upgrades de prancha compráveis.
6. Desafio de tiro ao alvo.
7. Pistas secretas por ouro em todas as copas.

## Fontes (apenas em resultados de busca)
en.wikipedia.org/wiki/Snowboard_Kids · en.wikipedia.org/wiki/Snowboard_Kids_2 · giantbomb.com (SBK, SBK2) ·
backloggd.com/games/snowboard-kids · nintendolife.com/reviews/2010/09/snowboard_kids_retro · gamefaqs.gamespot.com (FAQs SBK) ·
speedrun.com/sbk (fórum) · strategywiki.org/wiki/Snowboard_Kids_2/Boards · freezenet.ca (review SBK2)
