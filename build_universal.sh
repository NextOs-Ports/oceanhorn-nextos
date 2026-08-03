#!/usr/bin/env bash
# Build universal AArch64 do Oceanhorn: Chronos Dungeon (GLIBC <= 2.30).
#
# O teto baixo de glibc é intencional nesta variante pública multi-firmware.
# A imagem Debian Buster fornece glibc 2.28; headers SDL/EGL/GLES, que não
# definem a ABI libc do executável, vêm do sysroot NextOS montado somente para
# leitura. SDL2 e os drivers gráficos são fornecidos pelo firmware do aparelho.
#
# O build NextOS Elite corrente (glibc 2.43) continua em ./build.sh e é um
# artefato SEPARADO: ele não entra no pacote universal.
#
# Uso no host:
#   ./build_universal.sh
#
# Uso manual dentro do container:
#   OCEAN_BUSTER_IN_CONTAINER=1 ./build_universal.sh
set -euo pipefail

PORT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUTPUT=${OCEAN_UNIVERSAL_OUTPUT:-oceanhorn-universal}
DIAGNOSTICS=${OCEAN_UNIVERSAL_DIAGNOSTICS:-0}

if [ "${OCEAN_BUSTER_IN_CONTAINER:-0}" != "1" ]; then
  NEXTOS_ROOT=${NEXTOS_ROOT:-"$HOME/NextOS-Elite-Edition"}
  NEXTOS_TOOLCHAIN=$(
    find -H "$NEXTOS_ROOT" -maxdepth 2 -type d \
      -path '*/build.NextOS-Retro-Elite-Edition-Amlogic-old.aarch64-*/toolchain' \
      -print | sort -V | tail -1
  )
  [ -n "$NEXTOS_TOOLCHAIN" ] ||
    { echo "toolchain NextOS atual não encontrado em $NEXTOS_ROOT" >&2; exit 1; }
  NEXTOS_SYSROOT=$NEXTOS_TOOLCHAIN/aarch64-libreelec-linux-gnu/sysroot
  [ -d "$NEXTOS_SYSROOT" ] ||
    { echo "sysroot NextOS não encontrado: $NEXTOS_SYSROOT" >&2; exit 1; }
  command -v docker >/dev/null 2>&1 ||
    { echo "docker é necessário para a build GLIBC <= 2.30" >&2; exit 1; }

  exec docker run --rm \
    -e OCEAN_BUSTER_IN_CONTAINER=1 \
    -e OCEAN_UNIVERSAL_OUTPUT="$OUTPUT" \
    -e OCEAN_UNIVERSAL_DIAGNOSTICS="$DIAGNOSTICS" \
    -v "$PORT_DIR":/repo \
    -v "$NEXTOS_SYSROOT":/nxsr:ro \
    debian:buster \
    bash /repo/build_universal.sh
fi

export DEBIAN_FRONTEND=noninteractive
if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  printf '%s\n' \
    'deb http://archive.debian.org/debian buster main' \
    'deb http://archive.debian.org/debian-security buster/updates main' \
    > /etc/apt/sources.list
  apt-get -o Acquire::Check-Valid-Until=false update -qq >/dev/null
  apt-get install -y -qq gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    file >/dev/null
fi

CC=aarch64-linux-gnu-gcc
NM=aarch64-linux-gnu-nm
READELF=aarch64-linux-gnu-readelf
cd /repo

OBJDIR=$(mktemp -d)
STUBDIR=$(mktemp -d)
trap 'rm -rf "$OBJDIR" "$STUBDIR"' EXIT

OBJS=()
DIAGNOSTIC_FLAGS=()
if [ "$DIAGNOSTICS" = "1" ]; then
  DIAGNOSTIC_FLAGS=(-DOCEAN_DEV_DIAGNOSTICS=1)
fi
for source in src/*.c; do
  object="$OBJDIR/$(basename "${source%.c}").o"
  "$CC" -D_GNU_SOURCE -I src -idirafter /nxsr/usr/include \
    "${DIAGNOSTIC_FLAGS[@]}" \
    -O2 -fPIC -fno-omit-frame-pointer \
    -Wno-unused-parameter -Wno-unused-function \
    -c "$source" -o "$object"
  OBJS+=("$object")
done

# SDL2 é fornecido pelo firmware no aparelho. O stub serve apenas para gravar o
# SONAME correto sem vincular a build à glibc 2.43 da SDL do sysroot NextOS.
UNDEFINED=$("$NM" --undefined-only "${OBJS[@]}" 2>/dev/null |
  awk '{print $NF}' | sort -u)
for symbol in $(printf '%s\n' "$UNDEFINED" | grep -E '^SDL_' || true); do
  printf 'void %s(void) {}\n' "$symbol"
done > "$STUBDIR/sdl.c"
"$CC" -shared -fPIC -nostdlib \
  -Wl,-soname,libSDL2-2.0.so.0 \
  "$STUBDIR/sdl.c" -o "$STUBDIR/libSDL2.so"

"$CC" -fPIE -pie -rdynamic -o "$OUTPUT" "${OBJS[@]}" \
  -L"$STUBDIR" -lSDL2 -ldl -lm -lpthread -lgcc_s \
  -Wl,-rpath,'$ORIGIN'

MAX_GLIBC=$(
  "$READELF" --version-info "$OUTPUT" |
    grep -oE 'GLIBC_[0-9]+([.][0-9]+)*' |
    sort -Vu | tail -1
)
[ -n "$MAX_GLIBC" ] ||
  { echo "não foi possível determinar a versão GLIBC de $OUTPUT" >&2; exit 1; }

version_number=${MAX_GLIBC#GLIBC_}
first=${version_number%%.*}
rest=${version_number#*.}
second=${rest%%.*}
if [ "$first" -gt 2 ] || { [ "$first" -eq 2 ] && [ "$second" -gt 30 ]; }; then
  echo "FALHA: $OUTPUT exige $MAX_GLIBC (limite GLIBC_2.30)" >&2
  exit 1
fi

# O canary bionic (tpidr_el0+0x28) exige que g_bionic_guard_pad continue sendo o
# PRIMEIRO bloco TLS do executável, com 256 bytes. Se o layout mudar, o guard cai
# no TLS de outra lib e volta o __stack_chk_fail intermitente.
TLS_FILESZ=$(
  "$READELF" -lW "$OUTPUT" |
    awk '$1 == "TLS" { value = $5 } END { print value }'
)
PAD_LAYOUT=$(
  "$READELF" -sW "$OUTPUT" |
    awk '$4 == "TLS" && $8 == "g_bionic_guard_pad" {
      value = $2 ":" $3
    } END { print value }'
)
[ "$PAD_LAYOUT" = "0000000000000000:256" ] ||
  { echo "FALHA: layout TLS do guard pad mudou ($PAD_LAYOUT)" >&2; exit 1; }
[ "$TLS_FILESZ" = "0x000100" ] ||
  { echo "FALHA: template TLS inesperado ($TLS_FILESZ)" >&2; exit 1; }

echo "UNIVERSAL AARCH64 BUILD OK -> $OUTPUT"
echo "glibc máxima: $MAX_GLIBC (limite: GLIBC_2.30)"
echo "TLS guard pad: offset/tamanho=$PAD_LAYOUT, template=$TLS_FILESZ"
file "$OUTPUT"
sha256sum "$OUTPUT"
