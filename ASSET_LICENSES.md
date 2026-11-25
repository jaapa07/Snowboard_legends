# ASSET_LICENSES — Snowboard Legends 3D

Procedência e licença de todo arquivo distribuído. Nada foi baixado de bancos de assets; não há URLs inventadas.
O inventário arquivo a arquivo (com método de produção, hash e estado) está em `assets.manifest.json` / `ASSET_STATUS.md`,
gerados por `python3 tools/build_manifest.py`, que **rejeita licença desconhecida** (o build de release roda `--check`).

## 1. Conteúdo original do projeto (`project-original`)

Produzido dentro deste repositório pelos scripts em `tools/` (autoria por modelagem/síntese programada, versionada e
regenerável). Não há material de terceiros nesses arquivos e nada foi copiado do jogo de referência (sem modelos, mapas,
músicas, nomes, logotipos ou interface do original).

| Grupo | Arquivos | Ferramenta / fonte editável |
|---|---|---|
| 9 pilotos rigados, 24 clips cada | `assets/models/riders/*.glb` | `tools/blender/build_riders.py` → `source_art/blend/rider_*.blend` |
| 12 pranchas | `assets/models/boards/boards.glb` | `tools/blender/build_boards.py` → `source_art/blend/boards.blend` |
| Props, vegetação, teleférico, edifícios | `assets/models/props/props.glb` | `tools/blender/build_props.py` → `source_art/blend/props.blend` |
| 10 itens, moeda, 2 estações | `assets/models/items/items.glb` | `tools/blender/build_props.py` → `source_art/blend/items.blend` |
| 9 pistas + dados | `assets/models/tracks/*.glb`, `assets/data/tracks/*.json` | `tools/blender/build_tracks.py`, `tools/track_defs.py` → `source_art/blend/track_*.blend` |
| Retratos (9) | `assets/sprites/portraits/*.png` | render Cycles: `tools/blender/render_rider.py` |
| Ícones de itens (10 + moeda), thumbnails de pranchas (12) | `assets/sprites/items/*.png`, `assets/sprites/boards/*.png` | render Cycles: `tools/blender/render_objects.py` |
| Texturas PBR (albedo + normal) | `assets/textures/*.png` | `tools/gen_textures.py` |
| Sprites FX, medalhas, mapas, logo, ícone, atlas + JSON | `assets/sprites/{fx,maps,ui}/*` | `tools/gen_sprites.py` |
| Cadeados de UI | `assets/sprites/ui/lock.png`, `unlock.png` | `tools/gen_ui_icons.py` |
| 12 músicas (loop), 37 efeitos | `assets/audio/music/*.ogg`, `assets/audio/sfx/*.wav` | `tools/gen_audio.py` — síntese própria em numpy (sem samples de terceiros); partitura de cada música (forma, acordes, melodias) em `source_art/audio/*.json` |
| Tema de UI | `assets/ui/theme.tres` | escrito à mão |

Titularidade: do(a) dono(a) deste repositório. **Nenhuma licença pública foi escolhida para esse conteúdo** — essa decisão é
do(a) titular; até lá, o conteúdo segue com todos os direitos reservados. (Registrado como pendência de decisão do titular,
não como bloqueio técnico.)

Kaito, o 9º piloto secreto, é um personagem original deste projeto (paleta, rosto, acessórios e animação de vitória próprios,
definidos em `tools/blender/build_riders.py`); não representa personagem de terceiros.

## 2. Terceiros

