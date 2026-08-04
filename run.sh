#!/bin/sh
# Oceanhorn Chronos Dungeon (Unity 2022.3.61f1 IL2CPP) — launcher universal.
# O binário negocia fbdev/Mali, KMSDRM, Wayland e GLES em runtime.
# O PortMaster é OPCIONAL e é carregado antes de `set -u`: versões reais do
# control.txt consultam variáveis que ainda não existem.
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
for _cf in /opt/system/Tools/PortMaster /opt/tools/PortMaster \
           "$XDG_DATA_HOME/PortMaster" /roms/ports/PortMaster \
           /storage/.config/PortMaster; do
  [ -d "$_cf" ] && { controlfolder=$_cf; break; }
done
if [ -n "${controlfolder:-}" ] && [ -f "$controlfolder/control.txt" ]; then
  . "$controlfolder/control.txt"
  case "${CFW_NAME:-}" in
    ''|*[!A-Za-z0-9._-]*) ;;
    *) [ -f "$controlfolder/mod_${CFW_NAME}.txt" ] &&
         . "$controlfolder/mod_${CFW_NAME}.txt" ;;
  esac
  command -v get_controls >/dev/null 2>&1 && get_controls
fi
: "${ESUDO:=}"
: "${CUR_TTY:=/dev/tty0}"

set -u
# `directory` vem do PortMaster quando o CFW usa outra raiz de ROMs.
if [ -n "${OCEAN_GAMEDIR:-}" ]; then
  GAMEDIR=$OCEAN_GAMEDIR
elif [ -n "${directory:-}" ]; then
  GAMEDIR="/${directory#/}/ports/oceanhorn"
else
  GAMEDIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)
fi
export OCEAN_GAMEDIR=$GAMEDIR
cd "$GAMEDIR" || { echo "sem $GAMEDIR"; exit 1; }

# Ajustes do usuário/testador ficam em userdata/, que a atualização do port
# nunca sobrescreve. Serve para experimentar um knob (ver README) sem editar
# nenhum arquivo distribuído. Só exporta o que o próprio arquivo definir.
if [ -r "$GAMEDIR/userdata/ocean-env.sh" ]; then
  # shellcheck disable=SC1091
  . "$GAMEDIR/userdata/ocean-env.sh"
  echo "[run] userdata/ocean-env.sh aplicado"
fi

# A trava acompanha o processo pelo descritor 9 (inclusive após exec). Um segundo
# launcher aborta antes de tocar na instância que já possui Mali/KMS/fbdev.
exec 9>"$GAMEDIR/.oceanhorn.lock"
flock -n 9 || { echo "ABORTO: outro launcher do Oceanhorn já está ativo"; exit 1; }

# TODO o ciclo fica registrado em launcher.log (rotacionado). Sem isso, um port
# lançado pelo menu falha em silêncio absoluto — lição da v1.0.0.
[ -s "$GAMEDIR/launcher.log" ] &&
  mv -f -- "$GAMEDIR/launcher.log" "$GAMEDIR/launcher.prev.log" 2>/dev/null
exec > "$GAMEDIR/launcher.log" 2>&1
echo "=== Oceanhorn Chronos Dungeon | $(date -Is 2>/dev/null || date) ==="

# Erro fatal: registra no log E mostra na tela do aparelho (CUR_TTY), porque o
# usuário não tem terminal — sem isso todo erro vira "tela preta".
launcher_error() {
  echo "ERRO: $*"
  {
    printf '\033[2J\033[H\n\n  OCEANHORN CHRONOS DUNGEON\n\n  %s\n\n' "$*"
    printf '  Detalhes em ports/oceanhorn/launcher.log\n'
  } > "$CUR_TTY" 2>/dev/null || true
  sleep 6
  exit 1
}

