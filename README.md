# Snowboard Legends 3D

Corrida arcade de snowboard em 3D, sucessor espiritual original (sem modelos, mapas, músicas, nomes, logotipos ou interface
do jogo de referência). 8 pistas de campanha + Parque de Manobras, 8 pilotos + 1 secreto (Kaito, original), 12 pranchas,
12 itens, Grand Prix / Corrida rápida / Contra o relógio com fantasma / Trick Attack / Desafios (slalom, pousos, moedas,
tiro ao alvo), multiplayer local de 2–4 em tela dividida, manobra-assinatura por piloto, upgrades de prancha e número de
descidas próprio de cada pista (Vale 5, Lago 4, Pico 4, Festival 5, Floresta 4, Estação 4, Tempestade 4, Cume 3, Parque 9).

Especificação: `docs/SPEC_MASTER_V3.md`. Estado real e evidências: `IMPLEMENTATION_STATUS.md`. Assets: `ASSET_STATUS.md`,
`assets.manifest.json`, `ASSET_LICENSES.md`.

## Versões fixadas

| Ferramenta | Versão |
|---|---|
| Godot (editor e templates de exportação) | **4.4.1-stable** (official, 49a5bc7b6) — Forward+ |
| Blender (como módulo Python `bpy`) | **5.0.1** (Python 3.11, `uv venv -p 3.11 tools/blenv && uv pip install bpy==5.0.1 numpy`) |
| Python / Pillow / NumPy / FFmpeg | 3.x / 13.0 / 2.x / libvorbis |

## Executar

- **Build Windows x64**: descompacte `SnowboardLegends3D-1.0.0-windows-x64.zip` e rode `SnowboardLegends3D.exe` (PCK embutido; não
  precisa de editor nem internet; requer GPU com Vulkan). Também há `SnowboardLegends3D-1.0.0-linux-x64.zip`
  (`./SnowboardLegends3D.x86_64`).
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
| Manobra-assinatura (no ar, em sequência) | Q, E, Shift | LB, RB, X |
| Item ofensivo / utilitário | F / R | Y / B |
| Pausa | Esc | Start |
| Menus | setas ou WASD, Enter/Espaço confirma, Esc volta | D-pad ou analógico, A confirma, B volta |

**Multiplayer local** (2–4, tela dividida): menu *Multiplayer local* (ou Participantes em Corrida rápida / Grand Prix);
START num gamepad livre entra como novo jogador. Multiplayer em um teclado: J1 "Teclado esquerdo" (WASD, Espaço, Q/E, Shift, F/R); J2 "Teclado direito" (setas, numérico
0 salto, 4/6 giro, 5 grab, 1/2 itens). Cada vaga humana escolhe seu dispositivo em **Participantes** (até 4 gamepads).

## Testes

```
godot --headless --path . --fixed-fps 60 res://tests/run_all.tscn            # tudo; código de saída 1 se algo falhar
godot --headless --path . --fixed-fps 60 res://tests/run_all.tscn -- --suite unit,integration,e2e
godot --headless --path . --fixed-fps 60 res://tests/run_all.tscn -- --suite ai --ai-races 100 --ai-laps 2 --tracks vale_pinheiros
python3 tools/build_manifest.py --check                                       # validação de assets/licenças (bloqueia release)
```

Última execução (`docs/test_reports/suite_unit_integration_e2e.json`): **329 verificações, 0 falhas** em 55 s —
unitários 185 (física, limites de velocidade 24/29/35 m/s, salto/coyote/buffer, manobras/combos/pouso/assinatura,
moedas, cooldown de dano/escudo, fila FIFO do teleférico, classificação, save/migração/backup, RNG com seed,
créditos/medalhas/desbloqueios, conteúdo/i18n, upgrades de prancha), integração 101 (corrida completa com teleférico,
estações e os 12 itens, reset fora da pista, as duas rotas de cada bifurcação, final de copa + recarga do save,
fantasma do Time Trial, Trick Attack, desafios incluindo tiro ao alvo, tela dividida 2–4) e E2E 43 (menus por teclado e
gamepad, remapeamento, multiplayer local, garagem, fluxo do Grand Prix, pausa/reinício).

Corridas de IA (`docs/test_reports/ai_<pista>.json`): **100 corridas por pista, 2 descidas cada (com teleférico),
seeds 1000 + 37·k, 4 pilotos, dificuldade normal — 900/900 concluídas**:

| Pista | Corridas concluídas | Pilotos que chegaram | Checkpoints pulados | NaN | Resets | Melhor vencedor | Mediana vencedor |
|---|---|---|---|---|---|---|---|
| cume_celestial | 100/100 | 400/400 | 0 | 0 | 0 | 106.9 s | 116.6 s |
| estacao_abandonada | 100/100 | 400/400 | 0 | 0 | 0 | 85.1 s | 93.2 s |
| festival_boreal | 100/100 | 400/400 | 0 | 0 | 0 | 76.5 s | 83.0 s |
| floresta_gigante | 100/100 | 400/400 | 0 | 0 | 0 | 95.9 s | 104.2 s |
| lago_cristal | 100/100 | 400/400 | 0 | 0 | 0 | 82.8 s | 90.7 s |
| parque_manobras | 100/100 | 400/400 | 0 | 0 | 0 | 45.0 s | 47.9 s |
| pico_vulcanico | 100/100 | 400/400 | 0 | 0 | 60 | 90.0 s | 97.7 s |
| tempestade_polar | 100/100 | 400/400 | 0 | 0 | 0 | 97.6 s | 106.3 s |
| vale_pinheiros | 100/100 | 400/400 | 0 | 0 | 0 | 69.3 s | 74.7 s |

