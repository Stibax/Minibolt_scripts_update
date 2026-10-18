#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
#  MiniBolt - Aggiornamento Bitcoin Core con binari precompilati (Option 1)
#  Guida: https://minibolt.minibolt.info/bitcoin/bitcoin/bitcoin-core#option-1-using-precompiled-binaries
#
#  Esegue UNO PER UNO, nell'ordine esatto della guida, i comandi della sezione
#  "Upgrade" variante "Option 1: Using precompiled binaries" - come se li
#  copiassi e incollassi a mano nel terminale.
#
#  Password: nessuna password viene mai salvata su disco, in file di log, nella
#  shell history o in variabili d'ambiente. L'autenticazione e' gestita
#  esclusivamente dal prompt nativo di sudo (`sudo -v`); questo script non legge
#  e non memorizza mai la password.
# =============================================================================
set -Eeuo pipefail

C_R=$'\033[0m'; C_B=$'\033[1m'; C_C=$'\033[36m'; C_Y=$'\033[33m'
C_G=$'\033[32m'; C_E=$'\033[31m'

say()  { printf '\n%s== %s ==%s\n' "$C_B$C_C" "$*" "$C_R"; }
step() { printf '\n%s>>> %s%s\n' "$C_Y" "$*" "$C_R"; }
note() { printf '    %s\n' "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_G" "$C_R" "$*"; }
warn() { printf '%s[ATTENZIONE]%s %s\n' "$C_Y" "$C_R" "$*"; }
err()  { printf '%s[ERRORE]%s %s\n' "$C_E" "$C_R" "$*" >&2; }
die()  { err "$*"; exit 1; }
on_err() { local c=$?; if [ "$c" -ge 129 ]; then warn "Terminato da un segnale (exit $c, tipico del Ctrl-C): se l'hai fermato tu va bene cosi', altrimenti guarda l'output qui sopra. Nessuna password e' stata salvata."; else err "comando fallito (exit $c) alla riga ${BASH_LINENO[0]:-?}: se lo script prosegue l'errore era in un contesto tollerato (if/test), altrimenti si ferma qui. Nessuna password e' stata salvata."; fi; }
trap on_err ERR

