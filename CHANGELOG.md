# Changelog — Oceanhorn: Chronos Dungeon (NextOS Ports)

## v1.0.2 (Universal) — 03/08/2026

Correções guiadas pelos primeiros logs de campo (obrigado, testadores!).

### Corrigido
- **ROCKNIX/Panfrost (RG-DS): abortava com "[EGL] Unable to find a configuration
  matching minimum spec"** — dois defeitos combinados:
  - PulseAudio herdado morto derrubava o `SDL_Init(VIDEO|AUDIO)` inteiro; vídeo
    e áudio agora inicializam separados, com retry sem o driver herdado (o
    mesmo fix validado no TASM2 v1.1.7 e no Horizon Chase v1.0.3).
  - O Mesa devolvia RGBX8888 e este Unity exige RGBA8888 exato; adotado o
    contrato de EGLConfig do Horizon Chase v1.0.3 (seleção e relato do config
    real RGBA de 8 bits por canal).
- **dArkOSRE (R36S): jogo encerrado do nada em gameplay (`Killed`)** — era o
  OOM killer num firmware sem swap. Resolvido por ECONOMIA, sem tocar no
  sistema do usuário: teto de textura mais agressivo (384) quando o firmware
  não oferece swap nenhum, e GC periódico do IL2CPP (`CUP_GCEVERY=900`) em
  aparelhos de ~1 GB para conter o heap gerenciado. Nenhum swap é criado.
- **muOS (RG 40XX-H): wrapper falhava sem deixar rastro** — o wrapper agora
  registra `oceanhorn-wrapper.log` ao lado de si mesmo com os caminhos
  testados, mostra o erro na tela, e conhece as raízes de ROMs do muOS
  (`/mnt/mmc`, `/mnt/sdcard`) e do Batocera (`/userdata`).
- Varredura de instâncias não polui mais o log com corridas de `/proc`.

## v1.0.1 (Universal) — 03/08/2026

Correção crítica de campo: a v1.0.0 falhava em silêncio absoluto fora dos
aparelhos de desenvolvimento — sem nenhum log e sem nenhuma mensagem na tela.

### Corrigido
- **Logs**: todo o ciclo (extrator, launcher e jogo) agora é gravado sozinho em
  `ports/oceanhorn/launcher.log` (rotacionado em `launcher.prev.log`). A v1.0.0
  não redirecionava nada quando lançada pelo menu.
- **Erros visíveis**: falha fatal agora aparece na tela do aparelho (`CUR_TTY`)
  com instrução do que fazer, em vez de voltar ao menu como "tela preta".
- **`pm_platform_helper`**: o helper do PortMaster que faz o frontend de cada
  CFW entregar o display agora é chamado antes do jogo (padrão Prizefighters 2).
  Sem ele, em vários firmwares o jogo rodava atrás de uma tela preta.
- Console visível é limpo antes da primeira cena (padrão Terraria).
- `python3` ausente vira mensagem clara em vez de falha muda.
- Ajustes de malloc para aparelhos com pouca RAM (padrão PF2).

## v1.0.0 (Universal) — 03/08/2026

Primeira versão multi-device.

### Adicionado
- Runtime público único exigindo apenas **GLIBC_2.27**, construído no Debian
  Buster, com o teto de 2.30 verificado pelo próprio build.
- Launcher universal: PortMaster opcional, wrapper visível fino, escopo de
  bibliotecas do firmware, seleção de runtime e ciclo de vida supervisionado.
- `SELECT+START` em pads sem `BTN_SELECT`/`BTN_START` físicos (RG351/R36S), com
  os ordinais calculados do bitmap do próprio pad.
- Medidor opcional de nível de áudio (`OCEAN_AUDIOLOG=N`) para auditar som sem
  depender de ouvir o aparelho.

### Alterado
- `CUP_ALPHAFIX` deixou de ser global: liga apenas no caminho fbdev, onde foi
  comprovado. Em KMSDRM o jogo desenha correto sem ele.
- Perfil de textura escolhido por RAM e capacidades reais, não por modelo.

### Validado fisicamente
- **R36S / ArkOS** (Mali-G31, KMSDRM 640×480): título, cutscene e dungeon
  jogável, áudio, controle e saída limpa. Pico de 352 MB de RSS.
- **NextOS Elite / Amlogic-old** (Mali-450, fbdev 1280×720): sem regressão, com
  o mesmo binário universal.