| Componente | Arquivos | Autor | Fonte | Licença | Alterações |
|---|---|---|---|---|---|
| Fonte Inter 4.0 (Bold, Black, SemiBold) | `assets/fonts/Inter-*.otf` | The Inter Project Authors | https://github.com/rsms/inter (obtida do pacote Debian/Ubuntu `fonts-inter` 4.0+ds-1) | SIL Open Font License 1.1 — texto completo em `assets/fonts/OFL-Inter.txt` | nenhuma |
| Godot Engine 4.4.1-stable (templates de exportação, embutidos nos executáveis) | `builds/*` | Godot Engine contributors; Juan Linietsky, Ariel Manzur | https://godotengine.org | MIT — `GODOT_LICENSE.txt` e avisos de componentes de terceiros do motor em `GODOT_THIRDPARTY.txt`, gerados por `tests/dump_licenses.gd` e incluídos no ZIP | nenhuma |

| Textura “metal_plate_02” (albedo neutralizado, normal GL, rugosidade, 1K) | `assets/textures/cc0/metal_plate_*.jpg` | Poly Haven | https://polyhaven.com/a/metal_plate_02 | CC0 1.0 | redimensionada 1K; albedo com cor média removida (`neutral`) |
| Textura “rocks_ground_04” (albedo neutralizado, normal GL, rugosidade, 1K) | `assets/textures/cc0/rock_cliff_*.jpg` | Poly Haven | https://polyhaven.com/a/rocks_ground_04 | CC0 1.0 | redimensionada 1K; albedo com cor média removida (`neutral`) |
| Textura “dark_rock_02” (albedo neutralizado, normal GL, rugosidade, 1K) | `assets/textures/cc0/rock_dark_*.jpg` | Poly Haven | https://polyhaven.com/a/dark_rock_02 | CC0 1.0 | redimensionada 1K; albedo com cor média removida (`neutral`) |
| Textura “snow_02” (albedo neutralizado, normal GL, rugosidade, 1K) | `assets/textures/cc0/snow_groomed_*.jpg` | Poly Haven | https://polyhaven.com/a/snow_02 | CC0 1.0 | redimensionada 1K; albedo com cor média removida (`snow`) |
| Textura “snow_01” (albedo neutralizado, normal GL, rugosidade, 1K) | `assets/textures/cc0/snow_powder_*.jpg` | Poly Haven | https://polyhaven.com/a/snow_01 | CC0 1.0 | redimensionada 1K; albedo com cor média removida (`snow`) |
| Textura “brown_planks_03” (albedo neutralizado, normal GL, rugosidade, 1K) | `assets/textures/cc0/wood_planks_*.jpg` | Poly Haven | https://polyhaven.com/a/brown_planks_03 | CC0 1.0 | redimensionada 1K; albedo com cor média removida (`neutral`) |
| Textura “Ice002” (1K-JPG) | `assets/textures/cc0/ice_*.jpg` | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Ice002 | CC0 1.0 | albedo com cor média removida |
| Céu HDRI “kloofendal_48d_partly_cloudy_puresky” (2K .hdr) | `assets/sky/sky_day.jpg` | Poly Haven | https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky | CC0 1.0 | tone mapping ACES, exposição -0.3 EV, grade (1.0, 1.0, 1.0), metade inferior esmaecida para a cor do horizonte |
| Céu HDRI “kloppenheim_06_puresky” (2K .hdr) | `assets/sky/sky_forest.jpg` | Poly Haven | https://polyhaven.com/a/kloppenheim_06_puresky | CC0 1.0 | tone mapping ACES, exposição +0.0 EV, grade (1.0, 1.0, 1.0), metade inferior esmaecida para a cor do horizonte |
| Céu HDRI “syferfontein_18d_clear_puresky” (2K .hdr) | `assets/sky/sky_ice.jpg` | Poly Haven | https://polyhaven.com/a/syferfontein_18d_clear_puresky | CC0 1.0 | tone mapping ACES, exposição +0.0 EV, grade (0.95, 1.0, 1.05), metade inferior esmaecida para a cor do horizonte |
| Céu HDRI “qwantani_night_puresky” (2K .hdr) | `assets/sky/sky_night.jpg` | Poly Haven | https://polyhaven.com/a/qwantani_night_puresky | CC0 1.0 | tone mapping ACES, exposição -2.6 EV, grade (0.55, 0.7, 1.35), metade inferior esmaecida para a cor do horizonte |
| Céu HDRI “qwantani_dusk_2_puresky” (2K .hdr) | `assets/sky/sky_sky.jpg` | Poly Haven | https://polyhaven.com/a/qwantani_dusk_2_puresky | CC0 1.0 | tone mapping ACES, exposição -0.7 EV, grade (1.12, 0.86, 1.18), metade inferior esmaecida para a cor do horizonte |
| Céu HDRI “kloofendal_28d_misty_puresky” (2K .hdr) | `assets/sky/sky_station.jpg` | Poly Haven | https://polyhaven.com/a/kloofendal_28d_misty_puresky | CC0 1.0 | tone mapping ACES, exposição +0.0 EV, grade (0.97, 0.99, 1.02), metade inferior esmaecida para a cor do horizonte |
| Céu HDRI “kloofendal_overcast_puresky” (2K .hdr) | `assets/sky/sky_storm.jpg` | Poly Haven | https://polyhaven.com/a/kloofendal_overcast_puresky | CC0 1.0 | tone mapping ACES, exposição +0.0 EV, grade (0.95, 0.98, 1.04), metade inferior esmaecida para a cor do horizonte |
| Céu HDRI “belfast_sunset_puresky” (2K .hdr) | `assets/sky/sky_volcano.jpg` | Poly Haven | https://polyhaven.com/a/belfast_sunset_puresky | CC0 1.0 | tone mapping ACES, exposição -0.4 EV, grade (1.25, 0.86, 0.68), metade inferior esmaecida para a cor do horizonte |
| Animações “Skateboarding”, “Knocked Down”, “Getting Up”, “Jogging Stumble” (captura de movimento, só esqueleto) | clips `push`; `fall`/`recover` de Mika, Luna, Boro e Zed; `hit` dentro de `assets/models/riders/*.glb` | Mixamo (Adobe) | https://www.mixamo.com — arquivo fornecido pelo titular do projeto | Termos de uso do Mixamo/Adobe (uso em jogos permitido; o FBX bruto não é redistribuído — `source_art/anim_import/` fica fora do git) | espelhada (base goofy), movimento relativo aplicado sobre a pose autoral, quadril e pé de trás relativos ao pé da frente, 24 fps, fechamento de loop |
| Capturas de movimento: danças/comemorações (AirGuitar, MacarenaDance, Dancing_Marching, Dance02_FlappyDance, InflatableTubeManDance, Dancing02, Emote_Celebrate, Emote_JumpforJoy, SillyDance_Short), esperas (Idle, Idle_01/02/03, Idle_Conversation, Idle_CharacterLoading01/02) e queda (Falling) | clips `victory`, `idle`, `fall`, `recover` dentro de `assets/models/riders/*.glb` | Rokoko (pacote de mocap gratuito) | arquivos fornecidos pelo titular do projeto | **A CONFIRMAR** — texto da licença do pacote ainda não anexado; FBX brutos fora do git | trecho escolhido automaticamente (queda e levantar: trechos fixos, 2× mais rápidos), transferido para o esqueleto próprio, virado para a frente do piloto, pés fixos na prancha, 24 fps, fechamento de loop |

Os arquivos CC0 são baixados e convertidos por `tools/fetch_cc0.py`; URLs e MD5 dos originais ficam em `source_art/cc0/sources.json`. CC0 não exige atribuição; os créditos acima são cortesia.

## 3. Ferramentas usadas apenas na produção (não distribuídas)

Blender 5.0.1 como módulo Python (`bpy`, GPL — usado como ferramenta; os arquivos gerados não herdam a GPL), Python 3,
NumPy, Pillow, FFmpeg/libvorbis (codificação OGG), Mesa lavapipe + Xvfb (renderização por software das capturas).