ask() {  # ask "prompt" [default]
  local p=$1 d=${2-} a
  if [ -n "$d" ]; then read -r -p "$p [$d]: " a || true; printf '%s' "${a:-$d}"
  else read -r -p "$p: " a || true; printf '%s' "$a"; fi
}
confirm() {  # confirm "domanda" [S|N]
  local p=$1 d=${2:-N} a
  read -r -p "$p ($d) " a || true
  case "${a:-$d}" in [sSyY]*) return 0 ;; *) return 1 ;; esac
}
run() { printf '%s$ %s%s\n' "$C_B" "$*" "$C_R"; "$@"; }
require_cmds() {
  local missing=() c
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    err "Comandi mancanti: ${missing[*]}"
    note "Installali con:  sudo apt update && sudo apt install -y ${missing[*]}"
    exit 1
  fi
}
sudo_start() {
  [ "$(id -u)" -eq 0 ] && die "Non lanciare lo script come root: usa l'utente 'admin' (lo script usa sudo dove serve)."
  step "Autenticazione sudo (una volta sola; la password e' letta e custodita solo da sudo)"
  sudo -v || die "Autenticazione sudo non riuscita."
  # Il subshell del keepalive deve essere immune a set -e e al trap ERR (set -E li eredita):
  # altrimenti un Ctrl-C durante lo script lo farebbe sembrare un errore del padre.
  ( set +e; trap - ERR; while true; do sudo -n true 2>/dev/null || exit 0; sleep 50; kill -0 "$$" 2>/dev/null || exit 0; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "${SUDO_KEEPALIVE_PID:-0}" 2>/dev/null || true' EXIT
  ok "sudo attivo per tutta la durata dello script."
}
latest_gh_tag() {  # latest_gh_tag owner/repo  -> tag senza 'v'
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -m1 '"tag_name"' \
    | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v?([^"]+)".*/\1/' || true
}

# -----------------------------------------------------------------------------
say "MiniBolt - Aggiornamento Bitcoin Core (binari precompilati - Option 1)"
note "Guida: https://minibolt.minibolt.info/bitcoin/bitcoin/bitcoin-core#option-1-using-precompiled-binaries"
echo
note "Sequenza eseguita (identica alla guida):"
note "  1  download di binari + SHA256SUMS + SHA256SUMS.asc + SHA256SUMS.ots"
note "  2  checksum check          sha256sum --ignore-missing --check SHA256SUMS"
note "  3  import builder keys     chiavi pubbliche da bitcoin-core/guix.sigs"
note "  4  signature check         gpg --verify SHA256SUMS.asc SHA256SUMS"
note "  5  timestamp check         ots --no-cache verify SHA256SUMS.ots -f SHA256SUMS"
note "  6  extract                 tar -xzvf"
note "  7  install                 sudo install -m 0755 -o root -g root -t /usr/local/bin"
note "  8  restart                 sudo systemctl restart bitcoind"
echo
warn "Leggi prima le RELEASE NOTES della versione che stai installando:"
note "https://github.com/bitcoin/bitcoin/tree/master/doc/release-notes"
note "Un salto di versione maggiore puo' richiedere modifiche a bitcoin.conf o una reindicizzazione."
echo
confirm "Confermi di aver letto le release notes e vuoi procedere?" N || die "Annullato dall'utente."

require_cmds wget curl gpg sha256sum tar systemctl
sudo_start

# --- stato attuale -----------------------------------------------------------
CUR="$(bitcoin-cli --version 2>/dev/null | head -n1 || true)"
if [ -n "$CUR" ]; then note "Versione attualmente installata: $CUR"
else warn "bitcoin-cli non trovato in PATH: procedo come prima installazione dei binari."; fi

# --- versione da installare --------------------------------------------------
DEFVER="$(latest_gh_tag bitcoin/bitcoin)"
while :; do
  VERSION="$(ask "Versione di Bitcoin Core da installare (es. 31.1, senza la 'v')" "$DEFVER")"
  VERSION="${VERSION#v}"
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+([.][0-9]+)?$ ]] && break
  warn "Formato non valido: '$VERSION' (atteso un formato tipo 31.1). Riprova (Ctrl-C per uscire)."
done
BASE="https://bitcoincore.org/bin/bitcoin-core-$VERSION"

if curl -fsI "$BASE/SHA256SUMS" >/dev/null 2>&1; then
  ok "Versione $VERSION presente su bitcoincore.org."
else
  err "La versione $VERSION non risulta disponibile su bitcoincore.org."
  note "Ultime versioni pubblicate:"
  curl -fsSL https://bitcoincore.org/bin/ 2>/dev/null | grep -oE 'bitcoin-core-[0-9]+(\.[0-9]+)*/' | sort -uV | tail -n 12 | sed 's|^|    |' || true
  exit 1
fi

echo
say "Riepilogo operazione"
note "Componente : Bitcoin Core, binari precompilati x86_64"
note "Da         : ${CUR:-non installato}"
note "A          : $VERSION"
note "Workdir    : /tmp  (svuotata al riavvio)"
confirm "Procedo?" S || die "Annullato dall'utente."

# =============================================================================
say "Passo 1/8 - Download (guida: Download binaries)"
run cd /tmp
for f in "bitcoin-$VERSION-x86_64-linux-gnu.tar.gz" SHA256SUMS SHA256SUMS.asc SHA256SUMS.ots; do
  if [ -e "/tmp/$f" ]; then
    warn "Esiste gia' /tmp/$f (residuo di un tentativo precedente)."
    if confirm "Vuoi eliminarlo e riscaricarlo?" S; then run rm -f "/tmp/$f"
    else die "Interrotto: rimuovi a mano /tmp/$f e rilancia lo script."; fi
  fi
done
run wget "$BASE/bitcoin-$VERSION-x86_64-linux-gnu.tar.gz"
run wget "$BASE/SHA256SUMS"
run wget "$BASE/SHA256SUMS.asc"
run wget "$BASE/SHA256SUMS.ots"

# =============================================================================
say "Passo 2/8 - Checksum check (guida: Checksum check)"
printf '%s$ sha256sum --ignore-missing --check SHA256SUMS%s\n' "$C_B" "$C_R"
CSRC=0
CSOUT="$(sha256sum --ignore-missing --check SHA256SUMS 2>&1)" || CSRC=$?
printf '%s\n' "$CSOUT"
if [ "$CSRC" -eq 0 ] && printf '%s\n' "$CSOUT" | grep -q "^bitcoin-$VERSION-x86_64-linux-gnu.tar.gz: OK\$"; then
  ok "CHECKSUM VERIFICATO: il tarball corrisponde alla riga di SHA256SUMS."
else
  err "Il checksum NON corrisponde al riferimento (exit $CSRC)."
  die "STOP. Il file scaricato non coincide con il riferimento ufficiale: non installare nulla, cancella /tmp/bitcoin-* e riprova."
fi

# =============================================================================
say "Passo 3/8 - Import delle chiavi dei firmatari (guida: Signature check)"
printf '%s$ curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do curl -s "$url" | gpg --import; done%s\n' "$C_B" "$C_R"
KEYS_BEFORE="$(gpg --list-keys 2>/dev/null | grep -c '^pub' || true)"
KURLS="$(mktemp)"
KRC=0
curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" \
  | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" > "$KURLS" || KRC=$?
if [ "$KRC" -ne 0 ] || [ ! -s "$KURLS" ]; then
  warn "Non sono riuscito a elencare le builder keys (rete assente, GitHub API non raggiungibile o rate-limit)."
  note "Le chiavi servono per la verifica GPG del passo successivo."
  if ! confirm "Continuare comunque? (senza chiavi la verifica GPG fallira')" N; then
    rm -f "$KURLS"; die "Annullato dall'utente."
  fi
else
  KN=0
  while read -r url; do
    KOUT="$(curl -s "$url" | gpg --import 2>&1)" || true
    printf '%s\n' "$KOUT" | grep -E 'imported|processed|not changed|unchanged|error|failed|cannot' | sed 's/^/    /' || true
    KN=$((KN + 1))
  done < "$KURLS"
  note "Chiavi elaborate: $KN"
fi
rm -f "$KURLS"
KEYS_AFTER="$(gpg --list-keys 2>/dev/null | grep -c '^pub' || true)"
ok "Chiavi pubbliche nel portachiavi: ${KEYS_AFTER:-0} (prima dell'import: ${KEYS_BEFORE:-0})"

# =============================================================================
say "Passo 4/8 - Verifica della firma GPG del file SHA256SUMS (guida: Signature check)"
printf '%s$ gpg --verify SHA256SUMS.asc SHA256SUMS%s\n' "$C_B" "$C_R"
GRC=0
GOUT="$(gpg --verify SHA256SUMS.asc SHA256SUMS 2>&1)" || GRC=$?
printf '%s\n' "$GOUT"
GOOD="$(printf '%s\n' "$GOUT" | grep -c 'Good signature' || true)"
if [ "$GRC" -eq 0 ] && [ "${GOOD:-0}" -ge 1 ]; then
  ok "FIRMA GPG VALIDA: ${GOOD} firma/e 'Good signature' dalle chiavi dei builder di Bitcoin Core."
  if [ "${GOOD:-0}" -lt 2 ]; then
    warn "La guida si aspetta di vedere piu' di una 'Good signature': controlla l'elenco qui sopra."
  fi
else
  err "Verifica GPG FALLITA (exit $GRC, firme valide: ${GOOD:-0})."
  die "STOP. Non installare binari la cui firma non e' verificata."
fi

# =============================================================================
say "Passo 5/8 - Timestamp check OpenTimestamps (guida: Timestamp check)"
if command -v ots >/dev/null 2>&1; then
  printf '%s$ ots --no-cache verify SHA256SUMS.ots -f SHA256SUMS%s\n' "$C_B" "$C_R"
  ORC=0
  OOUT="$(ots --no-cache verify SHA256SUMS.ots -f SHA256SUMS 2>&1)" || ORC=$?
  printf '%s\n' "$OOUT"
  if [ "$ORC" -eq 0 ]; then
    ok "TIMESTAMP VERIFICATO sulla blockchain Bitcoin."
  elif printf '%s' "$OOUT" | grep -q 'Pending confirmation'; then
    warn "Timestamp ancora 'Pending confirmation in Bitcoin blockchain'."
    note "Come da guida e' sicuro proseguire se firma e checksum sono OK (basta riprovare piu' tardi)."
  else
    warn "Il client ots non ha confermato il timestamp (exit $ORC)."
    confirm "Continuare comunque?" N || die "Annullato dall'utente."
  fi
else
  warn "Client 'ots' non installato: salto il controllo del timestamp."
  note "Verifica manuale dal browser: apri https://opentimestamps.org e carica SHA256SUMS.ots + SHA256SUMS."
  note "Installazione del client (guida, sezione OpenTimestamps client):"
  note "  sudo apt install python3-dev python3-pip python3-wheel && sudo pip3 install opentimestamps-client"
  confirm "Continuare senza la verifica del timestamp?" S || die "Annullato dall'utente."
fi

# =============================================================================
say "Passo 6/8 - Estrazione (guida: Extract)"
run tar -xzvf "bitcoin-$VERSION-x86_64-linux-gnu.tar.gz"
[ -x "/tmp/bitcoin-$VERSION/bin/bitcoind" ]    || die "Estrazione incompleta: /tmp/bitcoin-$VERSION/bin/bitcoind non trovato."
[ -x "/tmp/bitcoin-$VERSION/bin/bitcoin-cli" ] || die "Estrazione incompleta: /tmp/bitcoin-$VERSION/bin/bitcoin-cli non trovato."
run ls -l "/tmp/bitcoin-$VERSION/bin/"
ok "Binari estratti in /tmp/bitcoin-$VERSION/bin/"

# =============================================================================
say "Passo 7/8 - Installazione in /usr/local/bin (guida: Binaries installation)"
if [ -n "$CUR" ] && confirm "EXTRA (non previsto dalla guida): salvo una copia di sicurezza dei binari attuali?" S; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  run sudo cp -a /usr/local/bin/bitcoind    "/usr/local/bin/bitcoind.bak-$STAMP"
  run sudo cp -a /usr/local/bin/bitcoin-cli "/usr/local/bin/bitcoin-cli.bak-$STAMP"
  note "Backup: /usr/local/bin/bitcoind.bak-$STAMP e /usr/local/bin/bitcoin-cli.bak-$STAMP"
fi
printf '%s$ sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-%s/bin/bitcoin-cli bitcoin-%s/bin/bitcoind%s\n' "$C_B" "$VERSION" "$VERSION" "$C_R"
sudo install -m 0755 -o root -g root -t /usr/local/bin "bitcoin-$VERSION/bin/bitcoin-cli" "bitcoin-$VERSION/bin/bitcoind"
hash -r 2>/dev/null || true
run bitcoin-cli --version
NV="$(bitcoin-cli --version 2>/dev/null | head -n1 || true)"
case "$NV" in
  *"$VERSION"*) ok "Installata: $NV" ;;
  *)            warn "La versione riportata ($NV) non contiene '$VERSION': controlla." ;;
