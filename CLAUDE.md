# Snowboard Legends 3D — contexto para o Claude Code

Spec obrigatória: `docs/SPEC_MASTER_V3.md` (seções 18–24 prevalecem). Status real: `IMPLEMENTATION_STATUS.md`.

## Stack fixada
- Godot **4.4.1-stable** (Forward+; screenshots em ambiente sem GPU usam `--rendering-method gl_compatibility`), GDScript tipado.
- Templates de exportação 4.4.1 (Windows x64 e Linux x64).
- Blender **5.0.1** como módulo Python (`bpy` 5.0.1, exige Python 3.11): `uv venv -p 3.11 tools/blenv && uv pip install bpy==5.0.1 numpy`.
- Áudio/sprites/texturas: Python 3 + numpy + Pillow + ffmpeg (libvorbis).

## Pipeline de assets (tudo regenerável, determinístico)
```
python3 tools/gen_textures.py                     # texturas PBR (albedo+normal)
<blenv>/python tools/blender/build_props.py       # props.glb + items.glb
<blenv>/python tools/blender/build_riders.py      # 9 pilotos rigados + 24 clips cada
<blenv>/python tools/blender/build_boards.py      # 12 pranchas
<blenv>/python tools/blender/build_tracks.py      # 9 pistas (GLB + JSON de dados)
python3 tools/gen_resources.py                    # .tres tipados (riders/boards/tracks/items)
python3 tools/gen_sprites.py                      # FX, medalhas, mapas, logo, atlas+JSON
python3 tools/gen_audio.py                        # 37 SFX + 12 músicas (OGG em loop)
<blenv>/python tools/blender/render_rider.py <id> <out.png> <clip> <frame> portrait 256   # retratos
<blenv>/python tools/blender/render_objects.py <blend> <outdir> 256 board|item <names...>  # thumbnails/ícones
<blenv>/python tools/blender/render_maps.py /tmp/mapraw 960 <track ids...>   # render ortográfico das pistas
python3 tools/gen_maps.py /tmp/mapraw            # mapas ilustrados (rodar DEPOIS de gen_sprites.py, que tem mapas antigos)
python3 tools/gen_ui_icons.py                     # cadeados de UI
python3 tools/build_manifest.py [--check]         # assets.manifest.json + ASSET_STATUS.md; --check falha com missing/in_progress
```
`source_art/`, `tools/`, `docs/`, `builds/` têm `.gdignore` (o Godot não importa .blend).

## Comandos Godot
```
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 -- --race vale_pinheiros --laps 5 --autoplay --seed 99   # imprime RACE_RESULT {json}
godot --headless --path . --fixed-fps 60 res://tests/debug_slide.tscn
```
Testes devem rodar como **cena** (não `--script`), senão os autoloads (Registry, Save, Inputs, Audio, Game — nesta ordem) não carregam.
`--check-only --script` acusa falsos positivos "Identifier not found: Registry/Game/Audio".
```
godot --headless --path . --fixed-fps 60 res://tests/run_all.tscn -- [--suite unit,integration,e2e,ai] [--ai-races N] [--ai-laps L] [--tracks a,b] [--report path]
```
Sai com código 1 se algo falhar; usa `user://test_save.json` (nunca o save do jogador); intercepta trocas de cena via `Game.set_meta("test_hold")`.

Capturas reais (sem GPU): Forward+ via Mesa lavapipe (`apt install mesa-vulkan-drivers`), `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`
+ `xvfb-run`. O renderer Compatibility no llvmpipe estoura a neve (não usar para evidência).
```
xvfb-run -a -s "-screen 0 1280x720x24" godot --fixed-fps 60 --resolution 1280x720 --path . -- --race <id> --autoplay --screenshot out.png --shots "18,46" [--spectate] [--opponents a,b,c]
xvfb-run ... godot --path . -- --menu rider|garage|options|... --screenshot out.png --at 2
... -- --race <id> --laps 1 --autoplay --show-results --screenshot out.png --warp-results --at 3     # tela de resultados
... -- --race <id> --benchmark 30                                                                     # FPS / p95 / memória
```
`--warp` simula sem desenhar até o instante pedido (render por software é lento); a simulação é o loop normal.

## Arquitetura
- `scripts/race/track_runtime.gd`: carrega GLB+JSON da pista, materiais, ambiente, colisores de features, MultiMesh de vegetação, moedas, estações, teleférico; `project()` / `point_at()` sobre a spline.
- `scripts/rider/rider_controller.gd`: CharacterBody3D, física arcade; velocidade no solo integrada internamente (`_vf/_vl`) — **não** ler de volta `velocity` após `move_and_slide` (isso travava os pilotos a ~3,7 m/s). Qualquer alteração externa de velocidade deve usar `_scale_speed()` / `push()` / `_seed_speed()`.
- `scripts/ai/ai_driver.gd`: FSM, atraso de reação 450/250/120 ms, rotas, estações, manobras, itens.
- `scripts/race/race_manager.gd`: fases, checkpoints, ranking 10 Hz, `LiftSystem` (FIFO, 1,2 s, 3 s), chegada, ghost, slalom.
- Coordenadas: modelos Blender ficam de frente para +Z no Godot; `RiderVisual` gira 180°. Frente da corrida = -Z, `yaw` com forward = (-sin, 0, -cos).

- `scripts/ui/main_menu.gd` (todas as telas do front-end, `go()`/`back()`), `results_screen.gd` (pódio 3D, aplica `Game.process_results()` uma vez),
  `preview_stage.gd` (SubViewport com World3D próprio para modelo giratório), `menu_backdrop.gd` (pista real ao fundo do título).
- Regras de progressão puras em `game.gd` (`place_points`, `race_credits`, `skill_medal`, `standings`) — testadas em `tests/run_all.gd`.
- Navegação de UI por gamepad é registrada em `input_router.gd` (o InputMap padrão deste Godot não liga D-pad/A/B aos `ui_*`).

## Regras
Não inventar resultados de testes. Commits pequenos por marco. Atualizar `IMPLEMENTATION_STATUS.md` com evidência (arquivo, teste, captura).
