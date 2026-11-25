# ASSET_STATUS — Snowboard Legends 3D

Gerado por `python3 tools/build_manifest.py` a partir dos arquivos presentes (não editar à mão).
Estados: `missing` (arquivo ausente), `in_progress` (presente mas reprovado na validação), `integrated` (presente, validado e referenciado pelo jogo),
`verified` (além disso carregado por teste automatizado e/ou visível em captura real). O build de release roda `--check` e falha com `missing`/`in_progress`.

| Tipo | Qtd | missing | in_progress | integrated | verified | Verificação |
|---|---:|---:|---:|---:|---:|---|
| rider_model | 9 | 0 | 0 | 0 | 9 | tests/run_all unit content + races; docs/screenshots/riders |
| portrait | 9 | 0 | 0 | 0 | 9 | tests/run_all content check; HUD/results captures |
| board_library | 1 | 0 | 0 | 1 | 0 | validação de arquivo/formato |
| board_thumbnail | 12 | 0 | 0 | 12 | 0 | validação de arquivo/formato |
| item_library | 1 | 0 | 0 | 1 | 0 | validação de arquivo/formato |
| item_icon | 11 | 0 | 0 | 0 | 11 | tests/run_all content check |
| prop_library | 1 | 0 | 0 | 1 | 0 | validação de arquivo/formato |
| track_scene | 9 | 0 | 0 | 0 | 9 | tests/run_all AI races on every course; docs/screenshots/tracks |
| track_data | 9 | 0 | 0 | 0 | 9 | tests/run_all checkpoint spacing + AI races |
| map | 9 | 0 | 0 | 0 | 9 | tests/run_all content check; menu captures |
| music | 12 | 0 | 0 | 0 | 12 | tests/run_all content check (course music) |
| sfx | 37 | 0 | 0 | 37 | 0 | validação de arquivo/formato |
| texture | 28 | 0 | 0 | 28 | 0 | validação de arquivo/formato |
| fx_sprite | 6 | 0 | 0 | 6 | 0 | validação de arquivo/formato |
| ui_sprite | 11 | 0 | 0 | 11 | 0 | validação de arquivo/formato |
| atlas_metadata | 1 | 0 | 0 | 1 | 0 | validação de arquivo/formato |
| ui_theme | 1 | 0 | 0 | 1 | 0 | validação de arquivo/formato |
| font | 3 | 0 | 0 | 3 | 0 | validação de arquivo/formato |
| license_text | 1 | 0 | 0 | 1 | 0 | validação de arquivo/formato |

## Detalhe