esac

if confirm "Pulizia opzionale: elimino i file di installazione da /tmp (come da guida)?" S; then
  run sudo rm -r "bitcoin-$VERSION"
  run sudo rm "bitcoin-$VERSION-x86_64-linux-gnu.tar.gz"
  run sudo rm SHA256SUMS SHA256SUMS.asc SHA256SUMS.ots
fi

# =============================================================================
say "Passo 8/8 - Riavvio di bitcoind e controllo dei log"
confirm "Riavvio ora bitcoind per applicare la nuova versione?" S || die "Completato senza riavvio: lancia a mano 'sudo systemctl restart bitcoind'."
run sudo systemctl restart bitcoind
sleep 5
run sudo systemctl status bitcoind --no-pager -l || true
printf '%s$ journalctl -u bitcoind -n 40 --no-pager%s\n' "$C_B" "$C_R"
journalctl -u bitcoind -n 40 --no-pager || true

say "Completato"
note "Bitcoin Core : ${CUR:-non installato}  ->  ${NV:-?}"
note "Binari       : /usr/local/bin/bitcoind , /usr/local/bin/bitcoin-cli"
note "Verifica RPC : bitcoin-cli getblockchaininfo"
echo
if confirm "Vuoi seguire il journal di bitcoind in tempo reale adesso? (si esce con Ctrl-C)" N; then
  note "Premi Ctrl-C per uscire: a questo punto l'aggiornamento e' gia' completato, quindi un'interruzione non e' un errore."
  trap - ERR
  journalctl -fu bitcoind || true
  trap on_err ERR
fi
