# IMPLEMENTATION_STATUS — Snowboard Legends 3D

Legenda: ✅ feito e verificado (evidência citada) · 🟡 implementado, verificação parcial · ❌ não feito / bloqueado

Relatórios: `docs/test_reports/suite_unit_integration_e2e.json` (367 verificações, 0 falhas),
`docs/test_reports/ai_<pista>.json` (100 corridas × 9 pistas), `docs/test_reports/benchmark_*.json`.
Capturas reais: `docs/screenshots/`.

## Ambiente
- ✅ Godot 4.4.1-stable + templates (Windows/Linux x64); Blender 5.0.1 (`bpy`, Python 3.11 em `tools/blenv`); Pillow, NumPy, FFmpeg.
- ✅ Captura sem GPU: Forward+ via Mesa lavapipe + Xvfb (`CLAUDE.md`). Compatibility no llvmpipe estoura a neve — não usado como evidência.
- ✅ Bloqueio encontrado na verificação inicial e corrigido: `boot.gd` tinha `_capture` duplicado (erro de parse; o jogo não iniciava).

## Assets (`ASSET_STATUS.md`, `assets.manifest.json` — 221 entradas, 0 missing/in_progress; `--check` bloqueia release)
- ✅ 9 pilotos rigados (8 + Kaito, original e secreto), 24 clips cada (validados no GLB pelo manifesto). ⚠ 5,7–7,4k tri, abaixo do orçamento indicativo 8–18k.
- ✅ Clip `push` (remada com o pé de trás) por transferência de movimento de captura Mixamo ("Skateboarding"), espelhado para base goofy, aplicado aos 9 pilotos — `tools/blender/mixamo_retarget.py`; FBX original não versionado (termos da Adobe), fallback para o clip autoral sem ele. O clip "andando parado" foi testado para `glide` e descartado (< 3° de movimento).
- ✅ 12 pranchas, props/vegetação/teleférico, 12 itens (10 + cometa caçador + redemoinho), moeda, 2 estações, alvo de desafio.
- ✅ 9 pistas GLB + dados; checkpoints a cada 60 m (teste de conteúdo); descidas por pista (3–9).
- ✅ Retratos (9) e ícones de itens (12 + moeda + alvo) renderizados em Cycles (`tools/blender/render_rider.py`, `render_objects.py`).
- ✅ Mapas ilustrados a partir do render ortográfico real de cada pista + sobreposição de rota (`tools/blender/render_maps.py`, `tools/gen_maps.py`).
- ✅ Texturas PBR, sprites FX/UI, atlas+JSON, cadeados (`tools/gen_ui_icons.py`), fonte Inter (OFL-1.1).
- ✅ 37 SFX em camadas + 12 músicas arranjadas (intro/refrão/pausa; bateria, baixo, acordes, melodia; OGG estéreo, 42–90 s) — `tools/gen_audio.py --verify` (sem clipping, volume uniforme). Loops de vento/atrito importados sem compressão (antes repetiam só 0,4 s). ⚠ síntese procedural, sem vozes.
- ✅ Texturas fotográficas e céus HDRI CC0 (Poly Haven, ambientCG) — `tools/fetch_cc0.py`, origem e MD5 em `source_art/cc0/sources.json`, linhas em `ASSET_LICENSES.md`.
- ✅ `ASSET_LICENSES.md` (conteúdo original: licença pública ainda não escolhida pelo titular; terceiros: Inter OFL-1.1, Godot MIT).

## Gameplay (testes em `tests/run_all.gd`)
- ✅ Física arcade (24/29/35 m/s, salto carregado 4–8 m/s, coyote 100 ms, buffer 120 ms, pouso avaliado, queda 0,8–1,4 s) — unit: physics/speed/jump/tricks.
- ✅ Corrida com teleférico FIFO (1 cabine/1,2 s, viagem 3 s, invulnerável) — unit: lift FIFO; integração: corrida completa 5 descidas/4 pilotos.
  O cabo passa pelas torres com 9 m de folga sobre a pista (antes cortava a pista em Lago Cristal).
- ✅ Descidas por pista (Vale 5, Lago 4, Pico 4, Festival 5, Floresta 4, Estação 4, Tempestade 4, Cume 3, Parque 9): corridas de 3:04–3:54 com o vencedor de IA.
- ✅ Manobras, combos (teto 3×), repetição −30 %, moedas por manobra (5/100 pts, máx. 30), saldo máx. 200, estação 20 — unit: tricks/coins.
- ✅ Manobra-assinatura por piloto (Q, E, Shift no ar) — unit: sequência, queda se pousar antes, pontuação; a IA usa em saltos longos.
- ✅ 12 itens com efeitos, cooldown de dano 2 s, projéteis expiram em 4 s, telegraph — integração: cada item; unit: cooldown/escudo.
- ✅ Sorteio ponderado por posição e seed — unit: RNG.
- ✅ Reset fora da pista (2 s + penalidade) — integração; recuo para checkpoint com embalo antes de fendas (corrigido após falha em 41/100 corridas no Pico).
- ✅ Rotas alternativas: as duas rotas de cada bifurcação das 8 pistas são percorríveis e contam checkpoints — integração (32 verificações).
- ✅ IA: 100 corridas × 9 pistas (2 descidas, teleférico), **900/900 concluídas, 3600/3600 pilotos**, 0 checkpoints pulados, 0 NaN, sem piloto preso — `docs/test_reports/ai_*.json`.
  Correções feitas a partir da bateria: oscilação da direção (atraso de reação) e loop de reset na fenda.
