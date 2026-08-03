#!/usr/bin/env bash
# Monta os pacotes do Oceanhorn: Chronos Dungeon.
#
#   CODE   — só o nosso código (launcher, runtime de baixa glibc, docs).
#            É o que vai para o repositório e para a release. BYO-data.
#   FULL   — CODE + a árvore de dados Unity de uma instalação legal local.
#            Fica FORA do git e fora da release; serve para instalar no
#            aparelho e para o dono do jogo replicar nos próprios devices.
#
# Nenhum dado de jogo entra no pacote CODE. O script recusa montar o FULL se a
# origem dos dados não for indicada explicitamente.
set -euo pipefail

PORT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR=${OCEAN_PKG_OUT:-$PORT_DIR/package/dist}
VERSION=${OCEAN_PKG_VERSION:-1.0.0}
NAME="Oceanhorn Chronos Dungeon"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

BIN=$PORT_DIR/oceanhorn-universal
[ -x "$BIN" ] || { echo "falta $BIN — rode ./build_universal.sh antes" >&2; exit 1; }

# Gate público: o runtime distribuído nunca pode exigir mais que GLIBC_2.30.
MAXG=$(objdump -T "$BIN" | grep -oE 'GLIBC_2\.[0-9]+' | sort -uV | tail -1)
case "$MAXG" in
  GLIBC_2.1?|GLIBC_2.2?|GLIBC_2.30) ;;
  *) echo "FALHA: runtime exige $MAXG (teto GLIBC_2.30)" >&2; exit 1 ;;
esac

mkdir -p "$OUT_DIR" "$STAGE/oceanhorn/userdata" "$STAGE/oceanhorn/gamedata"
install -m 755 "$PORT_DIR/$NAME.sh"        "$STAGE/$NAME.sh"
install -m 755 "$PORT_DIR/run.sh"          "$STAGE/oceanhorn/run.sh"
install -m 755 "$BIN"                      "$STAGE/oceanhorn/oceanhorn-universal"
for doc in README.md LICENSE NOTICE.md INSTALLATION.md CHANGELOG.md; do
  [ -f "$PORT_DIR/$doc" ] && install -m 644 "$PORT_DIR/$doc" "$STAGE/oceanhorn/$doc"
done

cat > "$STAGE/oceanhorn/gamedata/LEIA-ME.txt" <<'TXT'
Este pacote NÃO contém o jogo.

Coloque aqui, a partir da sua cópia legal do APK do Oceanhorn: Chronos Dungeon
(com.FDGEntertainment.OceanhornChronosDungeon.gp, 4.0b54, arm64-v8a):

  libunity.so, libil2cpp.so, libmain.so   -> ports/oceanhorn/
  a árvore assets/bin/Data                -> ports/oceanhorn/bin/Data

Os saves ficam em ports/oceanhorn/userdata e nunca são apagados por uma
atualização do port.
TXT

# manifesto: quem auditar a release sabe o que exigimos sem ter o aparelho
{
  echo "pacote: $NAME (Universal) v$VERSION"
  echo "runtime: oceanhorn-universal  glibc_max=$MAXG  sha256=$(sha256sum "$BIN" | cut -d' ' -f1)"
  echo "launcher: run.sh + wrapper fino; PortMaster opcional"
  echo "validado fisicamente:"
  echo "  - R36S / ArkOS (RK3326, Mali-G31, KMSDRM 640x480, glibc 2.30)"
  echo "  - NextOS Elite / Amlogic-old (Mali-450, fbdev 1280x720, glibc 2.43)"
  echo "projetado por capacidade, sem prova física nesta release:"
  echo "  - demais CFWs AArch64 (muOS, ROCKNIX, Batocera, Knulli e afins)"
  echo "    o launcher detecta SDL/DRM/fb, RAM e extensões GL em runtime;"
  echo "    nenhum backend, resolução ou perfil é fixado por nome de aparelho."
} > "$STAGE/oceanhorn/MANIFEST.txt"

CODE_ZIP="$OUT_DIR/$NAME (Universal) v$VERSION.zip"
rm -f "$CODE_ZIP"
( cd "$STAGE" && zip -rq "$CODE_ZIP" . )
( cd "$OUT_DIR" && sha256sum "$(basename "$CODE_ZIP")" > "$(basename "$CODE_ZIP").sha256" )

if [ -n "${OCEAN_FULL_DATA_DIR:-}" ]; then
  [ -d "$OCEAN_FULL_DATA_DIR/bin/Data" ] ||
    { echo "OCEAN_FULL_DATA_DIR sem bin/Data" >&2; exit 1; }
  FULL=$(mktemp -d); trap 'rm -rf "$STAGE" "$FULL"' EXIT
  mkdir -p "$FULL/ports"
  cp -a "$STAGE/oceanhorn" "$FULL/ports/oceanhorn"
  cp -a "$STAGE/$NAME.sh" "$FULL/ports/$NAME.sh"
  cp -a "$OCEAN_FULL_DATA_DIR/bin" "$FULL/ports/oceanhorn/bin"
  for lib in libunity.so libil2cpp.so libmain.so; do
    [ -f "$OCEAN_FULL_DATA_DIR/$lib" ] && cp -a "$OCEAN_FULL_DATA_DIR/$lib" "$FULL/ports/oceanhorn/$lib"
  done
  rm -rf "$FULL/ports/oceanhorn/gamedata"
  FULL_TGZ="$OUT_DIR/$NAME (Universal, full data) v$VERSION.tar.gz"
  rm -f "$FULL_TGZ"
  ( cd "$FULL" && tar czf "$FULL_TGZ" ports )
  ( cd "$OUT_DIR" && sha256sum "$(basename "$FULL_TGZ")" > "$(basename "$FULL_TGZ").sha256" )
  echo "FULL  -> $FULL_TGZ"
fi

echo "CODE  -> $CODE_ZIP"
echo "glibc do runtime: $MAXG"
unzip -l "$CODE_ZIP" | tail -3