# Nunca lançar sobre instância viva. Confere executable, cwd/comm e também o
# executable marcado "(deleted)" após uma eventual substituição de arquivo.
hc_pids() {
  for p in /proc/[0-9]*; do
    e=$(readlink "$p/exe" 2>/dev/null || true)
    case "$e" in
      "$GAMEDIR/oceanhorn"*) echo "${p##*/}"; continue ;;
    esac
    c=$(cat "$p/comm" 2>/dev/null || true)
    a=$({ tr '\0' ' ' < "$p/cmdline"; } 2>/dev/null || true)
    d=
    case "$c:$a" in
      UnityMain:*|oceanhorn*:*|*:"./oceanhorn"*|*:"$GAMEDIR/oceanhorn"*)
        d=$(readlink "$p/cwd" 2>/dev/null || true)
        ;;
    esac
    case "$d:$c" in
      "$GAMEDIR:UnityMain"|"$GAMEDIR:oceanhorn"*)
        echo "${p##*/}"; continue ;;
    esac
    case "$d:$a" in
      "$GAMEDIR:./oceanhorn"*|"$GAMEDIR:$GAMEDIR/oceanhorn"*)
        echo "${p##*/}" ;;
    esac
  done
}
old_pids=$(hc_pids)
if [ -n "$old_pids" ]; then
  for pid in $old_pids; do
    echo "[run] encerrando instância anterior pid=$pid"
    kill "$pid" 2>/dev/null || true
  done
  i=0
  while [ "$i" -lt 20 ]; do
    alive=
    for pid in $old_pids; do [ -d "/proc/$pid" ] && alive="$alive $pid"; done
    [ -z "$alive" ] && break
    sleep 0.5
    i=$((i+1))
  done
  for pid in $alive; do
    echo "[run] forçando encerramento da instância anterior pid=$pid"
    kill -9 "$pid" 2>/dev/null || true
  done
  remaining=$(hc_pids)
  [ -z "$remaining" ] ||
    { echo "ABORTO: instância viva ($remaining)"; exit 1; }
fi

# ---- NXExtract: dados BYO validados/instalados de forma transacional ----
# A UI usa SDL/EGL/GLES do firmware (nxextract-runtime-env.sh cuida do escopo);
# o arquivo legal do usuário nunca é apagado; dados antigos válidos são adotados.
${ESUDO:-} chmod +x "$GAMEDIR/run-extractor.sh" "$GAMEDIR/nxextract-runtime-env.sh"   "$GAMEDIR/nxextract.py" "$GAMEDIR/nxextract-ui" 2>/dev/null || true
if [ -f "$GAMEDIR/extractor.json" ] && [ -x "$GAMEDIR/run-extractor.sh" ]; then
  command -v python3 >/dev/null 2>&1 ||
    launcher_error "Este firmware não tem python3; o instalador de dados não pode rodar."
  # Instalação legada (fase 1) tinha as libs no root do port. Normaliza para o
  # layout lib/ ANTES do extrator, para a adoção validar por hash em vez de
  # pedir o APK de novo a quem já tem tudo instalado.
  if [ ! -d "$GAMEDIR/lib" ] && [ -f "$GAMEDIR/libunity.so" ] &&
     [ -d "$GAMEDIR/bin/Data" ]; then
    mkdir -p "$GAMEDIR/lib"
    for _so in libmain libunity libil2cpp; do
      [ -f "$GAMEDIR/$_so.so" ] && cp -f "$GAMEDIR/$_so.so" "$GAMEDIR/lib/$_so.so"
    done
    echo "[run] instalação legada normalizada para lib/ (adoção)"
  fi
  nx_firmware_libraries=
  if [ -n "${controlfolder:-}" ]; then
    for _d in "$controlfolder/libs" "$controlfolder/libs.aarch64"; do
      [ -d "$_d" ] &&
        nx_firmware_libraries=${nx_firmware_libraries:+$nx_firmware_libraries:}$_d
    done
  fi
  NXEXTRACT_GAME_DIR=$GAMEDIR   NXEXTRACT_FIRMWARE_LIBRARY_PATH=$nx_firmware_libraries     "$GAMEDIR/run-extractor.sh" ||
    launcher_error "Dados do jogo ausentes ou inválidos. Coloque seu APK do Oceanhorn (4.0b54, arm64) em ports/oceanhorn/gamedata/ e abra de novo."
  # so_load abre "libunity.so" relativo ao GAMEDIR; o payload instalado fica em
  # lib/. Materializa cópias no root (symlink não existe em FAT — errno 524).
  for _so in libmain libunity libil2cpp; do
    if [ -f "$GAMEDIR/lib/$_so.so" ] &&
       ! cmp -s "$GAMEDIR/lib/$_so.so" "$GAMEDIR/$_so.so" 2>/dev/null; then
      cp -f "$GAMEDIR/lib/$_so.so" "$GAMEDIR/$_so.so"
    fi
  done
  if [ "${OCEAN_EXTRACTOR_ONLY:-0}" = 1 ]; then
    echo "[run] validação do extrator concluída"
    exit 0
  fi
fi

