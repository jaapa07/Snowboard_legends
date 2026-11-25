# SNOWBOARD LEGENDS 3D
## Master Game Specification — v3.0

Documento de implementação integral • PC nativo • Português brasileiro

## 1. Referência e identidade
Fonte: Snowboard Kids (N64) Gameplay.mp4, 414,81 segundos. Inspeção por amostras visuais a cada 20 segundos, não análise quadro a quadro. 00:40: menu Battle Race, Skill Game, Time Attack, Board Shop, Exit/Save; 01:00: Rookie Mt.; 01:20–06:00: descida em terceira pessoa, cinco voltas, moedas, dois slots de itens, posição, indicador vertical de competidores, curvas com sinalização, rampas, estação de retorno e efeitos de impacto; 06:00: classificação e recompensa; 06:20: loja de pranchas, categorias Free Style e All Around. Os tempos são aproximados. Valores de física, economia, nomes e conteúdo abaixo são propostas originais; não são medições do jogo original.

Criar um sucessor espiritual, não uma reprodução: não copiar modelos, mapas, músicas, nomes, logotipos ou interface do original. Visual 3D estilizado, proporções caricatas, neve colorida, silhuetas legíveis e animações expressivas. Público geral. Partidas de 3–6 minutos. O jogador deve sentir velocidade, domínio da prancha e rivalidade divertida.

## 2. Entrega obrigatória
- Projeto Godot 4.x estável com GDScript tipado, project.godot, export_presets.cfg e build nativa Windows x64; Linux x64 quando ambiente permitir. Fixar versão exata do editor e templates no README.
- Campanha com 8 pistas, 8 personagens, 12 pranchas, 10 itens, 4 modos e progressão persistente.
- Corridas de 4 participantes, jogador contra IA ou multiplayer local de 2–4 jogadores; preencher vagas com IA opcionalmente.
- Sem backend obrigatório, sem serviços pagos obrigatórios, sem assets remotos indispensáveis.
- Não declarar funcionalidades concluídas sem implementação e teste. Não entregar apenas menu, demo ou cenário vazio. Não usar cubos como personagens finais, botões inertes, áudio silencioso ou pistas duplicadas com simples troca de cor.

## 3. Stack e arquitetura
Godot 4.x, GDScript tipado, renderizador Forward+ com perfil Compatibility opcional. Blender para autoria, glTF/GLB para intercâmbio. CharacterBody3D para pilotos, ShapeCast3D para contato e recuperação, Area3D para gatilhos, StaticBody3D para terreno, AnimationTree e Skeleton3D para animação, GPUParticles3D para efeitos, Control para UI. Simulação em _physics_process a 60 Hz, interpolação visual, RNG com seed. Nada de HTML, WebGL, Canvas 2D ou motor web. CanvasItem interno do Godot é permitido apenas para HUD e menus, não gameplay.

```text
project.godot
export_presets.cfg
scenes/{menus,race,riders,tracks,items,ui}/
scripts/{core,physics,race,rider,tricks,items,ai,camera,save}/
resources/{riders,boards,tracks,items}/
assets/{models,textures,sprites,audio,fonts}/
source_art/ tools/ tests/ docs/ builds/
```
Contratos Resource tipados: RiderDefinition, BoardDefinition, TrackDefinition, ItemDefinition; RaceManager controla fases, ranking e checkpoints; RiderController recebe InputCommand de jogador ou IA; SaveService usa user:// e escrita atômica; AssetRegistry valida manifesto. Sinais para HUD e áudio; não acoplar física à UI. Cada pista é PackedScene com terreno autoral, Path3D de navegação, checkpoints Area3D, pontos de spawn e estação de retorno. Multiplayer via SubViewportContainer com câmeras e HUD independentes, compartilhando o mesmo World3D e simulação.

## 4. Loop de jogo
Menu → modo → seleção de personagem/prancha → pista → carregamento → contagem regressiva → descida → chegada → teleférico → nova volta → resultados → recompensas. Corrida padrão: 5 descidas. Cada descida termina em área de embarque; teleférico retorna ao topo. A última descida termina na linha final sem retorno. Embarque é parte estratégica da corrida, mas não pode bloquear permanentemente um jogador: fila FIFO, capacidade 1 por cabine, cabine a cada 1,2 s, viagem visual de 3 s, invulnerabilidade durante transporte. A fila preserva ordem; jogadores não podem atacar na área protegida. Permitir pular animação somente em treino solo.

