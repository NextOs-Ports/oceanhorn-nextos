# Changelog — Oceanhorn: Chronos Dungeon (NextOS Ports)

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
