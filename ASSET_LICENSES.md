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
| 12 músicas (loop), 37 efeitos | `assets/audio/music/*.ogg`, `assets/audio/sfx/*.wav` | `tools/gen_audio.py` (fontes WAV das músicas em `source_art/audio/`) |
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

## 3. Ferramentas usadas apenas na produção (não distribuídas)

Blender 5.0.1 como módulo Python (`bpy`, GPL — usado como ferramenta; os arquivos gerados não herdam a GPL), Python 3,
NumPy, Pillow, FFmpeg/libvorbis (codificação OGG), Mesa lavapipe + Xvfb (renderização por software das capturas).