## 5. Controle e física
Teclado: A/D ou setas para direção, W para tuck (posição aerodinâmica), S para frear, Espaço para carregar/soltar salto, Q/E para rotação aérea, Shift para grab, F para usar item ofensivo, R para defensivo, Esc para pausa. Gamepad: analógico esquerdo, gatilhos para tuck/freio, A salto, X grab, LB/RB rotação, Y/B itens. Remapeamento, deadzone 0,15 e vibração opcional. Multiplayer local: dispositivos separados, seleção de dispositivo antes da partida.

Modelo arcade: coordenadas em metros, velocidade máxima inicial 24 m/s, tuck 29 m/s, boost até 35 m/s. Projetar gravidade no plano tangente do terreno; aplicar arrasto, resistência lateral e força de carving. Direção depende da velocidade e aderência; não girar instantaneamente. Freio reduz velocidade e aumenta controle. Raycasts ou shape casts detectam superfície; usar normal suavizada para orientar prancha. Colisão contínua em alta velocidade, cápsula do piloto e limites laterais. Evitar tunneling, vibração e atravessamento de rampas. Salto carregado 0–0,65 s, impulso vertical 4–8 m/s. Coyote time 100 ms e buffer 120 ms. Aterrissagem avalia ângulo, velocidade angular e inclinação; erro moderado reduz velocidade, erro severo causa queda de 0,8–1,4 s. Reset em último checkpoint seguro após 2 s fora da pista; penalidade 2 s. Todos os valores configuráveis.

## 6. Manobras e economia
Manobras: ollie, grab, 180, 360, 540, 720, frontflip, backflip, rail grind, combo grab+spin. Pontos base 50/100/100/200/350/500/300/300/150; multiplicador de combo até 3x. Validar somente após pouso. Repetição reduz pontuação em 30% até alternar manobra. A cada 100 pontos válidos, ganhar 5 moedas (máximo 30 por salto). Moedas de pista em linhas de 3–8 unidades, valor 5 cada; saldo máximo de corrida 200. Estações de itens cobram 20 moedas; falha por saldo insuficiente deve ser sinalizada sem interromper corrida. Moedas de corrida são separadas dos créditos de carreira. Dois slots independentes: ofensivo e utilitário. Sem monetização real.

## 7. Itens
| Item | Efeito | Contrajogo |
|---|---|---|
| Bola de neve | projétil frontal, desacelera por 1 s | desvio/escudo |
| Mina de gelo | armadilha traseira, derrapagem 1,2 s | salto |
| Rajada | impulso por 2 s | curvas exigem controle |
| Escudo aurora | bloqueia um ataque, expira em 6 s | esperar expirar |
| Pinguim de vento | perseguidor de curto alcance | obstáculo/escudo |
| Névoa | reduz visibilidade local por 2 s | sair da área |
| Mola | salto extra em solo | risco de pouso |
| Ímã | coleta moedas próximas por 5 s | alcance limitado |
| Onda de neve | empurra rivais próximos | distância |
| Reparador | recupera rapidamente de queda | uso único |

Distribuição ponderada por posição: líder recebe mais defesa, últimos mais recuperação; sem ataques inevitáveis. Cooldown global de dano 2 s; projéteis expiram após 4 s; telegraph visual e sonoro; sem stun-lock. Item não deve atravessar parede. Estações sinalizadas por cor e ícone, com respawn de 2 s.

## 8. Elenco e pranchas
Atributos de 1–5: velocidade, controle, salto, aceleração, resistência. Todos os pilotos competitivos; sem personagem estritamente superior.
| Piloto original | V/C/S/A/R | Visual |
|---|---|---|
| Niko | 3/4/3/4/3 | jaqueta turquesa, óculos grandes |
| Mika | 3/5/4/2/3 | gorro coral, tranças |
| Taro | 5/2/3/3/4 | casaco laranja, capacete |
| Luna | 3/3/5/4/2 | roupa violeta, estrelas |
| Boro | 4/2/2/4/5 | traje verde, mochila |
| Yuki | 2/5/4/4/2 | roupa branca e azul |
| Zed | 5/3/2/4/2 | visual futurista amarelo |
| Pippa | 2/4/5/3/3 | traje rosa, luvas grandes |

