# IMPLEMENTATION_STATUS — Snowboard Legends 3D

Legenda: ✅ feito e verificado · 🟡 implementado, não verificado/incompleto · ❌ não feito

## Ambiente
- ✅ Godot 4.4.1 + templates Win/Linux; Blender 5.0.1 (bpy); Xvfb+Mesa disponíveis (sem GPU real).

## Assets (scripted modelling em Blender — método declarado, não escultura manual)
- ✅ 9 pilotos rigados (8 da spec + Kaito, secreto/extra), 5,7–7,4k tri, rig compartilhado com IK nos pés, 24 clips + vitória própria. Renders Cycles conferidos. ⚠ abaixo do orçamento 8–18k tri.
- ✅ 12 pranchas únicas (contorno, kick, sidecut, bindings, arte).
- ✅ Props: 6 árvores, 4 arbustos, 3 rochas, 4 bancos de neve, 5 cercas, 6 placas, 3 bandeiras, 4 lanternas, 3 rails, 4 rampas, 3 pontes, 4 túneis, 6 edifícios, torre/estação/4 cabines de teleférico, arco de largada, tronco, vagão.
- ✅ 10 modelos de itens + moeda + 2 estações.
- ✅ 9 pistas GLB + JSON (8 campanha com comprimentos exatos da spec + Parque de Manobras), 3 marcos exclusivos cada, rotas divididas, zonas (gelo, lama, vapor, fenda, vento, abrigo, turbo), plataformas, rails, túneis.
- ✅ 14 texturas PBR; sprites FX, medalhas, avisos, 9 mapas ilustrados, logo, ícone, atlas+JSON.
- ✅ 37 SFX + 12 músicas originais sintetizadas (loops). ⚠ qualidade de síntese, não produção de estúdio.
- ❌ Ícones de itens (render do items.blend), retratos dos pilotos (render_rider portrait) — scripts prontos, renders não gerados.
- ❌ `assets.manifest.json`, `ASSET_STATUS.md`, `ASSET_LICENSES.md`.

## Gameplay
- ✅ Física arcade (tangente, arrasto, carving, tuck, freio/curva fechada, salto carregado, coyote/buffer, pouso avaliado, queda).
- ✅ Corrida 5 descidas + teleférico FIFO em Vale dos Pinheiros: concluída headless, 4 IAs, 0 resets (seeds 1234 e 99: 3:06–3:40).
- 🟡 Manobras/pontuação/moedas (funcionam na simulação; sem teste unitário).
- 🟡 10 itens (IA compra e usa; nem todos exercitados em teste).
- 🟡 Rails/grind, plataformas, fendas, vento, gelo — implementados, não testados individualmente.
- ❌ Corridas nas outras 7 pistas + parque (nunca executadas).
- 🟡 HUD (código pronto; nunca visto renderizado). 🟡 Câmera chase. 🟡 Pausa.
- 🟡 Time Trial com fantasma, Trick Attack, Slalom (lógica no RaceManager, não testados). ❌ Desafio de pousos/coleta completos.
- ❌ Menus: título, perfil, modos, participantes (4 vagas), piloto/prancha com modelo giratório, mapa de pista, opções/remapeamento, garagem/loja, resultados com pódio. (`main_menu.tscn` e `results.tscn` NÃO existem — `Game.goto_menu/goto_results` quebram.)
- ❌ Grand Prix completo (pontos 10/7/4/2, créditos, medalhas, desbloqueios na UI). Save/migração escritos, não testados.
- 🟡 Multiplayer local em tela dividida (código de layout pronto, não testado).

## Testes / entrega
- ❌ Suíte `tests/run_all` (unitários, integração, 100 corridas IA/pista), relatório.
- ❌ Capturas reais de gameplay/menus.
- ❌ `export_presets.cfg`, build Windows, README, benchmark.
