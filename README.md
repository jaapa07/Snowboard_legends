# Snowboard Legends 3D

Corrida arcade de snowboard em 3D, sucessor espiritual original (sem modelos, mapas, músicas, nomes, logotipos ou interface
do jogo de referência). 8 pistas de campanha + Parque de Manobras, 8 pilotos + 1 secreto, 12 pranchas, 10 itens,
Grand Prix / Corrida rápida / Contra o relógio com fantasma / Trick Attack / Desafios, multiplayer local de 2–4 em tela dividida.

Especificação: `docs/SPEC_MASTER_V3.md`. Estado real e evidências: `IMPLEMENTATION_STATUS.md`. Assets: `ASSET_STATUS.md`,
`assets.manifest.json`, `ASSET_LICENSES.md`.

## Versões fixadas

| Ferramenta | Versão |
|---|---|
| Godot (editor e templates de exportação) | **4.4.1-stable** (official, 49a5bc7b6) — Forward+ |
| Blender (como módulo Python `bpy`) | **5.0.1** (Python 3.11, `uv venv -p 3.11 tools/blenv && uv pip install bpy==5.0.1 numpy`) |
| Python / Pillow / NumPy / FFmpeg | 3.x / 13.0 / 2.x / libvorbis |

## Executar

- **Build Windows x64**: descompacte `SnowboardLegends3D-windows-x64.zip` e rode `SnowboardLegends3D.exe` (PCK embutido; não
  precisa de editor nem internet). Também há `SnowboardLegends3D-linux-x64.zip` (`./SnowboardLegends3D.x86_64`).
- **Pelo projeto**: abra a pasta no Godot 4.4.1 e rode (cena principal `scenes/menus/boot.tscn`), ou `godot --path .`.
- Save local em `user://save.json` (Windows: `%APPDATA%\Godot\app_userdata\Snowboard Legends 3D\`), com backup,
  migração de schema e exportação/importação em Perfil.

## Controles

| Ação | Teclado (padrão, remapeável em Opções → Controles) | Gamepad |
|---|---|---|
| Virar | A / D ou ← / → | analógico esquerdo (zona morta 0,15) |
| Tuck (agachar; no ar: frontflip) | W ou ↑ | RT |
| Frear (no ar: backflip) | S ou ↓ | LT |
| Salto (segure para carregar, solte para saltar) | Espaço | A |
| Giro no ar | Q / E | LB / RB |
| Grab | Shift | X |
| Item ofensivo / utilitário | F / R | Y / B |
| Pausa | Esc | Start |
| Menus | setas ou WASD, Enter/Espaço confirma, Esc volta | D-pad ou analógico, A confirma, B volta |

Multiplayer em um teclado: J1 "Teclado esquerdo" (WASD, Espaço, Q/E, Shift, F/R); J2 "Teclado direito" (setas, numérico
0 salto, 4/6 giro, 5 grab, 1/2 itens). Cada vaga humana escolhe seu dispositivo em **Participantes** (até 4 gamepads).

## Testes

```
godot --headless --path . --fixed-fps 60 res://tests/run_all.tscn            # tudo; código de saída 1 se algo falhar
godot --headless --path . --fixed-fps 60 res://tests/run_all.tscn -- --suite unit,integration,e2e
godot --headless --path . --fixed-fps 60 res://tests/run_all.tscn -- --suite ai --ai-races 100 --ai-laps 2 --tracks vale_pinheiros
python3 tools/build_manifest.py --check                                       # validação de assets/licenças (bloqueia release)
```

RESULTADOS_TESTES

## Benchmark

BENCHMARK_RESULTADOS

## Build de distribuição

```
python3 tools/build_manifest.py --check
godot --headless --path . --export-release "Windows Desktop" builds/windows/SnowboardLegends3D.exe
godot --headless --path . --export-release "Linux" builds/linux/SnowboardLegends3D.x86_64
godot --headless --path . --script res://tests/dump_licenses.gd -- builds/windows   # licença MIT do Godot + avisos de terceiros
```

BUILD_RESULTADOS

## Limitações conhecidas

LIMITACOES