12 pranchas: Starter, Carver, Rocket, Float, Grip, Twin, Powder, Rail, Alpine, Aurora, Comet, Legend. Cada uma com mesh e textura próprias, atributos e trade-offs. Categorias equilibrada, velocidade, freestyle, carving; modificadores máximos ±12% em relação à base. Desbloqueios por medalhas e créditos, nunca por vantagem absoluta.

## 9. Pistas e construção de terreno
Cada pista deve ter identidade geométrica própria, linha ideal, rotas alternativas, mapa, pontos de recuperação, estações de itens e teleférico funcional. Comprimento alvo por descida 800–1500 m; largura 8–20 m. Modelar terreno manualmente em Blender, com curvas inclinadas e perfil transversal autoral; validar continuidade, declive e colisões. Usar terreno visual separado de collider simplificado. Checkpoints sequenciais a cada 40–80 m; atalhos precisam de gates equivalentes para evitar exploits.

| Pista | Extensão | Setores e desafio | Atalho |
|---|---:|---|---|
| Vale dos Pinheiros | 850 m | reta inicial, curvas suaves, bosque, vila | rampa sobre riacho |
| Lago Cristal | 1000 m | gelo de baixa aderência, cavernas, ponte | túnel estreito |
| Pico Vulcânico | 1150 m | rocha escura, vapor, curvas inclinadas | salto sobre fenda sinalizada |
| Festival Boreal | 950 m | noite, lanternas, rails, praça | telhados acessíveis |
| Floresta Gigante | 1200 m | árvores enormes, raízes, bifurcações | trilha elevada |
| Estação Abandonada | 1100 m | vagões estáticos, túnel, rampas metálicas | plataforma lateral |
| Tempestade Polar | 1300 m | vento lateral previsível, gelo, visibilidade variável | corredor protegido |
| Cume Celestial | 1500 m | combinação de curvas técnicas, saltos e rotas | sequência de dois saltos |

Para cada pista entregar arquivo de dados com spline, largura, materiais, declive, checkpoints, pickups, hazards, câmeras e lift. Construir primeiro Vale dos Pinheiros: spawn largo, 150 m de tutorial natural, curva S, rampa, bosque com duas rotas, curva inclinada, estação de itens, reta final e embarque. Testar com todos os pilotos. Obstáculos nunca devem cobrir toda a largura sem rota segura.

## 10. IA adversária
IA usa a mesma física e regras de itens. Spline com corredores laterais e lookahead 10–35 m; velocidade alvo por curvatura, superfície e risco. FSM: Race, Overtake, Avoid, Jump, Trick, Recover, LiftQueue, Finish. Avaliar ocupação de corredores e tempo de colisão; evitar oscilações com histerese. Escolher atalhos conforme habilidade, executar manobras quando pouso previsível e comprar itens se houver moedas. Dificuldades: iniciante (reação 450 ms), normal (250 ms), expert (120 ms), com variação de precisão e decisões. Sem teleporte, sem moedas gratuitas e sem velocidade impossível. Se houver assistência de aproximação, limitar a 5%, respeitando teto físico, e permitir desligar. Ranking por volta, checkpoint e distância projetada no trecho válido; congelar ordem na chegada final.

## 11. Modos e progressão
Grand Prix: 4 copas de 2 pistas, pontos 10/7/4/2. Corrida rápida: pista, voltas 1–5, dificuldade e itens configuráveis. Time Trial: fantasma local, sem itens, recordes por pista e prancha. Trick Attack: 2 minutos, circuito de rampas e pontuação. Multiplayer local disponível em corrida rápida e Grand Prix; tela dividida horizontal para 2 e grade para 3–4. Campanha inicia com 2 pistas, 4 pilotos e 3 pranchas; bronze desbloqueia próxima copa, prata/ouro liberam pilotos e pranchas. Créditos 100/70/40/25 por colocação mais bônus de manobras limitado a 50. Salvar localmente com versão de schema, migração e recuperação de JSON inválido. Exportar/importar save validado. Sem ranking online prometido.

