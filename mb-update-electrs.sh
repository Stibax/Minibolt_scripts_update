#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
#  MiniBolt - Aggiornamento Electrs
#  Guida: https://minibolt.minibolt.info/bonus-guides/bitcoin/electrs
#         https://minibolt.minibolt.info/bonus-guides/system/rustup-cargo#upgrade
#
#  La sezione "Upgrade" della guida prescrive, in quest'ordine:
#    1) portare Rustc/Cargo all'ultima versione   -> rustup update
#    2) seguire TUTTA la sezione "Build from the source code" (dipendenze,
#       RocksDB, clone del tag firmato, verifica della firma git, cargo build,
#       install in /usr/local/bin)
#    3) riavviare electrs e controllare i log
#
#  Config gia' presenti (electrs.conf, electrs.service, reverse proxy nginx,
#  regole ufw, hidden service Tor) NON vengono toccate: l'upgrade le riusa.
#
#  Password: nessuna password viene mai salvata su disco, in file di log, nella
#  shell history o in variabili d'ambiente. L'autenticazione e' gestita
#  esclusivamente dal prompt nativo di sudo (`sudo -v`).
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

ask() {
  local p=$1 d=${2-} a
  if [ -n "$d" ]; then read -r -p "$p [$d]: " a || true; printf '%s' "${a:-$d}"
  else read -r -p "$p: " a || true; printf '%s' "$a"; fi
}
confirm() {
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
latest_gh_tag() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -m1 '"tag_name"' \
    | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v?([^"]+)".*/\1/' || true
}
load_cargo_env() { [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env" || true; }

ELECTRS_SIGNER="git@romanzey.de ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAZVq/3fgkildjN/MqEnhrP5550sDpFzGxMwevr5q/9w"

# -----------------------------------------------------------------------------
say "MiniBolt - Aggiornamento Electrs (compilazione dal sorgente)"
note "Guida: https://minibolt.minibolt.info/bonus-guides/bitcoin/electrs"
echo
note "Sequenza eseguita (sezione Upgrade + Build from the source code):"
note "  1  rustup update                     (guida Rustup + Cargo -> Upgrade)"
note "  2  dipendenze di sistema + RocksDB dal sorgente (sempre ricompilato)"
note "  3  git clone del tag electrs + allowed_signers + git verify-tag -v"
note "  4  cargo build --locked --release (ROCKSDB_INCLUDE_DIR / ROCKSDB_LIB_DIR)"
note "  5  sudo install -m 0755 -o root -g root -t /usr/local/bin ./target/release/electrs"
note "  6  sudo systemctl restart electrs + controllo dei log"
echo
warn "Attenzione: la compilazione di RocksDB e di Electrs puo' durare 15-30 minuti o piu'."
confirm "Procedo?" S || die "Annullato dall'utente."

require_cmds git curl systemctl
note "cmake, make, g++ e le altre dipendenze di compilazione vengono installate dal"
note "passo 2 (comando 'sudo apt install ...' della guida), non sono richieste adesso."
sudo_start

CURV="$(electrs --version 2>/dev/null || true)"
if [ -n "$CURV" ]; then note "Versione attualmente installata: electrs $CURV"
else warn "electrs non trovato in /usr/local/bin: procedo come prima installazione del binario."; fi

# =============================================================================
say "Passo 0 - Limite di file aperti per electrs (lacuna della guida)"
note "La unit electrs.service della guida NON imposta LimitNOFILE: il processo eredita"
note "il default di systemd (soft 1024). RocksDB tiene aperti tutti i file .sst"
note "dell'indice bindex (migliaia): superato il tetto electrs muore con"
note "'Too many open files'. Trappola: 'systemctl show electrs -p LimitNOFILE'"
note "stampa il HARD (524288) e sembra tutto a posto; il soft effettivo si legge solo"
note "da /proc/<pid>/limits. Questo passo NON e' nella guida: lo script se ne discosta"
note "perche' senza, con un indice grande, l'aggiornamento finisce male."
DROPIN_DIR=/etc/systemd/system/electrs.service.d
if sudo grep -rsq LimitNOFILE "$DROPIN_DIR" 2>/dev/null; then
  ok "LimitNOFILE gia' impostato da un drop-in:"
  sudo grep -rn LimitNOFILE "$DROPIN_DIR" | sed 's/^/    /'
else
  warn "Nessun drop-in in $DROPIN_DIR imposta LimitNOFILE."
  printf '%s$ printf "[Service]\\nLimitNOFILE=65536\\n" | sudo tee %s/10-nofile.conf%s\n' "$C_B" "$DROPIN_DIR" "$C_R"
  if confirm "Creo il drop-in LimitNOFILE=65536 (consigliato)?" S; then
    sudo mkdir -p "$DROPIN_DIR"
    printf '[Service]\nLimitNOFILE=65536\n' | sudo tee "$DROPIN_DIR/10-nofile.conf" >/dev/null
    run sudo systemctl daemon-reload
    ok "Drop-in creato: avra' effetto al riavvio di electrs (Passo 7)."
  else
    warn "Drop-in non creato: se l'indice e' grande electrs puo' morire di nuovo."
  fi
fi

# =============================================================================
say "Passo 1 - Rustc / Cargo all'ultima versione (guida: prima voce della sezione Upgrade)"
load_cargo_env
if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
  note "Prima dell'aggiornamento:"
  run rustc --version
  run cargo -V
  run rustup update
  ok "Dopo l'aggiornamento:"
  run rustc --version
  run cargo -V
else
  warn "rustc/cargo non trovati."
  note "La guida rimanda al bonus 'Rustup + Cargo' per l'installazione:"
  note '  curl --proto '"'"'=https'"'"' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal'
  confirm "Installo ora Rustup + Cargo con il comando qui sopra (come da guida)?" S || die "Annullato: installa Rust e rilancia."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  load_cargo_env
  run rustc --version
  run cargo -V
fi

# =============================================================================
say "Passo 2 - Dipendenze di sistema (guida: Preparations -> Install dependencies)"
if confirm "Eseguo 'sudo apt update && sudo apt full-upgrade' come da guida?" S; then
  run sudo apt update
  run sudo apt full-upgrade
fi
printf '%s$ sudo apt install libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev clang llvm-dev libclang-dev make g++ cmake build-essential%s\n' "$C_B" "$C_R"
sudo apt install libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev clang llvm-dev libclang-dev make g++ cmake build-essential

# =============================================================================
say "Passo 3 - RocksDB dal sorgente (guida: Install dependencies)"
note "La guida NON prevede alcuna verifica di firma/checksum per RocksDB: si clona"
note "il tag indicato dalla guida dal repository ufficiale https://github.com/facebook/rocksdb"
while :; do
  ROCKSDB_VERSION="$(ask "Versione (tag) di RocksDB richiesta dalla guida" "9.10.0")"
  ROCKSDB_VERSION="${ROCKSDB_VERSION#v}"
  [[ "$ROCKSDB_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] && break
  warn "Formato non valido: '$ROCKSDB_VERSION'. Riprova (Ctrl-C per uscire)."
done

run cd /tmp
if [ -e /tmp/rocksdb ]; then
  if confirm "Esiste gia' /tmp/rocksdb: lo elimino?" S; then run sudo rm -r /tmp/rocksdb; else die "Rimuovi /tmp/rocksdb e rilancia."; fi
fi
run git clone -b "v$ROCKSDB_VERSION" --depth 1 https://github.com/facebook/rocksdb
run cd /tmp/rocksdb
printf '%s$ make shared_lib -j %s%s\n' "$C_B" "$(nproc)" "$C_R"
make shared_lib -j "$(nproc)"
run sudo make install-shared
run sudo ldconfig
run cd /tmp
run sudo rm -r /tmp/rocksdb
[ -e /usr/local/lib/librocksdb.so ] || warn "Non vedo /usr/local/lib/librocksdb.so: controlla l'esito di 'sudo make install-shared'."
ok "RocksDB v$ROCKSDB_VERSION installata e cache delle librerie condivise aggiornata (ldconfig)."

# =============================================================================
say "Passo 4 - Clone e verifica firma del tag electrs (guida: Build from the source code)"
run cd /tmp
DEFVER="$(latest_gh_tag romanz/electrs)"
while :; do
  VERSION="$(ask "Versione di Electrs da installare (es. 0.11.1, senza la 'v')" "$DEFVER")"
  VERSION="${VERSION#v}"
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] && break
  warn "Formato non valido: '$VERSION'. Riprova (Ctrl-C per uscire)."
done

if git ls-remote --tags https://github.com/romanz/electrs.git "refs/tags/v$VERSION" | grep -q .; then
  ok "Il tag v$VERSION esiste nel repository romanz/electrs."
else
  err "Il tag v$VERSION non esiste su romanz/electrs."
  note "Ultimi tag disponibili:"
  git ls-remote --tags https://github.com/romanz/electrs.git 2>/dev/null | grep -oE 'refs/tags/v[0-9.]+$' | sed 's|refs/tags/||' | sort -V | tail -n 10 | sed 's|^|    |' || true
  exit 1
fi

if [ -e /tmp/electrs ]; then
  if confirm "Esiste gia' /tmp/electrs: lo elimino?" S; then run sudo rm -r /tmp/electrs; else die "Rimuovi /tmp/electrs e rilancia."; fi
fi
run git clone --branch "v$VERSION" https://github.com/romanz/electrs.git
run cd /tmp/electrs

step "Chiave pubblica del manutentore (guida: allowed_signers)"
run mkdir -p "$HOME/.config/git"
ALLOWED="$HOME/.config/git/allowed_signers"
if [ -f "$ALLOWED" ] && grep -qF "$ELECTRS_SIGNER" "$ALLOWED"; then
  ok "$ALLOWED esiste e contiene gia' la chiave di Roman Zeyde."
elif [ -f "$ALLOWED" ]; then
  warn "$ALLOWED esiste ma non contiene la chiave attesa: la aggiungo in coda."
  printf '%s\n' "$ELECTRS_SIGNER" >> "$ALLOWED"
else
  printf '%s$ cat > %s%s\n' "$C_B" "$ALLOWED" "$C_R"
  printf '%s\n' "$ELECTRS_SIGNER" > "$ALLOWED"
fi
printf '%s$ cat %s%s\n' "$C_B" "$ALLOWED" "$C_R"
cat "$ALLOWED"
run git config --global gpg.ssh.allowedSignersFile "$ALLOWED"

step "Verifica della firma del tag (guida: Verify the release)"
printf '%s$ git verify-tag -v v%s%s\n' "$C_B" "$VERSION" "$C_R"
set +e
VOUT="$(git verify-tag -v "v$VERSION" 2>&1)"; VRC=$?
set -e
printf '%s\n' "$VOUT"
if [ "$VRC" -eq 0 ] && printf '%s\n' "$VOUT" | grep -q "Good \"git\" signature"; then
  ok "FIRMA GIT VALIDA del tag v$VERSION (firmato da Roman Zeyde)."
else
  err "Verifica della firma FALLITA (exit $VRC)."
  die "STOP. Il tag v$VERSION non e' firmato correttamente: non compilare questo sorgente."
fi

# =============================================================================
say "Passo 5 - Compilazione (guida: Now compile the source code into an executable binary)"
printf '%s$ ROCKSDB_INCLUDE_DIR=/usr/local/include ROCKSDB_LIB_DIR=/usr/local/lib cargo build --locked --release%s\n' "$C_B" "$C_R"
note "(puo' durare 15-30 minuti; l'output di cargo scorre qui sotto)"
ROCKSDB_INCLUDE_DIR=/usr/local/include ROCKSDB_LIB_DIR=/usr/local/lib cargo build --locked --release
[ -x ./target/release/electrs ] || die "Compilazione terminata ma ./target/release/electrs non esiste."

say "Passo 6 - Installazione (guida: Install it)"
run sudo install -m 0755 -o root -g root -t /usr/local/bin ./target/release/electrs
run electrs --version
NV="$(electrs --version 2>/dev/null || true)"
case "$NV" in
  *"$VERSION"*) ok "Installata: electrs $NV" ;;
  *)            warn "electrs riporta '$NV', atteso v$VERSION: controlla." ;;
esac

if confirm "Pulizia opzionale: elimino /tmp/electrs?" S; then
  run sudo rm -r /tmp/electrs
fi
run cd "$HOME"

# =============================================================================
say "Passo 7 - Riavvio di electrs e controllo dei log"
confirm "Riavvio ora electrs per applicare la nuova versione?" S || die "Completato senza riavvio: lancia a mano 'sudo systemctl restart electrs'."
run sudo systemctl restart electrs
sleep 5
run sudo systemctl status electrs --no-pager -l || true
printf '%s$ journalctl -u electrs -n 40 --no-pager%s\n' "$C_B" "$C_R"
journalctl -u electrs -n 40 --no-pager || true

EL_PID="$(systemctl show -p MainPID --value electrs 2>/dev/null || true)"
if [ -n "${EL_PID:-}" ] && [ "$EL_PID" != "0" ]; then
  printf '%s$ sudo grep -i "open files" /proc/%s/limits%s\n' "$C_B" "$EL_PID" "$C_R"
  sudo grep -i "open files" "/proc/$EL_PID/limits" || true
  SOFT="$(sudo awk '/Max open files/{print $4}' "/proc/$EL_PID/limits" 2>/dev/null || true)"
  if [ "${SOFT:-0}" -ge 16384 ] 2>/dev/null; then
    ok "Limite soft di file aperti del processo: $SOFT"
  else
    warn "Limite soft di file aperti: ${SOFT:-?} - troppo basso per l'indice bindex: crea il drop-in del Passo 0 e riavvia electrs."
  fi
fi

if journalctl -u electrs -n 200 --no-pager 2>/dev/null | grep -q "Starting electrs $VERSION"; then
  ok "I log riportano 'Starting electrs $VERSION': la nuova versione e' in esecuzione."
else
  warn "Nei log recenti non vedo 'Starting electrs $VERSION': verifica con 'journalctl -fu electrs'."
fi

say "Completato"
note "Electrs     : ${CURV:-non installato}  ->  ${NV:-?}"
note "Binario     : /usr/local/bin/electrs"
note "Config      : /data/electrs/electrs.conf (non modificata)"
note "Porte       : 50001 TCP / 50002 SSL (reverse proxy nginx)"
echo
if confirm "Vuoi seguire il journal di electrs in tempo reale adesso? (si esce con Ctrl-C)" N; then
  note "Premi Ctrl-C per uscire: a questo punto l'aggiornamento e' gia' completato, quindi un'interruzione non e' un errore."
  trap - ERR
  journalctl -fu electrs || true
  trap on_err ERR
fi
