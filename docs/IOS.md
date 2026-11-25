# Snowboard Legends 3D no iPhone / iPad

## O que já está no projeto
- **Controles por toque** (`scripts/ui/touch_controls.gd`): metade esquerda da tela = analógico flutuante que aparece sob o
  polegar (esquerda/direita vira, empurrar para cima = tuck, puxar para baixo = freio); à direita, botões **SALTO**
  (segure para carregar — anel amarelo mostra a carga — e solte), **GRAB**, **◀ / ▶** (giro), item **ofensivo** (vermelho)
  e **utilitário** (azul) com o ícone do item, e **II** (pausa). Multitoque: dá para virar e saltar ao mesmo tempo.
  Manobra-assinatura: no ar, ◀, ▶, GRAB em sequência.
- **Virar inclinando o aparelho** (acelerômetro): Opções → *Virar inclinando o aparelho*.
- **Gamepad Bluetooth** (Xbox, PlayStation, MFi) funciona como no PC, inclusive no multiplayer local.
- **Menus tocáveis**: todos os botões/seletores respondem ao toque; botão **◀ Voltar** no canto superior (não há Esc).
- **Área segura** (notch / Dynamic Island) respeitada pelos menus e pelos controles.
- **Perfil gráfico mobile**: renderizador *Mobile* (Metal via MoltenVK); no primeiro uso em celular a qualidade vai para
  *Baixa* (escala de render 0,75, sem SSAO/SSIL, sombras mais curtas, menos partículas). Pode ser mudada em Opções.
- **Ciclo de vida**: ao ir para segundo plano (botão home, ligação) a corrida pausa e o save é gravado.
- **Vibração** (Taptic) ao tocar os botões e ao ser atingido — desligável em Opções.
- Paisagem com rotação automática (esquerda/direita).
- Ícones do app (1024 px opaco + todos os tamanhos) e tela de abertura: `assets/ios/` (gerados por `tools/gen_app_icons.py`).
- Preset de exportação **iOS** em `export_presets.cfg` (arm64, iOS 14+, iPhone + iPad, *increased memory limit*,
  save acessível pelo app Arquivos).

## O que você precisa fazer (fora deste ambiente Linux)
1. Um **Mac com Xcode** (15 ou mais recente) e o **Godot 4.4.1-stable** com os templates de exportação instalados.
2. Uma conta Apple: a gratuita instala só no seu próprio iPhone (o app expira em 7 dias); a **Apple Developer**
   (US$ 99/ano) permite TestFlight e App Store.
3. No Godot: *Projeto → Exportar → iOS* e preencha **App Store Team ID** (10 caracteres, em developer.apple.com →
   Membership) e, se quiser, troque o **Bundle Identifier** `com.snowboardlegends.game` por um seu (ex.: `com.seunome.snowboardlegends`).
4. Exporte. O preset está com *Export Project Only* ligado: o Godot gera `builds/ios/SnowboardLegends3D.xcodeproj`.
5. Abra o `.xcodeproj` no Xcode, escolha seu iPhone conectado, *Signing & Capabilities* → seu time, e **Run**.
   Para TestFlight/App Store: *Product → Archive*.

Verificado aqui: com um Team ID de teste, a exportação gerou o projeto Xcode completo (`.xcodeproj`, `MoltenVK.xcframework`,
PCK de 40 MB, ícones). O Godot avisa — corretamente — que o `.ipa` só pode ser compilado no macOS.

## Limitações honestas
- **Não foi testado num iPhone real**: este ambiente é Linux sem aparelho. Desempenho, sensação dos controles por toque e
  inclinação precisam ser conferidos no aparelho. Os testes automáticos cobrem a lógica dos controles por toque
  (`tests/run_all.gd`, "touch controls"), mas o servidor gráfico headless não entrega toques do sistema.
- O renderizador Mobile não tem SSAO/SSIL: o visual no celular é um pouco mais simples que no PC em qualidade média/alta.
- Tela dividida com 2–4 jogadores no celular só faz sentido com gamepads Bluetooth (os controles na tela são para 1 jogador).