## 12. Câmera, interface e feedback
Câmera chase atrás e acima, distância 5–8 m, FOV 65–85 conforme velocidade, suavização exponencial, lookahead, raycast contra cenário. Não herdar toda rotação da prancha. Reduzir shake e motion effects por configuração. HUD: posição, volta, velocidade, moedas, dois slots, minimapa, combo e avisos. Menus: título, perfil, modos, seleção de participantes em quatro espaços, piloto/prancha, mapa de pista, opções, pausa, resultados e garagem. Navegação completa por teclado/gamepad, foco visível, textos PT-BR e EN, contraste e ícones além de cor. Contagem 3–2–1–VAI; feedback de ultrapassagem, pouso perfeito, item, moedas e chegada. Tela de resultados mostra tempos, pontos, créditos e desbloqueios.

## 13. Pipeline de assets reais
Exigir produção autoral em Blender ou integração de modelos 3D licenciados e editados. Geração procedural de malhas não pode substituir personagens, pranchas, arquitetura ou pistas finais. Assets externos somente com licença compatível verificada (ex.: CC0), mantendo autor, URL, licença e alterações em `ASSET_LICENSES.md`. Não inventar URLs ou alegar que um arquivo existe. Não depender de geração de imagem como substituto de mesh rigado. Entregar GLB/glTF com materiais PBR, UVs, texturas e animações; compressão de texturas VRAM nativa quando compatível. Eixo Y para cima no runtime, unidade metro, pivôs consistentes. Validar escala, normais, bounding boxes, animações e carregamento.

| Grupo | Inventário mínimo | Orçamento indicativo |
|---|---|---|
| Pilotos | 8 meshes, rigs, roupas, rostos, acessórios | 8–18k tri por piloto LOD0 |
| Pranchas | 12 modelos, decks, bindings e decals | 500–1500 tri |
| Pistas | 8 terrenos, 8 teleféricos temáticos, 8 skyboxes | chunks e LOD |
| Vegetação | 6 árvores, 4 arbustos, 3 rochas, 4 bancos de neve | instancing |
| Props | 4 cabines, 5 cercas, 6 placas, 4 rampas, 3 rails, 6 edifícios, 4 lanternas, 3 pontes, 4 túneis | 100–3000 tri cada |
| Itens | 10 modelos, 10 ícones, moedas, 2 tipos de estação | 128–512 px ícones |
| VFX | spray de neve, trilha, boost, impacto, escudo, névoa, coleta, confete | pools reutilizáveis |
| UI | logo original, 8 retratos, 8 mapas, 12 thumbnails, ícones de controles | SVG/WebP |

Texturas: atlas de props 1024–2048, personagens 1024, pranchas 512–1024, materiais de neve/gelo/rocha/madeira/metal com albedo, normal e roughness. Neve com variação de cor, brilho moderado e trilhas visuais. Luz direcional + ambiente, sombras limitadas, fog atmosférico, AO baked quando possível. Não usar bloom excessivo. LOD0/1/2 e instancing para vegetação. Manifesto `assets.manifest.json` com id, caminho, tipo, licença, tamanho, dependências e fallback apenas de desenvolvimento. Build final falha se asset obrigatório faltar.

### Animações
Rig humanoide compartilhado quando compatível; clips idle, push, glide, tuck, carveLeft/Right, brake, jumpCharge, takeoff, airIdle, grab, spin, flip, grind, landSoft/Hard, hit, fall, recover, liftEnter/Idle/Exit, victory, defeat. Blend por velocidade, inclinação e estado. Pés presos à prancha via IK ou sockets; root motion desativado durante simulação. Eventos de pouso e impacto sincronizam áudio e partículas. Personagens têm poses de vitória distintas.

### Áudio
8 faixas originais ou licenciadas para pistas, 1 menu, 1 resultados, 1 vitória; loops sem corte audível. SFX: neve por superfície, carving, vento por velocidade, salto, pouso, queda, moedas, compra, 10 itens, teleférico, contagem, UI e chegada. Vozes curtas originais opcionais. Mix buses master/music/sfx/voice; limiter, volumes persistentes, espacialização de rivais, limite de vozes simultâneas. Não copiar trilha do N64.

