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

## Arquitetura
- `scripts/race/track_runtime.gd`: carrega GLB+JSON da pista, materiais, ambiente, colisores de features, MultiMesh de vegetação, moedas, estações, teleférico; `project()` / `point_at()` sobre a spline.
- `scripts/rider/rider_controller.gd`: CharacterBody3D, física arcade; velocidade no solo integrada internamente (`_vf/_vl`) — **não** ler de volta `velocity` após `move_and_slide` (isso travava os pilotos a ~3,7 m/s). Qualquer alteração externa de velocidade deve usar `_scale_speed()` / `push()` / `_seed_speed()`.
- `scripts/ai/ai_driver.gd`: FSM, atraso de reação 450/250/120 ms, rotas, estações, manobras, itens.
- `scripts/race/race_manager.gd`: fases, checkpoints, ranking 10 Hz, `LiftSystem` (FIFO, 1,2 s, 3 s), chegada, ghost, slalom.
- Coordenadas: modelos Blender ficam de frente para +Z no Godot; `RiderVisual` gira 180°. Frente da corrida = -Z, `yaw` com forward = (-sin, 0, -cos).

## Regras
Não inventar resultados de testes. Commits pequenos por marco. Atualizar `IMPLEMENTATION_STATUS.md` com evidência (arquivo, teste, captura).