# As libs do FIRMWARE (SDL2/EGL/GLES) vêm primeiro; as privadas do jogo ficam no
# fim do escopo para nunca sequestrar o driver do aparelho.
_libs="/usr/local/lib/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu:/usr/lib:/lib"
if [ -n "${controlfolder:-}" ]; then
  for _l in "$controlfolder/libs" "$controlfolder/libs.aarch64"; do
    [ -d "$_l" ] && _libs="$_libs:$_l"
  done
fi
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$_libs:$GAMEDIR
else
  export LD_LIBRARY_PATH=$_libs:$GAMEDIR
fi
export SDL_VIDEO_FULLSCREEN_DESKTOP=1
export SDL_GAMECONTROLLER_USE_BUTTON_LABELS=0
[ -n "${sdl_controllerconfig:-}" ] &&
  export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
if [ -z "${SDL_GAMECONTROLLERCONFIG_FILE:-}" ] && [ -n "${controlfolder:-}" ]; then
  for _db in "$controlfolder/gamecontrollerdb.txt"              "$controlfolder/gamecontrollerdb-SDL2.txt"; do
    [ -r "$_db" ] && [ ! -L "$_db" ] &&
      { export SDL_GAMECONTROLLERCONFIG_FILE=$_db; break; }
  done
fi
${ESUDO:-} chmod 666 "$CUR_TTY" /dev/uinput 2>/dev/null || true
# Unity/FMOD create many short-lived worker threads. Two malloc arenas avoid
# retaining one fragmented glibc heap per thread on the 1 GB Mali-450 target.
export MALLOC_ARENA_MAX=${MALLOC_ARENA_MAX:-2}
_mem_kib=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)
case "${_mem_kib:-}" in ''|*[!0-9]*) _mem_kib=0 ;; esac
if [ "$_mem_kib" -gt 0 ] && [ "$_mem_kib" -lt 1250000 ]; then
  export MALLOC_TRIM_THRESHOLD_=${MALLOC_TRIM_THRESHOLD_:-131072}
  export MALLOC_MMAP_THRESHOLD_=${MALLOC_MMAP_THRESHOLD_:-65536}
fi
# UnityPlayer is driven by Android Choreographer at 30 Hz in this title. Keep
# that native cadence on every backend unless an explicit engineering override
# is supplied; an unlimited host loop wastes CPU/GPU and inflates driver queues.
export OCEAN_FRAME_LIMIT=${OCEAN_FRAME_LIMIT:-30}

# Resolução real, sem assumir o painel do NextOS. O EGL usa o drawable como
# autoridade final; estas variáveis alimentam o JNI antes da janela existir.
_m=
[ -r /sys/class/graphics/fb0/mode ]  && read -r _m < /sys/class/graphics/fb0/mode  || true
[ -z "$_m" ] && [ -r /sys/class/graphics/fb0/modes ] && read -r _m < /sys/class/graphics/fb0/modes || true
if [ -n "$_m" ]; then
  _p=${_m#*:}; _p=${_p%%[!0-9x]*}; _w=${_p%x*}; _h=${_p#*x}
  case "$_w" in ''|*[!0-9]*) _w= ;; esac
  case "$_h" in ''|*[!0-9]*) _h= ;; esac
fi
if [ -z "${_w:-}" ] || [ -z "${_h:-}" ]; then
  for _status in /sys/class/drm/card*-*/status; do
    [ -r "$_status" ] || continue
    read -r _connected < "$_status" || true
    [ "$_connected" = connected ] || continue
    _modes=${_status%/status}/modes
    [ -r "$_modes" ] || continue
    read -r _mode < "$_modes" || true
    _w=${_mode%x*}; _h=${_mode#*x}
    case "$_w" in ''|*[!0-9]*) _w= ;; esac
    case "$_h" in ''|*[!0-9]*) _h= ;; esac
    [ -n "${_w:-}" ] && [ -n "${_h:-}" ] && break
  done
fi
if { [ -z "${_w:-}" ] || [ -z "${_h:-}" ]; } && [ -r /sys/class/graphics/fb0/virtual_size ]; then
  IFS=, read -r _w _vh < /sys/class/graphics/fb0/virtual_size || true
  case "${_w:-}" in ''|*[!0-9]*) _w= ;; esac
  case "${_vh:-}" in ''|*[!0-9]*) _vh= ;; esac
  if [ -n "${_w:-}" ] && [ -n "${_vh:-}" ]; then
    _h=$_vh
    # 1280x1440 e 640x960 são double-buffer; 640x480 não é.
    if [ "$_vh" -gt "$_w" ] && [ $((_vh % 2)) -eq 0 ]; then
      _half=$((_vh / 2))
      if [ "$_half" -le "$_w" ] && [ $((_half * 2)) -ge "$_w" ]; then
        _h=$_half
      fi
    fi
  fi
