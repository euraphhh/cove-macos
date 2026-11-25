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
  NotchApp.swift            # @main, LSUIElement (sem Dock), AppDelegate
  Window/
    NotchPanel.swift        # NSPanel borderless, nonactivating, nível acima da menu bar
    NotchGeometry.swift     # detecta notch via NSScreen.safeAreaInsets / auxiliaryTopLeft/RightArea
    HoverTracker.swift      # tracking area sobre o notch -> estados
  State/
    NotchViewModel.swift    # estados: closed / peek / expanded; @Observable
  Modules/                  # cada feature é um módulo isolado com protocolo comum
    NotchModule.swift       # protocol: id, compactView, expandedView, isAvailable
    Media/                  # agora tocando
    Shelf/                  # bandeja de arquivos (drag & drop)
    System/                 # bateria, volume, brilho (HUD)
  Settings/                 # SettingsView + UserDefaults/@AppStorage
  Support/                  # extensões, logging (os.Logger)
```

Regras:
- Janela: `NSPanel` com `.borderless`, `.nonactivatingPanel`, `level = .mainMenu + 1` (ou `.statusBar`), `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`, fundo transparente, `hasShadow = false`.
- Reposicionar ao mudar telas (`NSApplication.didChangeScreenParametersNotification`).
- O panel fica sempre do tamanho do estado expandido; o conteúdo anima por dentro. Cliques fora da forma visível precisam passar para trás (`ignoresMouseEvents` dinâmico conforme hover).
- Animações SwiftUI com `.spring`; forma do notch = shape customizada com cantos inferiores arredondados.
- Módulos não conhecem a janela; só expõem views e estado.

## MVP (ordem)
1. Panel no notch, preto, encaixado no notch físico, com hover -> expande / sai -> fecha.
2. Módulo Media via **AppleScript** (Spotify e Music): título, artista, artwork, play/pause/next.
   - MediaRemote (framework privado) fica para depois. Desde o macOS 15.4 o acesso direto está bloqueado; estudar o `mediaremote-adapter`. Tratar como frágil, sempre atrás de feature flag.
3. Módulo Shelf: arrastar arquivo até o notch -> guarda temporariamente -> arrastar de volta para fora.
4. Módulo System: HUD de volume/brilho/bateria.
5. Settings + launch at login (`SMAppService.mainApp`).

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

## Referências
- boring.notch (open-source, SwiftUI): ver como resolve janela/notch/mídia.
- DynamicNotchKit: implementação da janela.
- Sparkle docs: sparkle-project.org