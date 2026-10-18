#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
#  MiniBolt - Aggiornamento dei tool di build
#    A) Rustup + Cargo  -> https://minibolt.minibolt.info/bonus-guides/system/rustup-cargo
#    B) Node + NPM      -> https://minibolt.minibolt.info/bonus-guides/system/nodejs-npm
#
#  Esegue i comandi delle sezioni "Installation", "Upgrade" e "Upgrade to the
#  major version" delle due guide bonus, nell'ordine in cui sono elencati.
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
load_cargo_env() { [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env" || true; }

# -----------------------------------------------------------------------------
say "MiniBolt - Aggiornamento dei tool di build"
note "Rustup + Cargo : https://minibolt.minibolt.info/bonus-guides/system/rustup-cargo"
note "Node + NPM     : https://minibolt.minibolt.info/bonus-guides/system/nodejs-npm"
echo
note "Sezioni eseguite:"
note "  A) Rustup + Cargo  -> Installation (se manca) / Upgrade (rustup update)"
note "  B) Node + NPM      -> Upgrade (minor) oppure Upgrade to the major version"
echo
RUST=1; NODE=1
confirm "Aggiorno Rustup + Cargo (Rust)?" S || RUST=0
confirm "Aggiorno Node + NPM?" S || NODE=0
[ "$RUST$NODE" = "00" ] && die "Niente da fare: annullato dall'utente."

require_cmds curl systemctl
sudo_start

# =============================================================================
if [ "$RUST" -eq 1 ]; then
say "PARTE A - Rustup + Cargo"
note "Guida: https://minibolt.minibolt.info/bonus-guides/system/rustup-cargo"
load_cargo_env

if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
  note "Versioni prima dell'aggiornamento:"
  run rustc --version
  run cargo -V
  say "Upgrade (guida: sezione Upgrade)"
  run rustup update
  run rustup --version || true
  note "Versioni dopo l'aggiornamento:"
  run rustc --version
  run cargo -V
  ok "Rustup + Cargo aggiornati."
else
  warn "rustc/cargo non trovati in PATH: eseguo l'installazione (guida: sezione Installation)."
  note "Nota: rustup installa in \$HOME/.cargo - NON eseguirlo con sudo (la guida usa l'utente admin)."
  printf '%s$ curl --proto '"'"'=https'"'"' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal%s\n' "$C_B" "$C_R"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  step "Configurazione della shell corrente (guida: source \"\$HOME/.cargo/env\")"
  run bash -c '. "$HOME/.cargo/env"'
  load_cargo_env
  run rustc --version
  run cargo -V
  ok "Rustup + Cargo installati."
  note "Nelle nuove shell la PATH e' gia' configurata da rustup."
fi
fi

# =============================================================================
if [ "$NODE" -eq 1 ]; then
say "PARTE B - Node + NPM"
note "Guida: https://minibolt.minibolt.info/bonus-guides/system/nodejs-npm"
NODEPRESENT=0
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  NODEPRESENT=1
  run node -v
  run npm -v
  CURNODE="$(node -v 2>/dev/null || true)"
  CURNPM="$(npm -v 2>/dev/null || true)"
  ok "Installati: node ${CURNODE:-?} / npm ${CURNPM:-?}"
else
  warn "node/npm non trovati: verrà eseguita l'installazione dal repository NodeSource (come da guida)."
fi

step "Servizi dipendenti da Node (la guida usa BTC RPC Explorer e ThunderHub)"
SERVICES=()
while read -r s; do [ -n "$s" ] && SERVICES+=("$s"); done < <(
  systemctl list-unit-files --no-legend 2>/dev/null \
    | awk '{print $1}' | grep -E '^(btcrpcexplorer|thunderhub)\.service$' || true
)
if [ "${#SERVICES[@]}" -gt 0 ]; then
  note "Servizi trovati: ${SERVICES[*]}"
  for s in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$s"; then run sudo systemctl stop "$s"; note "(fermato: $s)"
    else note "$s non attivo: nessuno stop necessario."; fi
  done
else
  warn "Nessun servizio btcrpcexplorer/thunderhub trovato: procedo senza fermare servizi."
  SERVICES=()
fi

step "Tipo di aggiornamento"
if [ "$NODEPRESENT" -eq 0 ]; then
  warn "Node non installato: eseguo l'installazione con il repository NodeSource (major LTS)."
  CHOICE=2
else
  note "  1 = aggiornamento minore  (apt full-upgrade nel major attuale)          [guida: Upgrade]"
  note "  2 = aggiornamento di major (es. 20 -> 22, con il repo NodeSource)       [guida: Upgrade to the major version]"
  CHOICE="$(ask "Scelta" "1")"
fi

if [ "$CHOICE" = "2" ]; then
  warn "La guida ricorda: si passa alla versione LTS immediatamente superiore, es. 20 > 22."
  VERSION="$(ask "Major LTS di Node.js da installare" "22")"
  [[ "$VERSION" =~ ^[0-9]+$ ]] || die "Major non valido: '$VERSION' (atteso un numero, es. 22)"
  run cd /tmp
  printf '%s$ VERSION=%s%s\n' "$C_B" "$VERSION" "$C_R"
  printf '%s$ curl -fsSL https://deb.nodesource.com/setup_$VERSION.x -o nodesource_setup.sh%s\n' "$C_B" "$C_R"
  curl -fsSL "https://deb.nodesource.com/setup_$VERSION.x" -o nodesource_setup.sh
  run sudo -E bash nodesource_setup.sh
  run sudo apt update
  run sudo apt install nodejs
  run node -v
  run npm -v
  [ -f nodesource_setup.sh ] && run rm nodesource_setup.sh
else
  run sudo apt update
  run sudo apt full-upgrade
  run node -v
  run npm -v
  if [ -f /tmp/nodesource_setup.sh ]; then run rm /tmp/nodesource_setup.sh; fi
fi

NEWNODE="$(node -v 2>/dev/null || true)"
NEWNPM="$(npm -v 2>/dev/null || true)"
ok "Node/NPM ora: ${NEWNODE:-?} / ${NEWNPM:-?}"

if command -v thunderhub >/dev/null 2>&1 || systemctl list-unit-files --no-legend 2>/dev/null | grep -q '^thunderhub\.service'; then
  step "Telemetria Next.js (guida: opzionale, riguarda ThunderHub)"
  if confirm "Vuoi disattivare la telemetria di Next.js (npx next telemetry disable) come da guida?" N; then
    printf '%s(thunderhub)$ npx next telemetry disable%s\n' "$C_B" "$C_R"
    sudo -u thunderhub -H bash -c 'cd ~ && npx next telemetry disable' || warn "Operazione non riuscita."
    printf '%s(thunderhub)$ npx next telemetry status%s\n' "$C_B" "$C_R"
    sudo -u thunderhub -H bash -c 'cd ~ && npx next telemetry status' || true
  fi
fi

step "Riavvio dei servizi fermati"
if [ "${#SERVICES[@]}" -gt 0 ]; then
  for s in "${SERVICES[@]}"; do run sudo systemctl start "$s"; done
else
  note "Nessun servizio da riavviare."
fi
fi

say "Completato"
note "Rust : $(rustc --version 2>/dev/null || echo 'non installato')  |  $(cargo -V 2>/dev/null || echo '-')"
note "Node : $(node -v 2>/dev/null || echo 'non installato')  |  npm $(npm -v 2>/dev/null || echo '-')"
note ""
note "Se hai aggiornato Node, ricorda che BTC RPC Explorer va riavviato (fatto sopra)."
note "Per Electrs, dopo l'aggiornamento di Rust esegui mb-update-electrs.sh."