fi
[ -n "${_w:-}" ] && [ -n "${_h:-}" ] && export TER_SCREEN_W="$_w" TER_SCREEN_H="$_h"
echo "[run] fb real = ${TER_SCREEN_W:-?}x${TER_SCREEN_H:-?}"

# log em arquivo pelo SHELL (o dup2 interno trava a init — lição do terraria)
export TER_NOSTORAGEPATCH=1   # 🚫 patch de offset do Terraria NUNCA nesta libunity
export CUP_NOLOGFILE=1
export CUP_FRAMES=${CUP_FRAMES:-0}
# Em aparelho KMS com menos de ~1,25 GB físicos (perfil R36S de 1 GB), atlases
# crus/Alpha8 usam teto 512. O Mali-450 de pouca RAM mantém o perfil validado
# 768. KMS com >=1,7 GB deixa texturas na resolução original; ASTC/ETC2 seguem
# comprimidos em qualquer perfil que a GPU suporte.
if [ -z "${CUP_TEXHALF:-}" ]; then
  _mem_kb=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)
  case "${_mem_kb:-}" in ''|*[!0-9]*) _mem_kb=0 ;; esac
  _has_drm=0
  for _card in /dev/dri/card[0-9]*; do
    [ -e "$_card" ] && { _has_drm=1; break; }
  done
  _swap_kb=$(awk '/^SwapTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || echo 0)
  case "${_swap_kb:-}" in ''|*[!0-9]*) _swap_kb=0 ;; esac
  if [ "$_has_drm" -eq 1 ] && [ "$_mem_kb" -gt 0 ] &&
     [ "$_mem_kb" -lt 1250000 ]; then
    # Teto 512 sempre: o TEX16 (RGBA4444) já corta a RAM pela metade com
    # nitidez maior que um teto 384 em 8888 — o "borrado" do campo era o 384.
    CUP_TEXHALF=512
  elif [ "$_has_drm" -eq 1 ] && [ "$_mem_kb" -ge 1700000 ]; then
    unset CUP_TEXHALF
  else
    CUP_TEXHALF=768
  fi
fi
[ -n "${CUP_TEXHALF:-}" ] && export CUP_TEXHALF || unset CUP_TEXHALF
# Economia de RAM em device DRM curto: atlas RGBA8 grande sobe como RGBA4444
# (metade da RAM de textura, resolução da arte intacta). Mali-450/fbdev fica
# fora: o alvo publicado não muda.
if [ -z "${CUP_TEX16:-}" ] && [ "${_has_drm:-0}" -eq 1 ] &&
   [ "${_mem_kb:-0}" -gt 0 ] && [ "${_mem_kb:-0}" -lt 1250000 ]; then
  export CUP_TEX16=1
fi
# Horizon's GLES2 sprite variant asks for a split external-alpha sampler even
# after the unsupported ASTC atlases have been decoded to ordinary RGBA. On
# this build that sampler is a zero-filled dummy, making affected sprites
# transparent. Use the alpha already present in the decoded main texture.
# Sem DRM (caminho fbdev/Amlogic) o compositor exige alpha=1 no backbuffer. Em
# KMSDRM o mesmo ajuste não tem motivo comprovado, então não é ligado por padrão:
# correção estreita e condicionada por prova, nunca global.
if [ -z "${CUP_ALPHAFIX:-}" ]; then
  _has_drm_alpha=0
  for _card in /dev/dri/card[0-9]*; do
    [ -e "$_card" ] && { _has_drm_alpha=1; break; }
  done
  [ "$_has_drm_alpha" -eq 0 ] && CUP_ALPHAFIX=1
fi
[ -n "${CUP_ALPHAFIX:-}" ] && export CUP_ALPHAFIX || unset CUP_ALPHAFIX
# O render-scale experimental altera a composição e foi rejeitado visualmente
# neste aparelho. A produção preserva sempre o framebuffer nativo completo.
unset CUP_RENDERSCALE
# FMOD's Android streaming worker changes CREATESTREAM|NONBLOCKING sounds from
# LOADING to ERR_INTERNAL only after createSound has returned success. Convert
# that mode proactively to a synchronous resident sample on Unity's preload
# worker, preserving the exact original FSB while the OpenSL bridge feeds Pulse.
export HC_STREAM_FALLBACK=${HC_STREAM_FALLBACK:-1}

