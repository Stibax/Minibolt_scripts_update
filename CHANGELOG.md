# Changelog

## Non rilasciato (in preparazione per la 1.2)

### Script

- `mb-update-electrs.sh`: **controllo di `rest=1`** quando la versione di destinazione è ≥ 0.12 (motore `bindex`). Se manca, lo script mostra il sintomo nel journal e si ferma **prima di compilare**, invece di lasciare `electrs` in `failed` alla fine. `bitcoin.conf` **non** viene modificato: l'aggiunta e la reindicizzazione restano manuali.

### Documentazione

- `README.md`/`README.en.md`, `SECURITY.md`/`SECURITY.en.md`, `keys/README.md`/`keys/README.en.md`: **un file per lingua** (prima la versione inglese stava in fondo allo stesso file), con il rimando all'altra lingua in prima riga.
- Nuova sezione in **§5**: *perché l'aggiornamento di electrs può fallire* — i due guasti (bindex → `rest=1` + reindicizzazione; `Too many open files` → `LimitNOFILE`), con le versioni **0.11.1 → 0.12.0**, i rimedi, **chi li applica** (lo script o a mano) e le **fonti**. I due callout duplicati in §7 ora rimandano lì.
- **§3**: la chiave pubblica con tre modi di importazione (dal file, dal keyserver, dal solo fingerprint), la chiave aggiunta ai trasferimenti `scp`/`rsync`, la spiegazione di cosa significa `latest`, l'alternativa `wget` e il link copiato col tasto destro dalla release, e il **percorso di estrazione** (`/home/admin/minibolt-update/`) in evidenza.
- Chiarito **cosa fanno gli script da soli e cosa resta da fare a mano**, e spiegato il termine *preflight* (controlli preliminari).
- Tolta dal README la nota sul comportamento con Ctrl-C (dettaglio interno, non utile a chi usa gli script).

### Cambi

- Il file della chiave pubblica passa da `keys/stibax-minibolt.asc` a **`keys/vladx-minibolt.asc`**: il nome segue l'UID `Vladx`. Nella release **1.1** l'asset si chiama ancora `stibax-minibolt.asc`.

## 1.1 — 2026-10-18

Correzioni nate dall'uso reale su un nodo MiniBolt (Ubuntu 22.04) il 2026-10-16.

### Aggiunto

- **`mb-update-electrs.sh` — Passo 0, preflight `LimitNOFILE`**: l'unit
  `electrs.service` della guida **non imposta `LimitNOFILE`**, quindi il limite
  effettivo è il soft di default (1024) mentre RocksDB tiene aperto un file per
  ogni SST (indice reale: ~3.700 file / ~77 GB) → `Too many open files` e
  indicizzazione che si interrompe. Il Passo 0 rileva il caso, spiega perché,
  chiede conferma e crea un drop-in con `LimitNOFILE=65536`. Nel Passo 7 lo
  script verifica ora il **soft limit effettivo** letto da `/proc/<pid>/limits`
  (non il valore di `systemctl show`, che riporta il *hard* limit e nasconde il
  problema).

### Corretto

- **Tutti gli script** — il trap `on_err` classificava un normale **exit 128**
  (per esempio `git` che risponde `fatal: not a git repository`) come
  «terminato da un segnale»: la soglia è passata da `>=128` a `>=129`, e il
  testo non afferma più che lo script è stato interrotto quando invece prosegue.
- **`mb-update-btc-rpc-explorer.sh`** — una nota eseguiva `git rev-parse HEAD`
  e, fuori da un repository, faceva uscire con 128 l'intera sostituzione di
  comando: il testo è ora letterale.
- **`mb-update-electrs.sh`** — la nota sulle porte indicava `50021`/`50022`
  (inesistenti): corrette in `50001` (Electrum RPC) e `50002` (SSL, via nginx).

## 1.0 — 2026-10-02

Prima versione: cinque script (`mb-update.sh`, Bitcoin Core, Electrs, BTC RPC
Explorer, tool di build) con i gate di firma e checksum bloccanti. Usata su un
nodo reale; **mai pubblicata** perché priva del preflight `LimitNOFILE`.