## 14. Performance e estabilidade
Meta de 60 FPS em desktop de referência a definir e medir, 30 FPS em modo baixo; não alegar desempenho sem benchmark. Qualidade baixa/média/alta: escala de renderização 0,75–1,0, sombras, partículas, distância de visão e pós-processamento. Multiplayer divide orçamento de renderização por viewport. Pool de projéteis e partículas; frustum culling, chunk streaming, instancing e descarte de GPU resources. Carregar pista antes da contagem, mostrar progresso real. Meta inicial de distribuição até 2 GB, com carregamento por pista; revisar com medições. Pausar simulação ao perder foco em solo. Evitar listeners duplicados, vazamentos e timers órfãos.

## 15. Testes e aceite
- Unitários: integração física, velocidade limite, salto, combos, saldo, cooldown, ranking, checkpoints, fila do lift, save/migração, RNG.
- Integração: corrida completa de 5 voltas com 4 participantes, compra/uso de cada item, queda e recuperação, atalhos, finalização, desbloqueio e recarga do save.
- IA: 100 corridas simuladas por pista com seeds fixas; nenhuma IA permanentemente presa, sem checkpoints pulados, sem NaN. Registrar taxa de conclusão e tempos.
- E2E: abrir menu, selecionar piloto, iniciar, controlar, pausar, reiniciar, finalizar, voltar ao menu; repetir com gamepad e multiplayer local quando ambiente permitir.
- Visual: capturas de cada pista, HUD e menus; conferir clipping, legibilidade, animações e sombras. Teste manual de sensação de carving e câmera.
- Performance: medir frame time, memória e carregamento em hardware identificado; registrar resultados reais, não inventados.
- CI: importação headless, validação de scripts, testes, exportação nativa, validação de manifesto/licenças. Entregar README com instruções, controles, limitações e relatório de testes.

## 16. Roadmap de implementação
1. Bootstrap: projeto, CI, schemas, input, loop fixo, pipeline de assets e documentação de decisões.
2. Vertical slice: piloto original rigado, prancha, Vale dos Pinheiros, física, câmera, HUD, checkpoints e corrida completa com lift. Aceite: partida jogável do início ao fim.
3. Competição: três IAs, itens, moedas, manobras, ranking e recuperação. Aceite: 20 corridas automatizadas sem travamento.
4. Conteúdo: demais 7 pistas, 7 pilotos, 11 pranchas, todos os itens, assets finais e áudio. Aceite: manifesto completo e corridas em todas as pistas.
5. Produto: copas, save, desbloqueios, time trial, trick attack, multiplayer local, acessibilidade e opções.
6. Polimento: balanceamento, LOD, VFX, áudio, testes e build de distribuição. Corrigir regressões antes de avançar. Manter `IMPLEMENTATION_STATUS.md` com tarefas, evidências e pendências.

## 17. Prompt START para agente de desenvolvimento
Leia este documento integralmente e inspecione o repositório antes de editar. Você é responsável por implementar Snowboard Legends 3D como jogo executável, original e completo. Preserve código existente que funcione. Crie um plano rastreável por fases e comece imediatamente pela vertical slice jogável; não pare na geração do plano. Implemente física arcade de snowboard, câmera, pista real, personagem rigado, HUD, checkpoints, adversários e teleférico. Execute os comandos de teste e build após cada marco, corrija erros e avance para as demais pistas, modos e assets. Produza ou integre assets com licenças verificáveis e registre sua procedência. Não use placeholders na entrega final, não simule funcionalidades, não invente resultados de testes e não declare conclusão se houver pendências. Se ferramentas de modelagem ou áudio não estiverem disponíveis, documente a limitação e use assets licenciados acessíveis e registre os requisitos ainda bloqueados; não finja ter produzido arquivos. Priorize jogabilidade e estabilidade antes de efeitos cosméticos. Ao concluir, forneça instruções de execução, inventário de assets, resultados reais dos testes, limitações e lista de requisitos atendidos. O documento é a especificação de desenvolvimento, não evidência de que o jogo já foi implementado.


