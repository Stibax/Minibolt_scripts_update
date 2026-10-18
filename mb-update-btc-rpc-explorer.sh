#!/usr/bin/env bash
# shellcheck shell=bash
# =============================================================================
#  MiniBolt - Aggiornamento BTC RPC Explorer
#  Guida: https://minibolt.minibolt.info/bitcoin/bitcoin/btc-rpc-explorer
#
#  La sezione "Upgrade" della guida prescrive, in quest'ordine:
#    sudo systemctl stop btcrpcexplorer
#    sudo su - btcrpcexplorer
#    cd btc-rpc-explorer
#    git fetch origin
#    git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)
#    git clean -fd
#    npm install
#    head -n 3 .../package.json | grep version
#    exit
#    sudo systemctl start btcrpcexplorer
#
#  Note importanti:
#   * la guida NON ha versioni numerate: l'upgrade segue l'ultimo commit del
#     branch corrente. E' disponibile anche l'opzione di pinnare un tag/commit.
#   * la guida NON prevede alcun controllo di firma nella sezione Upgrade: la
#     verifica `git verify-commit` esiste solo nella sezione di installazione.
#     Qui viene proposta come controllo EXTRA facoltativo (default: no).
#   * NON eseguire mai `npm audit fix` (indicazione esplicita della guida).
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
as_user() { printf '%s(btcrpcexplorer)$ %s%s\n' "$C_B" "$*" "$C_R"; sudo -u btcrpcexplorer -H bash -c "$*"; }
require_cmds() {
  local missing=() c
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    err "Comandi mancanti: ${missing[*]}"
    note "Per Node + NPM la guida rimanda a: https://minibolt.minibolt.info/bonus-guides/system/nodejs-npm"
    note "(oppure usa lo script mb-update-buildtools.sh)"
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

# La home dell'utente btcrpcexplorer e' tipicamente 0750 (drwxr-x---): l'utente admin
# NON puo' attraversarla, quindi ogni controllo su file e cartelle del repo va fatto
# come root (sudo e' gia' attivo). Senza questo, un `test -d` sul repo fallisce per
# PERMESSI e sembra che l'installazione non esista.
as_root() { sudo "$@"; }

BTCEXP_USER="btcrpcexplorer"
BTCEXP_DIR_DEFAULT="/home/$BTCEXP_USER/btc-rpc-explorer"
# Percorso personalizzato (solo se serve): primo argomento oppure MB_BTCEXP_DIR.
#   ./mb-update-btc-rpc-explorer.sh /opt/btc-rpc-explorer
BTCEXP_DIR="${1:-${MB_BTCEXP_DIR:-$BTCEXP_DIR_DEFAULT}}"

# -----------------------------------------------------------------------------
say "MiniBolt - Aggiornamento BTC RPC Explorer"
note "Guida: https://minibolt.minibolt.info/bitcoin/bitcoin/btc-rpc-explorer"
echo
warn "La guida non assegna un numero di versione a BTC RPC Explorer: l'aggiornamento"
note "segue l'ultimo commit del branch corrente (git fetch + git reset --hard origin/<branch>)."
note "Puoi comunque indicare un tag/commit preciso al momento della richiesta."
echo

require_cmds git node npm systemctl
sudo_start

id "$BTCEXP_USER" >/dev/null 2>&1 || die "Utente '$BTCEXP_USER' inesistente: BTC RPC Explorer non risulta installato."
# --- individuazione dell'installazione ---------------------------------------
# Il percorso della guida e' /home/btcrpcexplorer/btc-rpc-explorer, ma non e' scritto
# da nessuna parte che sia per forza li': se non e' un repository git, lo cerchiamo
# (unit systemd del servizio, poi percorsi tipici) invece di fermarci con un errore secco.
if ! as_root test -d "$BTCEXP_DIR/.git"; then
  # Qui dentro si fanno SOLO sonde: con set -e/pipefail basta un find che incontra
  # una cartella illeggibile per far scattare il trap ERR e interrompere lo script.
  # Il trap resta spento per tutto il blocco e viene ripristinato subito dopo.
  trap - ERR
  TROVATO=""
  if [ "$BTCEXP_DIR" = "$BTCEXP_DIR_DEFAULT" ]; then
    step "Ricerca dell'installazione"
    note "Il percorso previsto dalla guida non e' un repository git: $BTCEXP_DIR"
    UNIT="$(systemctl cat btcrpcexplorer 2>/dev/null || true)"
    if [ -n "$UNIT" ]; then
      WD="$(printf '%s\n' "$UNIT" | sed -nE 's/^[[:space:]]*WorkingDirectory=//p' | head -n1 | tr -d '"')"
      if [ -n "$WD" ] && as_root test -d "$WD/.git"; then
        TROVATO="$WD"
      else
        # dall'eseguibile di ExecStart risaliamo fino alla cartella col package.json
        for p in $(printf '%s\n' "$UNIT" | sed -nE 's/^[[:space:]]*ExecStart=[^=]*[[:space:]]([^[:space:]]+)[[:space:]]*$/\1/p'); do
          case "$p" in /*) ;; *) continue ;; esac
          d="$(dirname "$p")"
          while [ -n "$d" ] && [ "$d" != "/" ]; do
            if as_root test -f "$d/package.json" && sudo grep -q 'btc-rpc-explorer' "$d/package.json" 2>/dev/null; then
              TROVATO="$d"; break
            fi
            d="$(dirname "$d")"
          done
          [ -n "$TROVATO" ] && break
        done
      fi
      [ -n "$TROVATO" ] && note "Unit systemd: installazione individuata in $TROVATO"
    fi
    if [ -z "$TROVATO" ]; then
      for base in "$HOME" /home /opt /srv /usr/local; do
        [ -d "$base" ] || continue
        cand="$(sudo find "$base" -maxdepth 4 -type d -name 'btc-rpc-explorer' 2>/dev/null | head -n1)" || true
        if [ -n "$cand" ] && as_root test -d "$cand/.git"; then TROVATO="$cand"; break; fi
      done
    fi
  fi
  trap on_err ERR
  if [ -n "$TROVATO" ]; then
    BTCEXP_DIR="$TROVATO"
    ok "Installazione trovata qui: $BTCEXP_DIR"
  elif as_root test -d "$BTCEXP_DIR"; then
    die "La cartella $BTCEXP_DIR esiste ma non e' un repository git: l'aggiornamento via git (fetch + reset) non e' applicabile. Installazione fatta da archivio? In quel caso reinstalla seguendo la guida."
  else
    die "Nessun repository git di BTC RPC Explorer trovato (cercato in $BTCEXP_DIR_DEFAULT e nei percorsi tipici).
    Attenzione: questo script AGGIORNA un'installazione esistente, non la crea.
    Per capire cosa c'e' sul nodo:
      systemctl cat btcrpcexplorer            # esiste il servizio? da dove parte?
      sudo ls -la /home/$BTCEXP_USER/         # cosa contiene la home dell'utente?
      sudo find / -maxdepth 5 -type d -name 'btc-rpc-explorer' 2>/dev/null
    Se e' installato altrove, indicalo come argomento:
      $0 /percorso/btc-rpc-explorer            (oppure MB_BTCEXP_DIR=/percorso)
    Se non e' installato (o gira in un container Docker), segui la guida:
      https://minibolt.minibolt.info/bitcoin/bitcoin/btc-rpc-explorer"
  fi
fi
run sudo systemctl is-active --quiet btcrpcexplorer && note "Servizio btcrpcexplorer attivo." || warn "Servizio btcrpcexplorer non attivo."

# --- stato attuale -----------------------------------------------------------
step "Stato attuale"
printf '%s(btcrpcexplorer)$ head -n 3 /home/btcrpcexplorer/btc-rpc-explorer/package.json | grep version%s\n' "$C_B" "$C_R"
sudo head -n 3 "$BTCEXP_DIR/package.json" | grep version || true
CURVER="$(sudo grep -m1 '"version"' "$BTCEXP_DIR/package.json" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true)"
CURBRANCH="$(sudo -u "$BTCEXP_USER" -H git -C "$BTCEXP_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
CURCOMMIT="$(sudo -u "$BTCEXP_USER" -H git -C "$BTCEXP_DIR" log -1 --format='%h %ad %s' --date=short 2>/dev/null || true)"
note "Branch   : ${CURBRANCH:-?}"
note "Commit   : ${CURCOMMIT:-?}"
note "Versione : ${CURVER:-?}"

REQ="$(ask "Tag o commit da installare (INVIO = ultimo commit del branch corrente, come da guida)" "")"
if [ -n "$REQ" ]; then MODE=pin; else MODE=branch; fi

echo
say "Riepilogo operazione"
note "Componente : BTC RPC Explorer"
note "Da         : ${CURVER:-?} (${CURCOMMIT:-?})"
if [ "$MODE" = pin ]; then note "A          : $REQ  (checkout pinnato, NON previsto dalla guida)"
else note "A          : ultimo commit del branch '${CURBRANCH:-main}' (come da guida)"; fi
confirm "Procedo?" S || die "Annullato dall'utente."

# =============================================================================
say "Passo 1 - Stop del servizio (guida: Upgrade, primo comando)"
run sudo systemctl stop btcrpcexplorer

# =============================================================================
say "Passo 2 - Accesso come utente btcrpcexplorer e aggiornamento del repository"
note "La guida fa 'sudo su - btcrpcexplorer' e poi opera nella home dell'utente."
note "Qui gli stessi comandi vengono eseguiti come utente btcrpcexplorer (sudo -u ... -H),"
note "con la stessa sequenza: cd btc-rpc-explorer, git fetch, git reset, git clean, npm install, exit."
printf '%s(btcrpcexplorer)$ sudo su - %s%s   # equivalente: sudo -u %s -H\n' "$C_B" "$BTCEXP_USER" "$C_R" "$BTCEXP_USER"
printf '%s(btcrpcexplorer)$ cd btc-rpc-explorer%s\n' "$C_B" "$C_R"

if [ "$MODE" = branch ]; then
  as_user 'cd ~/btc-rpc-explorer && git fetch origin'
  printf '%s(btcrpcexplorer)$ git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)%s\n' "$C_B" "$C_R"
  as_user 'cd ~/btc-rpc-explorer && git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)'
else
  as_user 'cd ~/btc-rpc-explorer && git fetch origin --tags'
  printf '%s(btcrpcexplorer)$ git checkout --force %s%s\n' "$C_B" "$REQ" "$C_R"
  as_user "cd ~/btc-rpc-explorer && git checkout --force '$REQ'"
fi
printf '%s(btcrpcexplorer)$ git clean -fd%s\n' "$C_B" "$C_R"
as_user 'cd ~/btc-rpc-explorer && git clean -fd'

NEWCOMMIT="$(sudo -u "$BTCEXP_USER" -H git -C "$BTCEXP_DIR" log -1 --format='%h %ad %s' --date=short 2>/dev/null || true)"
note "Ora in HEAD: ${NEWCOMMIT:-?}"

# --- controllo EXTRA di firma (non presente nella sezione Upgrade) -----------
say "Controllo EXTRA - firma GPG del commit (facoltativo)"
note "La sezione 'Upgrade' della guida non prevede questo controllo: e' presente"
note "solo nella sezione di installazione ('git verify-commit HEAD', dentro il repo)."
if confirm "Esegui il controllo della firma GPG del commit (EXTRA, non previsto dalla guida)?" N; then
  if ! sudo -u "$BTCEXP_USER" -H gpg --list-keys 2>/dev/null | grep -q 'janoside'; then
    step "Importo la chiave GPG dello sviluppatore (guida: Installazione)"
    printf '%s(btcrpcexplorer)$ curl https://github.com/janoside.gpg | gpg --import%s\n' "$C_B" "$C_R"
    sudo -u "$BTCEXP_USER" -H bash -c 'curl -fsSL https://github.com/janoside.gpg | gpg --import' || warn "Import della chiave fallito."
  fi
  SVRC=0
  SVOUT="$(sudo -u "$BTCEXP_USER" -H bash -c 'cd ~/btc-rpc-explorer && git verify-commit $(git rev-parse HEAD)' 2>&1)" || SVRC=$?
  printf '%s\n' "$SVOUT"
  if [ "$SVRC" -eq 0 ] && printf '%s' "$SVOUT" | grep -q 'Good signature'; then
    ok "Firma GPG del commit VALIDA."
  else
    warn "Firma GPG del commit NON verificata (exit $SVRC)."
    confirm "Continuare comunque (la guida non richiede questo controllo nell'upgrade)?" N || die "Annullato dall'utente."
  fi
else
  note "Controllo saltato su richiesta."
fi

# =============================================================================
say "Passo 3 - Installazione delle dipendenze NPM (guida: npm install)"
warn "Non eseguire MAI 'npm audit fix': puo' rompere il codice originale (indicazione della guida)."
note "L'installazione puo' richiedere diversi minuti."
printf '%s(btcrpcexplorer)$ npm install%s\n' "$C_B" "$C_R"
as_user 'cd ~/btc-rpc-explorer && npm install'

# =============================================================================
say "Passo 4 - Controllo della versione installata (guida: Check the correct installation)"
printf '%s(btcrpcexplorer)$ head -n 3 /home/btcrpcexplorer/btc-rpc-explorer/package.json | grep version%s\n' "$C_B" "$C_R"
sudo head -n 3 "$BTCEXP_DIR/package.json" | grep version || true
NEWVER="$(sudo grep -m1 '"version"' "$BTCEXP_DIR/package.json" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true)"
printf '%s(btcrpcexplorer)$ exit%s\n' "$C_B" "$C_R"

# =============================================================================
say "Passo 5 - Riavvio del servizio e validazione"
run sudo systemctl start btcrpcexplorer
sleep 5
run sudo systemctl status btcrpcexplorer --no-pager -l || true
printf '%s$ sudo ss -tulpn | grep -E "(:3002|:4000)"%s\n' "$C_B" "$C_R"
sudo ss -tulpn | grep -E '(:3002|:4000)' || warn "Porte 3002/4000 non in ascolto: controlla i log."
printf '%s$ journalctl -u btcrpcexplorer -n 40 --no-pager%s\n' "$C_B" "$C_R"
journalctl -u btcrpcexplorer -n 40 --no-pager || true

say "Completato"
note "BTC RPC Explorer : ${CURVER:-?} (${CURCOMMIT:-?})  ->  ${NEWVER:-?} (${NEWCOMMIT:-?})"
note "Home             : $BTCEXP_DIR"
note "Interfaccia      : http://127.0.0.1:3002  -  https://<nodo>:4000 (nginx)"
echo
if confirm "Vuoi seguire il journal di btcrpcexplorer in tempo reale adesso? (si esce con Ctrl-C)" N; then
  note "Premi Ctrl-C per uscire: a questo punto l'aggiornamento e' gia' completato, quindi un'interruzione non e' un errore."
  trap - ERR
  journalctl -fu btcrpcexplorer || true
  trap on_err ERR
fi
