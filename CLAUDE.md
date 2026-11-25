# Notch app — briefing do projeto

App open-source estilo Dynamic Island para macOS, que vive no notch do MacBook.
Distribuição gratuita via GitHub Releases, **sem conta paga da Apple** (app não assinado/notarizado).

## Público e escopo
- Alvo: MacBooks Apple Silicon com notch (Air M2+, Pro 14/16).
- macOS mínimo: 14 (Sonoma).
- Sem notch (Mac mini, iMac, Studio, monitor externo): fallback de "ilha flutuante" centralizada no topo. Baixa prioridade, mas a arquitetura não pode impedir.
- Só Apple Silicon (build arm64).

## Stack
- Swift 5.10+ / SwiftUI para UI, AppKit para janela e eventos.
- Xcode project (ou XcodeGen com `project.yml`), sem dependências pesadas.
- SPM para dependências. Permitidas: Sparkle (auto-update). Avaliar DynamicNotchKit só como referência.
- Sem Electron/Tauri/web views.

## Arquitetura
```
App/
  NotchApp.swift            # @main, LSUIElement (sem Dock), AppDelegate (cria e conecta os módulos)
  Window/
    NotchPanel.swift        # NSPanel borderless, nonactivating, nível acima da menu bar
    NotchRootView.swift     # forma do notch, animações, compacto/expandido/bolha
    NotchGeometry.swift     # detecta notch via NSScreen.safeAreaInsets / auxiliaryTopLeft/RightArea
    HoverTracker.swift      # monitores de mouse -> estados (polling só enquanto o botão está pressionado)
    SwipeHandler.swift      # gesto de dois dedos (próxima/anterior)
  State/
    NotchViewModel.swift    # estados: closed / peek / expanded, alertas; @Observable
  Modules/
    NotchModule.swift       # protocol base: id, compactView, expandedView, isAvailable
    ActivityRegistry.swift  # Activity, ActivityEntry, ActivityProviding, ActivityRegistry
    Media/                  # agora tocando (AppleScript + notificações do Spotify/Music)
    Timer/  Calendar/  Downloads/   # live activities
    Shelf/                  # bandeja (arquivos, imagens, links, texto), persiste em Application Support
    Home/                   # tela inicial quando nada está tocando
    System/                 # monitores: bateria, volume/HUD, bluetooth, rede, Focus, privacidade, screenshots...
  Settings/                 # SettingsView, Prefs (UserDefaults/@AppStorage), onboarding, menu bar
  Support/                  # Updater (Sparkle), FolderWatcher, Feedback, Log (os.Logger), DebugHooks
Tests/CoveTests/            # XCTest da lógica pura (`swift test`)
```

### Como adicionar uma live activity
1. O módulo conforma a `ActivityProviding` e devolve um `ActivityEntry` (`isLive`, `leading`, `trailing`, `bubble`, `expanded`, `wide`, `expandedHeight`).
2. Criar a constante em `Activity` (a prioridade define quem ocupa a ilha) e registrar o módulo em `AppDelegate`.
3. `NotchRootView` não precisa mudar. Chaves de preferência vão em `Prefs` e a UI em `SettingsView`.

Regras:
- Janela: `NSPanel` com `.borderless`, `.nonactivatingPanel`, `level = .mainMenu + 1`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`, fundo transparente, `hasShadow = false`.
- Reposicionar ao mudar telas (`NSApplication.didChangeScreenParametersNotification`).
- O panel fica sempre do tamanho do estado expandido; o conteúdo anima por dentro. Cliques fora da forma visível passam para trás (`ignoresMouseEvents` dinâmico conforme hover).
- Animações SwiftUI com `.spring`; forma do notch = shape customizada com cantos inferiores arredondados.
- Módulos não conhecem a janela; só expõem views e estado.
- **Nada de polling fixo.** Preferir eventos: notificações (distribuídas/NSWorkspace), listeners do Core Audio/CMIO, `FolderWatcher`. Quando um timer for inevitável (progresso, contagem), ele só existe enquanto há algo ativo ou a feature está ligada.
- AppleScript sempre fora da main thread (fila serial do `MediaModule`).
- Features que tocam locais protegidos (Downloads, banco do Focus) só abrem o recurso depois que o usuário liga o toggle.

## Estado atual
Já implementado: Shelf com ações (OCR, converter imagem, zip, AirDrop), panel no notch com hover/peek/expand, mídia (Spotify e Music via AppleScript, scrub, saída de áudio), timer, próxima reunião, downloads, alertas (carregador, bateria baixa, Low Power, AirPods, desbloqueio, online/offline, Focus, screenshots), HUD de volume/brilho (opt-in), Shelf, indicador de câmera/mic, bolha de segunda atividade, gestos, fallback sem notch, onboarding, Sparkle e distribuição via Homebrew.

Ideias para depois (ver conversa de planejamento): letra sincronizada (LRCLIB, opt-in), nome do app que usa o mic (Core Audio process objects, macOS 14.2+), Pomodoro, atalho global, atalhos configuráveis na Home, histórico da área de transferência, perfis por app em foco.

MediaRemote (framework privado) segue para depois: desde o macOS 15.4 o acesso direto está bloqueado; estudar o `mediaremote-adapter`. Tratar como frágil, sempre atrás de feature flag.

## Fora de escopo na v1
- Notificações de outros apps (não existe API pública).
- Responder mensagens pelo notch.
- Suporte Intel.

## Permissões
- Automação (Apple Events) para Spotify/Music: `NSAppleEventsUsageDescription` no Info.plist.
- Pedir permissões só quando o módulo é ativado, com explicação no onboarding.
- Sem sandbox (App Store não é alvo), Hardened Runtime opcional.

## Distribuição (custo zero)
- GitHub Actions: build Release arm64 -> `.dmg`/`.zip` -> GitHub Release.
- Sparkle com chave EdDSA própria; appcast no GitHub Pages.
- Tap Homebrew próprio (`brew tap <user>/tap`), cask com `postflight` removendo quarantine.
- README explica: app não notarizado, abrir via Ajustes > Privacidade e Segurança > "Abrir mesmo assim" ou `xattr -cr /Applications/<App>.app`.

## Licença
- A definir: MIT (adoção) ou GPL-3.0 (impede fork fechado). Se copiar código do boring.notch, respeitar a licença dele.

## Convenções
- Código e commits em inglês; docs em PT ok.
- Sem force unwrap fora de inicialização óbvia.
- Toda API privada isolada num único arquivo por feature, com fallback.
- Testar em: notch MBP 14", Air 13", monitor externo, troca de Spaces, app em tela cheia.
- Lógica pura ganha teste em `Tests/CoveTests` (o CI roda `swift build` e `swift test`).

## Referências
- boring.notch (open-source, SwiftUI): ver como resolve janela/notch/mídia.
- DynamicNotchKit: implementação da janela.
- Sparkle docs: sparkle-project.org