## 18. Contrato obrigatório de qualidade visual e autoria (prevalece sobre permissões anteriores)
- Renderização exclusivamente Godot 3D nativo em perspectiva 3D, com profundidade, malhas, materiais, iluminação e câmera reais. Proibido Canvas 2D, pseudo-3D, raycasting 2D, sprites como substitutos de pilotos e cenários planos. Nenhum elemento HTML canvas ou WebView no jogo.
- Cada pista deve ter terreno e composição autorais, editáveis em Blender, exportados como GLB. Splines servem para checkpoints, IA e colisão, não para gerar automaticamente a arte final. Modelar curvas inclinadas, rampas, margens e áreas de embarque. Cada pista terá três marcos visuais exclusivos, duas rotas alternativas testadas e uma sequência de saltos própria.
- Procedural permitido somente para distribuição determinística de vegetação já modelada, partículas, marcas de prancha, variações de neve e ferramentas auxiliares. Nenhum personagem, pista, edifício principal ou prancha final pode ser substituído por primitivas geradas em runtime. Não usar geração infinita de mapas. Registrar método de produção por asset no manifesto.
- Direção artística: cartoon 3D premium, silhuetas expressivas, roupas de inverno com costuras, óculos, luvas, botas e acessórios exclusivos. Cada piloto tem paleta, proporções, rosto e pose próprios. Proibir simples recoloração de um único modelo como personagem novo.
- Entregar sprites e atlas reais em PNG/WebP com transparência: moedas, dez poderes, avisos de impacto, flocos, brilhos, retratos, indicadores de direção, medalhas, ícones de controles e emotes. Sprites são complementos de HUD/VFX, não substitutos de geometria 3D. Atlas com metadados JSON, pivôs, padding e frames de animação.
- Efeitos: trilha dupla de carving alinhada ao terreno, neve pulverizada dependente da velocidade, neve compactada no pouso, rastro de turbo, impacto com estrelas estilizadas, escudo translúcido, explosão de gelo, partículas de coleta, confete de chegada. Cada efeito tem duração, curva de opacidade, limite de partículas e evento de disparo. Usar billboards e malhas 3D conforme necessário.
- Menus com identidade própria: logo final, cenário 3D animado ao fundo, seleção de piloto com modelo giratório e animação de confirmação, garagem com inspeção de prancha, mapa ilustrado de cada pista e prévia 3D, transições suaves e resultados com pódio animado. Não copiar interface do N64.

## 19. Portões de produção de conteúdo
1. Criar guia de arte com paletas, proporções, escala, materiais, referências licenciadas e identidade de cada pista. Criar arquivos-fonte editáveis quando produzidos no projeto.
2. Para cada asset: modelar/adquirir, verificar licença, ajustar UV e materiais, rigar quando necessário, exportar, validar no motor, capturar prévia e registrar manifesto. Não marcar como pronto antes da inspeção no jogo.
3. Para cada pista: blockout temporário, teste de percurso, modelagem final, colisão simplificada, iluminação, props exclusivos, áudio ambiente, IA, checkpoints, minimapa, teste de atalhos e corrida completa. Remover blockout da distribuição.
4. Criar `ASSET_STATUS.md` com estados missing, in_progress, integrated, verified. O build de release deve rejeitar missing/in_progress e arquivos vazios ou caminhos inexistentes. Verificar também clips obrigatórios, dimensões de texturas e referências de materiais. Uma licença desconhecida bloqueia distribuição.
5. Entregar capturas reais de gameplay em cada pista e de cada personagem, não imagens conceituais apresentadas como screenshots. Comparar cenas em movimento para identificar clipping, repetição visual, falta de feedback e problemas de câmera.
6. Se o agente não tiver ferramentas de modelagem, acesso a assets ou capacidade de testar GPU, declarar explicitamente a pendência; não mascarar com geometria genérica nem afirmar conclusão. Continuar os requisitos independentes.