for hc_pulse_socket in /var/run/pulse/native /run/pulse/native; do
  if [ -S "$hc_pulse_socket" ]; then
    export PULSE_SERVER="unix:$hc_pulse_socket"
    break
  fi
done
# O Android/Unity enumera uma identidade única e estável; o estado físico é
# normalizado pelo bridge do Horizon para o layout Xbox/XInput.
export TER_GAMEPAD=1
# GCOFF só quando pedido de verdade (getenv("") também conta como ligado).
# ⚠️ CUP_GCOFF chamava il2cpp_gc_disable por OFFSET do Terraria -> .rodata no HC = SIGSEGV.
# Agora resolve por nome, mas segue OFF por padrão (não precisamos desligar o GC).
[ -n "${CUP_GCOFF:-}" ] && export CUP_GCOFF || unset CUP_GCOFF
# ⚠️ NÃO forçar il2cpp_gc_collect periódico: crashou a ~60s no campo (muOS,
# SEGV logo após "[GCEVERY] limpeza"). Pressão de memória usa o caminho
# ANDROID nativo: nativeLowMemory quando MemAvailable aperta (no binário).

# O scaler do Mali-450 pode desligar pixel processors e manter só 400 MHz entre
# os jobs do mesmo quadro. No Amlogic-old isto derrubou a mesma cena de 24–25
# para 14–16 FPS. Mantém todos os PPs e usa o maior nível oficial do driver
# durante o jogo. Um guarda recua um nível antes do trip "hot" do kernel; não
# altera resolução, shaders, efeitos nem texturas. Tudo é restaurado ao sair.
GPU_DIR=/sys/class/mpgpu
GPU_OLD_MIN_FREQ=
GPU_OLD_MIN_PP=
GPU_PINNED=0
GPU_TARGET_FREQ=
GPU_COOL_FREQ=
GPU_THERM_PID=
GAME_PID=
restore_gpu() {
  if [ "$GPU_PINNED" = 1 ]; then
    [ -n "$GPU_OLD_MIN_FREQ" ] &&
      echo "$GPU_OLD_MIN_FREQ" > "$GPU_DIR/min_freq" 2>/dev/null || true
    [ -n "$GPU_OLD_MIN_PP" ] &&
      echo "$GPU_OLD_MIN_PP" > "$GPU_DIR/min_pp" 2>/dev/null || true
    GPU_PINNED=0
  fi
}
stop_game() {
  signal=$1
  if [ -n "$GPU_THERM_PID" ]; then
    kill "$GPU_THERM_PID" 2>/dev/null || true
    GPU_THERM_PID=
  fi
  if [ -n "$GAME_PID" ] && kill -0 "$GAME_PID" 2>/dev/null; then
    kill -"$signal" "$GAME_PID" 2>/dev/null || true
    wait "$GAME_PID" 2>/dev/null || true
  fi
  GAME_PID=
  restore_gpu
  exit 143
}
trap restore_gpu EXIT
trap 'stop_game TERM' TERM
trap 'stop_game INT' INT
trap 'stop_game HUP' HUP
if [ "${OCEAN_GPU_PERFORMANCE:-1}" != 0 ] &&
   [ -r "$GPU_DIR/max_freq" ] && [ -r "$GPU_DIR/min_freq" ] &&
   [ -w "$GPU_DIR/min_freq" ] &&
   [ -r "$GPU_DIR/max_pp" ] && [ -r "$GPU_DIR/min_pp" ] &&
   [ -w "$GPU_DIR/min_pp" ]; then
  GPU_OLD_MIN_FREQ=$(cat "$GPU_DIR/min_freq" 2>/dev/null || true)
  GPU_OLD_MIN_PP=$(cat "$GPU_DIR/min_pp" 2>/dev/null || true)
  GPU_TARGET_FREQ=$(cat "$GPU_DIR/max_freq" 2>/dev/null || true)
  GPU_MAX_PP=$(cat "$GPU_DIR/max_pp" 2>/dev/null || true)
  case "$GPU_TARGET_FREQ" in
    ''|*[!0-9]*) GPU_TARGET_FREQ= ;;
    *) [ "$GPU_TARGET_FREQ" -gt 0 ] &&
         GPU_COOL_FREQ=$((GPU_TARGET_FREQ - 1)) ;;
  esac
  if [ -n "$GPU_OLD_MIN_FREQ" ] && [ -n "$GPU_OLD_MIN_PP" ] &&
     [ -n "$GPU_TARGET_FREQ" ] && [ -n "$GPU_MAX_PP" ]; then
    GPU_PINNED=1
    if echo "$GPU_TARGET_FREQ" > "$GPU_DIR/min_freq" 2>/dev/null &&
       echo "$GPU_MAX_PP" > "$GPU_DIR/min_pp" 2>/dev/null &&
       [ "$(cat "$GPU_DIR/min_freq" 2>/dev/null)" = "$GPU_TARGET_FREQ" ] &&
       [ "$(cat "$GPU_DIR/min_pp" 2>/dev/null)" = "$GPU_MAX_PP" ]; then
      echo "[run] GPU desempenho: frequência nível $GPU_TARGET_FREQ, $GPU_MAX_PP PPs"
    else
      echo "[run] aviso: perfil de GPU não aplicado; restaurando valores originais"
      restore_gpu
    fi
  fi
