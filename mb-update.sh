#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
#  MiniBolt - Launcher degli aggiornamenti
#  Menu unico per i 4 script di aggiornamento (che restano eseguibili da soli).
#
#  Password: nessuna password viene gestita qui; ogni script fa il proprio
#  `sudo -v` e non salva mai nulla su disco.
# =============================================================================
set -Eeuo pipefail

C_R=$'\033[0m'; C_B=$'\033[1m'; C_C=$'\033[36m'; C_Y=$'\033[33m'
C_G=$'\033[32m'; C_E=$'\033[31m'

say()  { printf '\n%s== %s ==%s\n' "$C_B$C_C" "$*" "$C_R"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '%s[ATTENZIONE]%s %s\n' "$C_Y" "$C_R" "$*"; }
err()  { printf '%s[ERRORE]%s %s\n' "$C_E" "$C_R" "$*" >&2; }

DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

S_BUILD="$DIR/mb-update-buildtools.sh"
S_CORE="$DIR/mb-update-bitcoin-core.sh"
S_ELECTRS="$DIR/mb-update-electrs.sh"
S_EXPLORER="$DIR/mb-update-btc-rpc-explorer.sh"

check_files() {
  local f
  for f in "$S_BUILD" "$S_CORE" "$S_ELECTRS" "$S_EXPLORER"; do
    [ -f "$f" ] || { err "Script mancante: $f"; exit 1; }
    [ -x "$f" ] || chmod +x "$f" 2>/dev/null || true
  done
}

separator() { printf '\n%s--------------------------------------------------------------%s\n' "$C_C" "$C_R"; }

run_one() {  # run_one <file> <etichetta>
  separator
  note "Avvio: $(basename "$1")"
  separator
  local rc=0
  bash "$1" || rc=$?
  if [ "$rc" -eq 0 ]; then
    note "Fatto: $(basename "$1")"
  elif [ "$rc" -ge 129 ]; then
    warn "$(basename "$1") interrotto da un segnale (exit $rc): se l'hai fermato tu con Ctrl-C va bene cosi'."
  else
    warn "Lo script $(basename "$1") e' terminato con errore (exit $rc)."
  fi
  printf '\n'
  read -r -p "Premi INVIO per tornare al menu..." _ || true
}

check_files

while true; do
  say "MiniBolt - Aggiornamenti"
  note "Guide di riferimento: minibolt.minibolt.info"
  echo
  printf '  1) Tool di build  (Rustup + Cargo, Node + NPM)\n'
  printf '  2) Bitcoin Core   (binari precompilati, con verifica firma/checksum/timestamp)\n'
  printf '  3) Electrs        (compilazione dal sorgente, firma git del tag)\n'
  printf '  4) BTC RPC Explorer (git fetch/reset + npm install)\n'
  printf '  5) Tutti in sequenza: 1 -> 2 -> 3 -> 4\n'
  printf '  q) Esci\n'
  echo
  read -r -p "Scelta: " CHOICE || true

  case "${CHOICE:-}" in
    1) run_one "$S_BUILD" ;;
    2) run_one "$S_CORE" ;;
    3) run_one "$S_ELECTRS" ;;
    4) run_one "$S_EXPLORER" ;;
    5)
      separator
      note "Sequenza completa. Verrai interrogato per ogni versione da installare."
      note "Ordine: tool di build -> Bitcoin Core -> Electrs -> BTC RPC Explorer."
      separator
      read -r -p "Procedo con l'intera sequenza? (s/N) " A || true
      case "${A:-N}" in
        [sSyY]*)
          run_one "$S_BUILD"
          run_one "$S_CORE"
          run_one "$S_ELECTRS"
          run_one "$S_EXPLORER"
          ;;
        *) note "Annullato." ;;
      esac
      ;;
    q|Q) note "Uscita."; exit 0 ;;
    *) warn "Scelta non valida." ;;
  esac
done
