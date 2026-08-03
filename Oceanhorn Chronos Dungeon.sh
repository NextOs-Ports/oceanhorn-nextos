#!/bin/bash
# Entrada visível universal do Oceanhorn: Chronos Dungeon.
# Toda a lógica mora em ports/oceanhorn/run.sh — este arquivo só a encontra.
# Se NADA for encontrado, ainda assim deixa um log ao lado de si mesmo e uma
# mensagem na tela: wrapper mudo foi exatamente o relato do muOS na v1.0.1.

PORT_ID="oceanhorn"
PORT_TITLE="Oceanhorn Chronos Dungeon"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || SCRIPT_DIR=.

CAND_LIST="
$SCRIPT_DIR/$PORT_ID/run.sh
$SCRIPT_DIR/../ports/$PORT_ID/run.sh
/roms/ports/$PORT_ID/run.sh
/roms2/ports/$PORT_ID/run.sh
/storage/roms/ports/$PORT_ID/run.sh
/mnt/mmc/ports/$PORT_ID/run.sh
/mnt/mmc/ROMS/ports/$PORT_ID/run.sh
/mnt/sdcard/ports/$PORT_ID/run.sh
/userdata/roms/ports/$PORT_ID/run.sh
"

for launcher in $CAND_LIST; do
  if [ -f "$launcher" ] && [ ! -L "$launcher" ]; then
    exec bash "$launcher" "$@"
  fi
done

# Nada encontrado: registrar ONDE procurou, ao lado do próprio wrapper.
WLOG="$SCRIPT_DIR/oceanhorn-wrapper.log"
{
  echo "=== $PORT_TITLE wrapper | $(date 2>/dev/null) ==="
  echo "run.sh não encontrado. Caminhos testados:"
  printf '%s\n' $CAND_LIST
  echo "Conteúdo de $SCRIPT_DIR:"
  ls "$SCRIPT_DIR" 2>/dev/null
} > "$WLOG" 2>/dev/null

MSG="$PORT_TITLE: pasta ports/$PORT_ID/ não encontrada. Veja oceanhorn-wrapper.log"
printf '%s\n' "$MSG" >&2
for tty in /dev/tty0 /dev/tty1 /dev/console; do
  printf '\033[2J\033[H\n\n  %s\n' "$MSG" > "$tty" 2>/dev/null && break
done
sleep 6
exit 1