A bateria de IA encontrou e motivou correções reais: oscilação da direção da IA (piloto não terminava a descida) e
um loop de reset diante da fenda do Pico Vulcânico (41/100 corridas incompletas antes da correção; 100/100 depois).
Duração de corrida completa (descidas por pista): 3:04–3:54 com o vencedor de IA.

## Benchmark

Medido com `--benchmark 30` (30 s de corrida real em Vale dos Pinheiros, tempo de relógio por quadro;
`docs/test_reports/benchmark_*.json`). **Hardware: Intel Xeon 2,10 GHz, 4 núcleos, 15 GB RAM, Ubuntu 24.04, sem GPU —
renderização por software (Mesa llvmpipe/lavapipe)**, janela 1280×720 (resolução lógica 1600×900).

| Renderizador / qualidade | FPS médio | Frame médio | p95 | p99 | Memória estática (pico) | Memória de vídeo | Draw calls |
|---|---|---|---|---|---|---|---|
| Forward+ média | 1,1 | 883,6 ms | 966,4 ms | 975,1 ms | 82,5 MB | 258,0 MB | 408 |
| Forward+ baixa | 5,3 | 189,7 ms | 222,4 ms | 246,1 ms | 82,7 MB | 107,1 MB | 241 |
| Compatibility média | 1,4 | 709,5 ms | 806,6 ms | 889,0 ms | 57,8 MB | 84,2 MB | 404 |

Estes números **não** representam um PC de jogo: sem GPU, cada quadro é rasterizado pela CPU. A meta de 60 FPS
(spec §14) ainda precisa ser medida em hardware com GPU — pendência registrada. A simulação em si roda ~10× mais rápido
que o tempo real em modo headless (uma corrida de 220 s simulada em ~22 s nesta CPU).

## Build de distribuição

```
python3 tools/build_manifest.py --check
godot --headless --path . --export-release "Windows Desktop" builds/windows/SnowboardLegends3D.exe
godot --headless --path . --export-release "Linux" builds/linux/SnowboardLegends3D.x86_64
godot --headless --path . --script res://tests/dump_licenses.gd -- builds/windows   # licença MIT do Godot + avisos de terceiros
```

Gerados em `builds/` (não versionados: o executável Windows tem 137 MB, acima do limite de 100 MB do GitHub):

- `SnowboardLegends3D-1.0.0-windows-x64.zip` (97,3 MB): `SnowboardLegends3D.exe` (PE32+ x86-64, PCK embutido), `LEIA-ME.txt`,
  `ASSET_LICENSES.md`, `OFL-Inter.txt`, `GODOT_LICENSE.txt`, `GODOT_THIRDPARTY.txt`.
- `SnowboardLegends3D-1.0.0-linux-x64.zip` (90,0 MB): mesmo conteúdo com `SnowboardLegends3D.x86_64`.

Teste em pasta limpa (sem editor, sem projeto, `HOME` isolado): o binário Linux descompactado completou uma corrida de
3 descidas no Cume Celestial sem erros de script. O PCK embutido no `.exe` foi carregado pelo motor 4.4.1 (`--main-pack`)
e completou uma corrida de 4 descidas no Lago Cristal sem erros. **O `.exe` em si não pôde ser executado**: não há Windows
nesta máquina e o Wine 9.0 instalado aborta já no `wineboot` (`free(): invalid pointer`). Testar no Windows é pendência.

## Limitações conhecidas

- **Desempenho em GPU não medido** (só há render por software aqui) e **`.exe` não executado em Windows** (ver acima).
- Capturas de tela feitas com Forward+ por software (lavapipe); o renderizador Compatibility no llvmpipe estoura a neve
  e não foi usado como evidência.
- Pilotos com 5,7–7,4 mil triângulos, abaixo do orçamento indicativo de 8–18 mil (spec §13).
- Áudio sintetizado por script (37 efeitos, 12 músicas em loop): funcional, sem qualidade de estúdio; não há vozes
  (por isso não há controle de volume de voz).
- Balanceamento: nas 100 corridas por pista, pilotos de velocidade alta (Taro, Zed) vencem com mais frequência que os de
  controle alto (Yuki, Mika) — ver `wins` em `docs/test_reports/ai_*.json`. Ajuste fino de atributos ainda não feito.
- Crash intermitente do motor observado **uma vez** na inicialização ("Caller thread can't call this function ... /root",
  sinal 11) com vários processos Godot concorrentes; não reproduziu em execuções seguintes nem nas 900 corridas.
- Pesquisa de referência (`docs/REFERENCE_RESEARCH.md`) feita só com trechos de busca: os sites não puderam ser abertos.
- Licença pública do conteúdo original do projeto não definida (decisão do titular) — ver `ASSET_LICENSES.md`.
- Multiplayer em rede não existe (apenas local, por escopo da spec).

## Capturas

Capturas reais do motor em `docs/screenshots/` (Forward+): `tracks/` (cada pista), `riders/` (cada piloto em corrida),
`menus/` (título, participantes, piloto, prancha, pista, copa, opções, controles, garagem, perfil, desafios), `results.png`
(pódio 3D) e `multiplayer/` (2 e 4 jogadores).
