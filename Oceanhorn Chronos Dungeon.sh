#!/bin/bash
# Entrada visível universal do Oceanhorn: Chronos Dungeon.
# Toda a lógica (PortMaster, lock, perfis, runtime, ciclo de vida) mora em
# ports/oceanhorn/run.sh — este arquivo só encontra a implementação e sai do caminho.

PORT_ID="oceanhorn"
PORT_TITLE="Oceanhorn Chronos Dungeon"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || exit 1

for launcher in \
  "$SCRIPT_DIR/$PORT_ID/run.sh" \
  "$SCRIPT_DIR/../ports/$PORT_ID/run.sh" \
  "/roms/ports/$PORT_ID/run.sh" \
  "/roms2/ports/$PORT_ID/run.sh" \
  "/storage/roms/ports/$PORT_ID/run.sh"
do
  if [ -f "$launcher" ] && [ ! -L "$launcher" ]; then
    exec bash "$launcher" "$@"
  fi
done

printf '%s: ports/%s/run.sh não encontrado\n' "$PORT_TITLE" "$PORT_ID" >&2
exit 1