## 20. Prompt único definitivo (copiar e executar com este arquivo)
Leia integralmente este arquivo MDS, incluindo os contratos das seções 18–20, que prevalecem sobre permissões anteriores. Atue como equipe de desenvolvimento de jogos 3D, responsável por engenharia, arte, level design, áudio, QA e entrega. Inspecione o ambiente e implemente Snowboard Legends 3D no repositório, sem parar após planejamento ou protótipo. Use Godot 4 e GDScript tipado com renderização 3D nativa; jamais Canvas 2D ou pseudo-3D. Construa pistas autorais e integre modelos GLB finais, rigs, animações, texturas, sprites, efeitos e áudio conforme inventário. Minimize procedural conforme seção 18. Implemente todos os modos, personagens, pistas, itens, progressão e multiplayer previstos. Execute os marcos em ordem, valide cada um com testes e build, corrija falhas e continue. Não solicite confirmações para decisões reversíveis de implementação; documente-as. Não invente assets, licenças, resultados ou funcionalidades. Não considere o projeto finalizado enquanto requisitos obrigatórios estiverem pendentes. Entregue código, assets locais, manifesto, licenças, README, controles, build executável, relatório de testes e lista explícita de limitações. Comece agora.


## 21. Fidelidade funcional ao vídeo e direção de corrida
- Rookie Mt. inspira Vale dos Pinheiros: descida aberta, montanhas ao fundo, neve com sulcos, bandeiras de direção, estruturas de estação e chegada bem legível. Não copiar geometria ou sinalização protegida.
- HUD vertical de progresso com quatro retratos ordenados por progresso normalizado; mostrar volta 1/5 até 5/5, posição grande, saldo e dois slots com sprites. Atualizar a 10 Hz, sem oscilar em empates.
- Estação de retorno: entrada estreita sinalizada, aproximação controlada, fila, embarque, deslocamento visível, saída segura. A volta só incrementa após saída válida; na última descida a chegada encerra a prova. Testar quatro pilotos chegando juntos e jogador atingido antes da entrada.
- Loja: preview 3D rotativo, comparação de atributos, confirmação de compra, saldo persistente e equipar; categorias freestyle, equilibrada, carving e velocidade. Não cobrar duas vezes ao confirmar.
- Skill Game: implementar desafios de slalom, salto com pouso e coleta de moedas, além de Trick Attack; medalhas com limiares configuráveis e feedback de falha. Time Attack registra fantasma por amostras de transformação, sem colisão.

## 22. Comandos e critérios de entrega nativa
Usar o binário Godot instalado (nome e caminho variam). Exemplos: `godot --headless --path . --editor --import`, `godot --headless --path . --script res://tests/run_all.gd`, `godot --headless --path . --export-release "Windows Desktop" builds/SnowboardLegends.exe`. Criar preset real e instalar templates compatíveis; não alegar exportação se indisponíveis. Test runner deve retornar código não zero em falha. Testes headless não substituem inspeção gráfica. Entregar ZIP da build com dependências, executável, licença e instruções; manter projeto-fonte separado. Testar execução em pasta limpa, sem editor ou internet. Registrar versão, hardware, FPS, frame time p95 e memória. Critério final: todos os assets obrigatórios presentes, todas as pistas concluíveis, nenhuma referência quebrada, nenhum erro de script, nenhum botão inerte, save persistente e relatório de limitações.

## 23. Checklist de autonomia do agente
Antes de iniciar, verificar editor, Blender, ferramentas de áudio e capacidade de exportar. Se ausentes, tentar instalação somente quando autorizada pelo ambiente; registrar bloqueio. Manter checklist por requisito com evidência (arquivo, teste ou captura). Não pedir confirmação para decisões reversíveis. Não substituir autoria por geometria procedural: permitido apenas distribuição de props autorais, partículas, trilhas de neve e ferramentas auxiliares. Entregar sprites PNG reais com alpha, atlas e metadados; não usar emoji como ícone final. Produzir arquivos .blend para conteúdo autoral e preservar fontes de áudio quando disponíveis. A especificação não contém os assets prontos: sua criação e integração são parte obrigatória do trabalho do agente.

## 24. START — comando único
Leia integralmente este arquivo como contrato de implementação. Desenvolva Snowboard Legends 3D em Godot 4 nativo, com GDScript tipado, Blender e assets locais finais. Execute todas as fases e testes, não pare no planejamento nem na vertical slice. Priorize a corrida de cinco descidas com retorno por teleférico, depois complete elenco, pistas, pranchas, itens, loja, modos, multiplayer e progressão. Respeite as restrições de autoria, licenças, ausência de Canvas no gameplay e procedural mínimo. Entregue projeto-fonte, assets, build executável e evidências reais. Registre qualquer bloqueio sem simular conclusão. START PROJECT NOW.