| id | arquivo | estado | método de produção | licença | observações |
|---|---|---|---|---|---|
| rider_model:niko | `assets/models/riders/niko.glb` | verified | scripted modelling + rig + 24 clips in Blender 5.0.1 (tools/blender/build_riders.py) | project-original | 24 clips, 1 meshes |
| portrait:niko | `assets/sprites/portraits/niko.png` | verified | Cycles render of the rigged model (tools/blender/render_rider.py portrait) | project-original | 256x256 |
| rider_model:mika | `assets/models/riders/mika.glb` | verified | scripted modelling + rig + 24 clips in Blender 5.0.1 (tools/blender/build_riders.py) | project-original | 24 clips, 1 meshes |
| portrait:mika | `assets/sprites/portraits/mika.png` | verified | Cycles render of the rigged model (tools/blender/render_rider.py portrait) | project-original | 256x256 |
| rider_model:taro | `assets/models/riders/taro.glb` | verified | scripted modelling + rig + 24 clips in Blender 5.0.1 (tools/blender/build_riders.py) | project-original | 24 clips, 1 meshes |
| portrait:taro | `assets/sprites/portraits/taro.png` | verified | Cycles render of the rigged model (tools/blender/render_rider.py portrait) | project-original | 256x256 |
| rider_model:luna | `assets/models/riders/luna.glb` | verified | scripted modelling + rig + 24 clips in Blender 5.0.1 (tools/blender/build_riders.py) | project-original | 24 clips, 1 meshes |
| portrait:luna | `assets/sprites/portraits/luna.png` | verified | Cycles render of the rigged model (tools/blender/render_rider.py portrait) | project-original | 256x256 |
| rider_model:boro | `assets/models/riders/boro.glb` | verified | scripted modelling + rig + 24 clips in Blender 5.0.1 (tools/blender/build_riders.py) | project-original | 24 clips, 1 meshes |
| portrait:boro | `assets/sprites/portraits/boro.png` | verified | Cycles render of the rigged model (tools/blender/render_rider.py portrait) | project-original | 256x256 |
| rider_model:yuki | `assets/models/riders/yuki.glb` | verified | scripted modelling + rig + 24 clips in Blender 5.0.1 (tools/blender/build_riders.py) | project-original | 24 clips, 1 meshes |
| portrait:yuki | `assets/sprites/portraits/yuki.png` | verified | Cycles render of the rigged model (tools/blender/render_rider.py portrait) | project-original | 256x256 |
| rider_model:zed | `assets/models/riders/zed.glb` | verified | scripted modelling + rig + 24 clips in Blender 5.0.1 (tools/blender/build_riders.py) | project-original | 24 clips, 1 meshes |
| portrait:zed | `assets/sprites/portraits/zed.png` | verified | Cycles render of the rigged model (tools/blender/render_rider.py portrait) | project-original | 256x256 |
| rider_model:pippa | `assets/models/riders/pippa.glb` | verified | scripted modelling + rig + 24 clips in Blender 5.0.1 (tools/blender/build_riders.py) | project-original | 24 clips, 1 meshes |
| portrait:pippa | `assets/sprites/portraits/pippa.png` | verified | Cycles render of the rigged model (tools/blender/render_rider.py portrait) | project-original | 256x256 |
| rider_model:kaito | `assets/models/riders/kaito.glb` | verified | scripted modelling + rig + 24 clips in Blender 5.0.1 (tools/blender/build_riders.py) | project-original | 24 clips, 1 meshes |
| portrait:kaito | `assets/sprites/portraits/kaito.png` | verified | Cycles render of the rigged model (tools/blender/render_rider.py portrait) | project-original | 256x256 |
| boards | `assets/models/boards/boards.glb` | integrated | scripted modelling in Blender (tools/blender/build_boards.py) | project-original | 12 meshes |
| board_thumb:starter | `assets/sprites/boards/board_starter.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:carver | `assets/sprites/boards/board_carver.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:float | `assets/sprites/boards/board_float.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:rocket | `assets/sprites/boards/board_rocket.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:grip | `assets/sprites/boards/board_grip.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:twin | `assets/sprites/boards/board_twin.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:powder | `assets/sprites/boards/board_powder.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:rail | `assets/sprites/boards/board_rail.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:alpine | `assets/sprites/boards/board_alpine.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:aurora | `assets/sprites/boards/board_aurora.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:comet | `assets/sprites/boards/board_comet.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| board_thumb:legend | `assets/sprites/boards/board_legend.png` | integrated | Cycles render (tools/blender/render_objects.py board) | project-original | 256x256 |
| items | `assets/models/items/items.glb` | integrated | scripted modelling in Blender (tools/blender/build_props.py) | project-original | 13 meshes |
| item_icon:snowball | `assets/sprites/items/snowball.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:icemine | `assets/sprites/items/icemine.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:penguin | `assets/sprites/items/penguin.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:fog | `assets/sprites/items/fog.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:wave | `assets/sprites/items/wave.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:gust | `assets/sprites/items/gust.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:shield | `assets/sprites/items/shield.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:spring | `assets/sprites/items/spring.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:magnet | `assets/sprites/items/magnet.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:repair | `assets/sprites/items/repair.png` | verified | Cycles render of the item model (tools/blender/render_objects.py item) | project-original | 256x256 |
| item_icon:coin | `assets/sprites/items/coin.png` | verified | Cycles render (tools/blender/render_objects.py item) | project-original | 256x256 |
| props | `assets/models/props/props.glb` | integrated | scripted modelling in Blender (tools/blender/build_props.py) | project-original | 64 meshes |
| track_scene:vale_pinheiros | `assets/models/tracks/vale_pinheiros.glb` | verified | authored course built in Blender from the course definition (tools/blender/build_tracks.py) | project-original | 54 meshes |
| track_data:vale_pinheiros | `assets/data/tracks/vale_pinheiros.json` | verified | exported with the course (spline, widths, checkpoints, zones, lift) | project-original |  |
| map:vale_pinheiros | `assets/sprites/maps/vale_pinheiros.png` | verified | illustrated map drawn from course data (tools/gen_sprites.py) | project-original | 512x512 |
| music:vale_pinheiros | `assets/audio/music/track_vale_pinheiros.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| track_scene:lago_cristal | `assets/models/tracks/lago_cristal.glb` | verified | authored course built in Blender from the course definition (tools/blender/build_tracks.py) | project-original | 51 meshes |
| track_data:lago_cristal | `assets/data/tracks/lago_cristal.json` | verified | exported with the course (spline, widths, checkpoints, zones, lift) | project-original |  |
| map:lago_cristal | `assets/sprites/maps/lago_cristal.png` | verified | illustrated map drawn from course data (tools/gen_sprites.py) | project-original | 512x512 |
| music:lago_cristal | `assets/audio/music/track_lago_cristal.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| track_scene:pico_vulcanico | `assets/models/tracks/pico_vulcanico.glb` | verified | authored course built in Blender from the course definition (tools/blender/build_tracks.py) | project-original | 54 meshes |
| track_data:pico_vulcanico | `assets/data/tracks/pico_vulcanico.json` | verified | exported with the course (spline, widths, checkpoints, zones, lift) | project-original |  |
| map:pico_vulcanico | `assets/sprites/maps/pico_vulcanico.png` | verified | illustrated map drawn from course data (tools/gen_sprites.py) | project-original | 512x512 |
| music:pico_vulcanico | `assets/audio/music/track_pico_vulcanico.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| track_scene:festival_boreal | `assets/models/tracks/festival_boreal.glb` | verified | authored course built in Blender from the course definition (tools/blender/build_tracks.py) | project-original | 78 meshes |
| track_data:festival_boreal | `assets/data/tracks/festival_boreal.json` | verified | exported with the course (spline, widths, checkpoints, zones, lift) | project-original |  |
| map:festival_boreal | `assets/sprites/maps/festival_boreal.png` | verified | illustrated map drawn from course data (tools/gen_sprites.py) | project-original | 512x512 |
| music:festival_boreal | `assets/audio/music/track_festival_boreal.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| track_scene:floresta_gigante | `assets/models/tracks/floresta_gigante.glb` | verified | authored course built in Blender from the course definition (tools/blender/build_tracks.py) | project-original | 70 meshes |
| track_data:floresta_gigante | `assets/data/tracks/floresta_gigante.json` | verified | exported with the course (spline, widths, checkpoints, zones, lift) | project-original |  |
| map:floresta_gigante | `assets/sprites/maps/floresta_gigante.png` | verified | illustrated map drawn from course data (tools/gen_sprites.py) | project-original | 512x512 |
| music:floresta_gigante | `assets/audio/music/track_floresta_gigante.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| track_scene:estacao_abandonada | `assets/models/tracks/estacao_abandonada.glb` | verified | authored course built in Blender from the course definition (tools/blender/build_tracks.py) | project-original | 76 meshes |
| track_data:estacao_abandonada | `assets/data/tracks/estacao_abandonada.json` | verified | exported with the course (spline, widths, checkpoints, zones, lift) | project-original |  |
| map:estacao_abandonada | `assets/sprites/maps/estacao_abandonada.png` | verified | illustrated map drawn from course data (tools/gen_sprites.py) | project-original | 512x512 |
| music:estacao_abandonada | `assets/audio/music/track_estacao_abandonada.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| track_scene:tempestade_polar | `assets/models/tracks/tempestade_polar.glb` | verified | authored course built in Blender from the course definition (tools/blender/build_tracks.py) | project-original | 52 meshes |
| track_data:tempestade_polar | `assets/data/tracks/tempestade_polar.json` | verified | exported with the course (spline, widths, checkpoints, zones, lift) | project-original |  |
| map:tempestade_polar | `assets/sprites/maps/tempestade_polar.png` | verified | illustrated map drawn from course data (tools/gen_sprites.py) | project-original | 512x512 |
| music:tempestade_polar | `assets/audio/music/track_tempestade_polar.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| track_scene:cume_celestial | `assets/models/tracks/cume_celestial.glb` | verified | authored course built in Blender from the course definition (tools/blender/build_tracks.py) | project-original | 114 meshes |
| track_data:cume_celestial | `assets/data/tracks/cume_celestial.json` | verified | exported with the course (spline, widths, checkpoints, zones, lift) | project-original |  |
| map:cume_celestial | `assets/sprites/maps/cume_celestial.png` | verified | illustrated map drawn from course data (tools/gen_sprites.py) | project-original | 512x512 |
| music:cume_celestial | `assets/audio/music/track_cume_celestial.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| track_scene:parque_manobras | `assets/models/tracks/parque_manobras.glb` | verified | authored course built in Blender from the course definition (tools/blender/build_tracks.py) | project-original | 91 meshes |
| track_data:parque_manobras | `assets/data/tracks/parque_manobras.json` | verified | exported with the course (spline, widths, checkpoints, zones, lift) | project-original |  |
| map:parque_manobras | `assets/sprites/maps/parque_manobras.png` | verified | illustrated map drawn from course data (tools/gen_sprites.py) | project-original | 512x512 |
| music:parque_manobras | `assets/audio/music/track_parque_manobras.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| music:menu | `assets/audio/music/menu.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| music:results | `assets/audio/music/results.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| music:victory | `assets/audio/music/victory.ogg` | verified | original synthesized loop (tools/gen_audio.py) | project-original |  |
| sfx:boost | `assets/audio/sfx/boost.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:buy | `assets/audio/sfx/buy.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:buy_fail | `assets/audio/sfx/buy_fail.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:carve_loop | `assets/audio/sfx/carve_loop.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:coin | `assets/audio/sfx/coin.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:count | `assets/audio/sfx/count.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:count_go | `assets/audio/sfx/count_go.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:crash | `assets/audio/sfx/crash.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:finish | `assets/audio/sfx/finish.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:fog | `assets/audio/sfx/fog.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:gate | `assets/audio/sfx/gate.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:grind | `assets/audio/sfx/grind.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:hit | `assets/audio/sfx/hit.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:ice_burst | `assets/audio/sfx/ice_burst.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:ice_loop | `assets/audio/sfx/ice_loop.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:jump | `assets/audio/sfx/jump.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:land | `assets/audio/sfx/land.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:land_hard | `assets/audio/sfx/land_hard.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:lap | `assets/audio/sfx/lap.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:lift | `assets/audio/sfx/lift.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:magnet | `assets/audio/sfx/magnet.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:mine_drop | `assets/audio/sfx/mine_drop.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:penguin | `assets/audio/sfx/penguin.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:perfect | `assets/audio/sfx/perfect.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:repair | `assets/audio/sfx/repair.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:shield | `assets/audio/sfx/shield.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:shield_break | `assets/audio/sfx/shield_break.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:snow_loop | `assets/audio/sfx/snow_loop.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:spring | `assets/audio/sfx/spring.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:throw | `assets/audio/sfx/throw.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:ui_back | `assets/audio/sfx/ui_back.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:ui_move | `assets/audio/sfx/ui_move.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:ui_ok | `assets/audio/sfx/ui_ok.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:ui_open | `assets/audio/sfx/ui_open.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:unlock | `assets/audio/sfx/unlock.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:wave | `assets/audio/sfx/wave.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| sfx:wind_loop | `assets/audio/sfx/wind_loop.wav` | integrated | original synthesized sound (tools/gen_audio.py) | project-original |  |
| texture:bark_albedo | `assets/textures/bark_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:bark_normal | `assets/textures/bark_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:ice_albedo | `assets/textures/ice_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:ice_normal | `assets/textures/ice_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:metal_rust_albedo | `assets/textures/metal_rust_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:metal_rust_normal | `assets/textures/metal_rust_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:metal_steel_albedo | `assets/textures/metal_steel_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:metal_steel_normal | `assets/textures/metal_steel_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:rock_blue_albedo | `assets/textures/rock_blue_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:rock_blue_normal | `assets/textures/rock_blue_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:rock_grey_albedo | `assets/textures/rock_grey_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:rock_grey_normal | `assets/textures/rock_grey_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:rock_volcanic_albedo | `assets/textures/rock_volcanic_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:rock_volcanic_normal | `assets/textures/rock_volcanic_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_ash_albedo | `assets/textures/snow_ash_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_ash_normal | `assets/textures/snow_ash_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_day_albedo | `assets/textures/snow_day_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_day_normal | `assets/textures/snow_day_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_night_albedo | `assets/textures/snow_night_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_night_normal | `assets/textures/snow_night_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_sky_albedo | `assets/textures/snow_sky_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_sky_normal | `assets/textures/snow_sky_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_soft_albedo | `assets/textures/snow_soft_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_soft_normal | `assets/textures/snow_soft_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_storm_albedo | `assets/textures/snow_storm_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:snow_storm_normal | `assets/textures/snow_storm_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:wood_plank_albedo | `assets/textures/wood_plank_albedo.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| texture:wood_plank_normal | `assets/textures/wood_plank_normal.png` | integrated | procedural PBR texture synthesis (tools/gen_textures.py) | project-original | 512x512 |
| fx:confetti_strip | `assets/sprites/fx/confetti_strip.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 256x64 |
| fx:flake | `assets/sprites/fx/flake.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 64x64 |
| fx:puff | `assets/sprites/fx/puff.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 64x64 |
| fx:shard | `assets/sprites/fx/shard.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 64x64 |
| fx:sparkle | `assets/sprites/fx/sparkle.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 64x64 |
| fx:star | `assets/sprites/fx/star.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 64x64 |
| ui:atlas | `assets/sprites/ui/atlas.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 1024x1024 |
| ui:logo | `assets/sprites/ui/logo.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 1200x420 |
| ui:icon | `assets/sprites/ui/icon.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 256x256 |
| ui:medal_bronze | `assets/sprites/ui/medal_bronze.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 128x160 |
| ui:medal_silver | `assets/sprites/ui/medal_silver.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 128x160 |
| ui:medal_gold | `assets/sprites/ui/medal_gold.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 128x160 |
| ui:warning | `assets/sprites/ui/warning.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 128x128 |
| ui:arrow_left | `assets/sprites/ui/arrow_left.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 128x128 |
| ui:arrow_right | `assets/sprites/ui/arrow_right.png` | integrated | drawn with Pillow (tools/gen_sprites.py) | project-original | 128x128 |
| ui:lock | `assets/sprites/ui/lock.png` | integrated | drawn with Pillow (tools/gen_ui_icons.py) | project-original | 128x128 |
| ui:unlock | `assets/sprites/ui/unlock.png` | integrated | drawn with Pillow (tools/gen_ui_icons.py) | project-original | 128x128 |
| ui:atlas_json | `assets/sprites/ui/atlas.json` | integrated | generated with the atlas (tools/gen_sprites.py) | project-original |  |
| ui:theme | `assets/ui/theme.tres` | integrated | hand-written Godot theme | project-original |  |
| font:Inter-Bold | `assets/fonts/Inter-Bold.otf` | integrated | third-party font, unmodified | OFL-1.1 |  |
| font:Inter-Black | `assets/fonts/Inter-Black.otf` | integrated | third-party font, unmodified | OFL-1.1 |  |
| font:Inter-SemiBold | `assets/fonts/Inter-SemiBold.otf` | integrated | third-party font, unmodified | OFL-1.1 |  |
| font:license | `assets/fonts/OFL-Inter.txt` | integrated | license text shipped with the font | OFL-1.1 |  |