- ✅ Assistência de IA ≤5 %, sob o teto físico, desligável — unit (antes era uma opção sem efeito).
- ✅ HUD (posição, descida x/N, tempo, velocidade, moedas, 2 slots, barra vertical de retratos a 10 Hz, minimapa, avisos) — capturas `docs/screenshots/tracks/`.
- ✅ Pausa (Esc/Start), retomar, reiniciar — e2e.
- ✅ Queda em buraco: reaparece 8 m após a fenda já rolando (≥10 m/s, 0,8 s), com flash e dica — integração `_i_pit_respawn`; IA 6×2 descidas nas 7 pistas com fenda: 168/168 concluíram, 0 checkpoints pulados.
- ✅ Poderes legíveis: projéteis maiores com halo aditivo (`scripts/fx/glow_halo.gd`), auras no piloto (ímã/turbo/acerto), faixas "Novo poder", "Atingido por X", "O escudo bloqueou" (`race_hud.gd`).

## Modos e progressão
- ✅ Grand Prix: 4 copas × 2 pistas, pontos 10/7/4/2, créditos 100/70/40/25 + bônus ≤50, medalhas, desbloqueios — unit + integração + e2e (corrida 1 → próxima → final da copa → ouro → desbloqueios → menu).
- ✅ Corrida rápida (pista, descidas padrão ou 1–9, dificuldade, itens).
- ✅ Contra o relógio com fantasma (amostras de transformação) e recordes por pista/prancha — integração.
- ✅ Trick Attack 2 min no Parque — integração. ✅ Desafios: slalom, pousos limpos, corrida das moedas, tiro ao alvo — integração.
- ✅ Garagem/loja: prévia 3D, comparação de atributos, confirmação, cobrança única, equipar, upgrades de prancha (3 níveis, teto ±12 %) — unit + e2e.
- ✅ Save com schema, migração, backup, exportar/importar validado — unit.
- ✅ Multiplayer local 2–4 em tela dividida (horizontal / grade), dispositivo por vaga, entrada com START, tags J1–J4 — integração + e2e + capturas `docs/screenshots/multiplayer/`.

## Front-end
- ✅ `main_menu.tscn`: título com pista 3D animada, modos, participantes (4 vagas), piloto com modelo giratório e animação de confirmação, prancha, pista com mapa, copa, desafios, garagem, perfil, opções (volumes, qualidade, idioma PT/EN, acessibilidade), remapeamento — capturas `docs/screenshots/menus/`.
- ✅ `results.tscn`: pódio 3D animado, tempos, pontos, créditos, medalhas, desbloqueios — captura `docs/screenshots/results.png`; e2e.
- ✅ Navegação completa por teclado e gamepad com foco visível — e2e. (Corrigido: o InputMap padrão não ligava D-pad/A/B aos `ui_*`.)

## Visual
- ✅ MSAA 4x + FXAA, filtro anisotrópico, SSAO (média+), SSIL (alta), sombras suaves 4096, neblina de vale, precipitação por clima, animação polida (crossfades, inclinação, squash no pouso), noite mais legível — capturas.

## Web / celular
- ✅ Export Web (GitHub Pages, branch `gh-pages`, PWA), texturas ETC2, PCK ~67 MB; modo `perf_low` (escala de viewport, vegetação reduzida).
- ✅ Controles de toque em PT-BR com legendas, fundo escuro, anel dourado + nome do poder pronto, dicas nas 3 primeiras corridas — verificado em emulação iPhone 13 paisagem (Playwright). 🟡 Sem teste em aparelho físico.

## Entrega
- ✅ `tests/run_all.tscn` (unit/integration/e2e/ai), sai com código 1 em falha.
- ✅ `export_presets.cfg`; builds Windows x64 e Linux x64 em `builds/` + ZIPs com licenças e instruções (não versionados: o `.exe` tem 137 MB).
- 🟡 ZIP Linux testado em pasta limpa (corrida completa OK). ZIP Windows: PCK validado com o motor 4.4.1; **o `.exe` não foi executado** (sem Windows; Wine aborta neste container).
- 🟡 Benchmark real registrado (README), mas **só em render por software** (sem GPU): 1,1–5,3 FPS. FPS em hardware com GPU não medido.
- ✅ README com controles, testes, benchmark, build e limitações.

## Pendências explícitas
1. Medir FPS/frame time em PC com GPU (meta 60 FPS) e executar o `.exe` no Windows.
2. Balanceamento entre pilotos (velocidade alta vence mais nas corridas de IA).
3. Pilotos abaixo do orçamento indicativo de triângulos; áudio sem qualidade de estúdio.
4. Escolha da licença pública do conteúdo original (decisão do titular).
