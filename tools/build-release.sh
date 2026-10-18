#!/usr/bin/env bash
#
# tools/build-release.sh — costruisce l'archivio di una release partendo dal repository.
#
# Uso:      tools/build-release.sh <versione>          (es. tools/build-release.sh 1.1)
# Produce:  dist/minibolt-update-scripts-<versione>.tar.gz
#           dist/minibolt-update-scripts-<versione>.tar.gz.sha256
#
# NON firma niente: la chiave privata sta su una smartcard, su un'altra macchina.
# La firma si fa dove sta la chiave:
#     gpg --detach-sign --armor dist/minibolt-update-scripts-<versione>.tar.gz
#
# L'archivio non e' compilato "a occhio": prima di produrlo controlla che il tree sia
# committato, che la versione sia citata nel README, e alla fine estrae l'archivio in una
# cartella temporanea e ricontrolla i checksum e la sintassi dei file estratti.

set -euo pipefail

die() { printf 'STOP: %s\n' "$*" >&2; exit 1; }

VERSION="${1:-}"
[ -n "$VERSION" ] || die "manca la versione. Uso: tools/build-release.sh <versione>   (es. 1.1)"
case "$VERSION" in
  *[!0-9.]*) die "versione non valida: '$VERSION' (atteso un numero tipo 1.1)" ;;
esac

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$REPO"

SCRIPTS=(mb-update.sh mb-update-bitcoin-core.sh mb-update-electrs.sh
         mb-update-btc-rpc-explorer.sh mb-update-buildtools.sh)
EXTRA=(README.md LICENSE SECURITY.md CHANGELOG.md)

echo "== Build minibolt-update-scripts ${VERSION} =="

# 1) il tree deve essere pulito: l'archivio deve corrispondere a un commit preciso
if [ -n "$(git status --porcelain)" ]; then
  git status --short
  die "ci sono modifiche non committate: committa (o metti via) prima di costruire la release"
fi
COMMIT="$(git rev-parse HEAD)"
echo "    commit: ${COMMIT}"

# 2) la versione deve comparire nel README (i comandi di download la citano)
grep -q "minibolt-update-scripts-${VERSION}.tar.gz" README.md \
  || die "README.md non cita la versione ${VERSION}: aggiorna i comandi di download e riprova"
grep -q "^## ${VERSION} " CHANGELOG.md \
  || echo "    ATTENZIONE: CHANGELOG.md non ha una sezione '## ${VERSION}'"

# 3) i file ci sono e la sintassi e' valida
for f in "${SCRIPTS[@]}" "${EXTRA[@]}" keys/stibax-minibolt.asc; do
  [ -f "$f" ] || die "file mancante: $f"
done
for f in "${SCRIPTS[@]}"; do bash -n "$f" || die "sintassi non valida: $f"; done
echo "    sintassi OK sui ${#SCRIPTS[@]} script"

# 4) staging: dentro l'archivio la cartella si chiama minibolt-update/
STAGE="dist/minibolt-update"
rm -rf dist
mkdir -p "$STAGE/keys"
cp "${SCRIPTS[@]}" "${EXTRA[@]}" "$STAGE/"
cp keys/stibax-minibolt.asc "$STAGE/keys/"
chmod +x "$STAGE"/*.sh

# 5) manifest interno (il nome dei file e' relativo alla radice dell'archivio)
( cd "$STAGE" && find . -type f ! -name SHA256SUMS.txt -printf '%P\n' \
    | LC_ALL=C sort | xargs sha256sum > SHA256SUMS.txt )
echo "    manifest: $(wc -l < "$STAGE/SHA256SUMS.txt") file verificabili"

# 6) archivio, riproducibile: stesso contenuto -> stessi byte (nessun timestamp/uid/orario)
TARNAME="minibolt-update-scripts-${VERSION}.tar.gz"
tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -czf "dist/${TARNAME}" -C dist minibolt-update
( cd dist && sha256sum "${TARNAME}" > "${TARNAME}.sha256" )

# 7) verifica end-to-end: estrai in una cartella temporanea e ricontrolla tutto
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tar xzf "dist/${TARNAME}" -C "$TMP"
( cd "${TMP}/minibolt-update" && sha256sum -c --quiet SHA256SUMS.txt ) \
  || die "i checksum dei file ESTRATTI non corrispondono al manifest"
for f in "${SCRIPTS[@]}"; do bash -n "${TMP}/minibolt-update/${f}" || die "sintassi non valida dopo l'estrazione: $f"; done
echo "    estratto e riverificato: checksum OK, sintassi OK"

echo
echo "== Fatto =="
ls -l "dist/${TARNAME}" "dist/${TARNAME}.sha256"
sed -n '1p' "dist/${TARNAME}.sha256"
echo
echo "Prossimi passi (sulla macchina dove sta la chiave privata):"
echo "  1) gpg --detach-sign --armor dist/${TARNAME}"
echo "  2) carica come asset della release:"
echo "       dist/${TARNAME}"
echo "       dist/${TARNAME}.sha256"
echo "       dist/${TARNAME}.asc"
echo "       keys/stibax-minibolt.asc"
echo "  3) tag firmato sullo stesso commit:"
echo "       git tag -s v${VERSION} -m \"minibolt-update-scripts ${VERSION}\" ${COMMIT}"