fi

# Limpa o console visível: resto de texto do frontend/extrator não pode ficar
# por cima da primeira cena (padrão Terraria).
${ESUDO:-} chmod 666 "$CUR_TTY" 2>/dev/null || true
printf '\033c' >> "$CUR_TTY" 2>/dev/null || true

# Runtime público de baixa glibc é o padrão em qualquer firmware; o build contra
# a glibc corrente do NextOS só entra se for o único presente.
if [ -x "$GAMEDIR/oceanhorn-universal" ]; then
  GAME_BIN=$GAMEDIR/oceanhorn-universal
elif [ -x "$GAMEDIR/oceanhorn" ]; then
  GAME_BIN=$GAMEDIR/oceanhorn
else
  launcher_error "Executável do port ausente — reinstale o pacote."
fi
echo "[run] binário: ${GAME_BIN##*/} ($(sha256sum "$GAME_BIN" 2>/dev/null | cut -c1-12))"
echo "[run] video=${SDL_VIDEODRIVER:-firmware-auto} audio=${SDL_AUDIODRIVER:-firmware-auto} cfw=${CFW_NAME:-nenhum}"
if command -v pm_platform_helper >/dev/null 2>&1; then
  pm_platform_helper "$GAME_BIN" >/dev/null ||
    launcher_error "PortMaster não conseguiu preparar o frontend deste CFW."
fi
"$GAME_BIN" &
GAME_PID=$!
if [ "$GPU_PINNED" = 1 ] && [ -n "$GPU_COOL_FREQ" ] &&
   [ -r /sys/class/thermal/thermal_zone0/temp ]; then
  (
    thermal_high=${OCEAN_GPU_THERMAL_HIGH:-82000}
    thermal_low=${OCEAN_GPU_THERMAL_LOW:-76000}
    case "$thermal_high:$thermal_low" in
      *[!0-9:]*) thermal_high=82000; thermal_low=76000 ;;
    esac
    if [ "$thermal_high" -le "$thermal_low" ]; then
      thermal_high=82000
      thermal_low=76000
    fi
    cooled=0
    while kill -0 "$GAME_PID" 2>/dev/null; do
      temperature=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
      case "$temperature" in ''|*[!0-9]*) temperature=0 ;; esac
      if [ "$cooled" = 0 ] && [ "$temperature" -ge "$thermal_high" ]; then
        echo "$GPU_COOL_FREQ" > "$GPU_DIR/min_freq" 2>/dev/null || true
        cooled=1
        echo "[run] proteção térmica: ${temperature}mC, GPU nível $GPU_COOL_FREQ"
      elif [ "$cooled" = 1 ] && [ "$temperature" -le "$thermal_low" ]; then
        echo "$GPU_TARGET_FREQ" > "$GPU_DIR/min_freq" 2>/dev/null || true
        cooled=0
        echo "[run] GPU restaurada ao nível $GPU_TARGET_FREQ (${temperature}mC)"
      fi
      sleep 5
    done
  ) &
  GPU_THERM_PID=$!
fi
wait "$GAME_PID"
STATUS=$?
GAME_PID=
if [ -n "$GPU_THERM_PID" ]; then
  kill "$GPU_THERM_PID" 2>/dev/null || true
  wait "$GPU_THERM_PID" 2>/dev/null || true
  GPU_THERM_PID=
fi
command -v pm_finish >/dev/null 2>&1 && pm_finish
exit "$STATUS"
