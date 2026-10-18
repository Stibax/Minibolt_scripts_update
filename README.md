> [!note] 🇬🇧 [English version ↓](#english-version)

# MiniBolt — script di aggiornamento

**Bitcoin Core · Electrs · BTC RPC Explorer · Rustup/Cargo · Node/NPM**

Cinque script bash che aggiornano un nodo [MiniBolt](https://minibolt.minibolt.info) riproducendo **passo per passo** le procedure della guida ufficiale: gli stessi comandi, nello stesso ordine, come se venissero copiati e incollati uno per uno nel terminale — ma con i **controlli di firma e checksum bloccanti**: se una verifica non passa, lo script si ferma e **non installa niente**.

> [!tip] Da dove arriva questo pacchetto
> La distribuzione ufficiale è **questo repository**: ogni versione esce come **release firmata** (firma GPG + `sha256`), e le istruzioni per verificarla sono in **§3** — leggile prima di estrarre l'archivio.
> - Chiave di firma, fingerprint, come segnalare un problema: [`SECURITY.md`](SECURITY.md)
> - Cosa cambia in ogni versione: [`CHANGELOG.md`](CHANGELOG.md)
> - Licenza: [MIT](LICENSE)

> [!warning] Prima di iniziare — leggi qui
> Questi script **installano, compilano e riavviano servizi** sul tuo nodo, con `sudo`.
> - Fai un **backup** (snapshot della VM o immagine del disco) prima di aggiornare. Su un nodo con canali Lightning attivi, valuta anche un backup del wallet.
> - Sono pensati per un nodo installato **seguendo la guida MiniBolt**: se hai cambiato percorsi, utenti o unit systemd, adattali prima.
> - Nessuna garanzia di alcun tipo: sei tu il responsabile del tuo nodo. Se puoi, provali prima su un nodo di test.

---

## 1. Requisiti

| Cosa | Dettaglio |
|---|---|
| Sistema | Ubuntu / Debian, nodo MiniBolt funzionante |
| Utente | **`admin`** con `sudo` (gli script **rifiutano** di girare come root) |
| Servizi | unit systemd `bitcoind`, `electrs`, `btcrpcexplorer` (e `thunderhub` se ce l'hai) |
| Comandi | `bash`, `curl`, `wget`, `gpg`, `git`, `tar`, `sha256sum`, `systemctl` |
| Facoltativo | `ots` (OpenTimestamps) per il timestamp di Bitcoin Core, `tmux` per le compilazioni lunghe |
| Spazio e tempo | qualche GB liberi in `/tmp` e in `/data`; **Electrs 15–30 minuti** di compilazione |

---

## 2. Contenuto del pacchetto

| File | Cosa aggiorna | Sezione della guida |
|---|---|---|
| `mb-update.sh` | **launcher** con menu unico (opzionale: gli altri restano autonomi) | — |
| `mb-update-buildtools.sh` | **Rustup + Cargo**, **Node + NPM** | `/bonus-guides/system/rustup-cargo`, `/bonus-guides/system/nodejs-npm` |
| `mb-update-bitcoin-core.sh` | **Bitcoin Core** (binari precompilati, Option 1) | `/bitcoin/bitcoin/bitcoin-core#option-1-using-precompiled-binaries` |
| `mb-update-electrs.sh` | **Electrs** (compilato dal sorgente, con RocksDB) | `/bonus-guides/bitcoin/electrs` |
| `mb-update-btc-rpc-explorer.sh` | **BTC RPC Explorer** | `/bitcoin/bitcoin/btc-rpc-explorer` |
| `README.md` (questo file) | — | — |
| `LICENSE`, `SECURITY.md`, `CHANGELOG.md` | licenza MIT, note di sicurezza, storico delle versioni | — |
| `keys/stibax-minibolt.asc` | chiave pubblica di firma — comoda da avere accanto all'archivio, ma **da sola non prova niente**: confronta il fingerprint (§3.4) | — |
| `SHA256SUMS.txt` | checksum dei file **dentro** l'archivio, da verificare dopo l'estrazione | — |
| `minibolt-update-scripts-1.1.tar.gz.sha256` | **fuori dall'archivio**: checksum dell'archivio stesso, da verificare **prima** di estrarlo | — |
| `minibolt-update-scripts-1.1.tar.gz.asc` | **fuori dall'archivio**: firma GPG dell'archivio, da verificare **prima** di estrarlo | — |
| `stibax-minibolt.asc` | **fuori dall'archivio**: chiave pubblica di firma (anche in `keys/` nel repository) | — |

---

## 3. Portare gli script sul nodo

Due strade: **scaricare** la release direttamente sul nodo (più semplice — il nodo ha già tutto quello che serve) oppure **trasferire** i file dal tuo PC con `ssh`/`scp`. In entrambi i casi si finisce con gli stessi file in `~`, e la **firma va verificata prima di estrarre** l'archivio.

### 3.1 Scaricare la release direttamente sul nodo

Sul nodo (`ssh admin@nodo`), servono solo `curl` e `gpg`:

```bash
cd ~
curl -fLO https://github.com/Stibax/Minibolt_scripts_update/releases/latest/download/minibolt-update-scripts-1.1.tar.gz
curl -fLO https://github.com/Stibax/Minibolt_scripts_update/releases/latest/download/minibolt-update-scripts-1.1.tar.gz.sha256
curl -fLO https://github.com/Stibax/Minibolt_scripts_update/releases/latest/download/minibolt-update-scripts-1.1.tar.gz.asc
curl -fLO https://github.com/Stibax/Minibolt_scripts_update/releases/latest/download/stibax-minibolt.asc
```

`-f` fa fallire il comando se il file non esiste (invece di salvare una pagina HTML d'errore), `-L` segue i redirect. Per una **versione specifica** sostituisci `latest` con il tag della versione (`.../releases/download/v1.1/...`) e il numero dentro i nomi dei file.

Poi passa a **§3.4** per la verifica.

### 3.2 In alternativa: trasferire i file dal tuo PC (porta 22)

Serve solo `ssh`/`scp` (o `rsync`): nessun altro strumento. Da qui in poi l'esempio usa `admin@nodo` — sostituisci con l'IP o il nome del tuo nodo.

I file da trasferire sono **tre**: l'archivio `minibolt-update-scripts-1.1.tar.gz`, il suo checksum `….sha256` e la firma `….asc`. Nei comandi li indico con `minibolt-update-scripts-1.1.tar.gz*`, così li prende tutti.

```bash
scp minibolt-update-scripts-1.1.tar.gz* admin@nodo:/home/admin/
```

Se preferisci `rsync` (riprende se la connessione cade, mostra il progresso):

```bash
rsync -avP minibolt-update-scripts-1.1.tar.gz* admin@nodo:/home/admin/
```

Con un `~/.ssh/config` di default — la configurazione che va bene per la maggior parte dei casi — diventa ancora più corto:

```sshconfig
Host nodo
    HostName 192.168.1.50      # IP o nome del tuo nodo
    User admin
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

```bash
scp minibolt-update-scripts-1.1.tar.gz* nodo:/home/admin/
rsync -avP minibolt-update-scripts-1.1.tar.gz* nodo:/home/admin/
ssh nodo                                     # per lavorare sul nodo
```

### 3.3 Se la porta SSH non è la 22

Attenzione, sono flag diversi nei due comandi:

```bash
scp -P 2222 minibolt-update-scripts-1.1.tar.gz* admin@nodo:/home/admin/      # -P maiuscola
rsync -avP -e "ssh -p 2222" minibolt-update-scripts-1.1.tar.gz* admin@nodo:/home/admin/
```

In `scp` la porta è **`-P`** (maiuscola); `-p` minuscola significa "preserva i timestamp" e il numero viene interpretato come un file → errore tipo `scp: stat local "2222": No such file or directory`.

### 3.4 Verificare la firma (autenticità)

Questa è la verifica che conta davvero: dice che l'archivio è stato firmato con la chiave privata di chi pubblica il pacchetto. Quella chiave sta su una **smartcard OpenPGP** e non esiste su disco.

```bash
gpg --import stibax-minibolt.asc        # solo la prima volta
gpg --verify minibolt-update-scripts-1.1.tar.gz.asc minibolt-update-scripts-1.1.tar.gz
```

Deve uscire `Good signature from "Vladx <vladx@vladtech.org>"` e, subito dopo, il fingerprint:

```
8CE3 522D 2DDF 1EEE 5349  19A4 476E C750 0847 4F71
```

**Confronta quel fingerprint** con quello pubblicato in [`SECURITY.md`](SECURITY.md), in [`keys/README.md`](keys/README.md) e su [keys.openpgp.org](https://keys.openpgp.org/search?q=8CE3522D2DDF1EEE534919A4476EC75008474F71). Se non coincide, **non estrarre niente**.

> [!note] `WARNING: This key is not certified with a trusted signature` è normale
> `gpg` sta dicendo che *non ha verificato da solo* l'identità di quella chiave — non che la firma è falsa (`Good signature` è già passato). Quella verifica la fai tu, confrontando il fingerprint su un canale diverso da quello da cui hai scaricato l'archivio.

### 3.5 Verificare che l'archivio sia integro (prima di estrarlo)

Sul nodo, controlla che l'archivio sia arrivato intero confrontandolo con il suo `.sha256`:

```bash
ssh admin@nodo
cd ~
sha256sum -c minibolt-update-scripts-1.1.tar.gz.sha256
# minibolt-update-scripts-1.1.tar.gz: OK
```

- `OK` → l'archivio è integro, prosegui.
- `FAILED` o `No such file or directory` → il trasferimento è incompleto o corrotto: **ritrasferisci** (entrambi i file) e ripeti.
- Confronta comunque l'hash con quello **pubblicato da chi ti ha dato il pacchetto** (nel messaggio, nella pagina di rilascio, nel README): così verifichi anche di aver ricevuto il file giusto e non una copia diversa.

> [!note] Cosa protegge (e cosa no) questo controllo
> Il `.sha256` serve a scoprire un **trasferimento andato storto** o un archivio modificato per errore. **Non** prova l'autenticità del pacchetto: chi può alterare l'archivio può alterare anche il suo `.sha256`. Per quello serve una **firma** di chi distribuisce (`gpg --verify`, se chi te lo passa la fornisce). Verifica sempre l'hash che ti è stato comunicato per un canale diverso da quello con cui hai scaricato l'archivio.

### 3.6 Estrarre e verificare i file

```bash
tar xzf minibolt-update-scripts-1.1.tar.gz          # crea la cartella minibolt-update/
cd minibolt-update
chmod +x *.sh
sha256sum -c SHA256SUMS.txt                         # tutte le righe devono dire OK
```

Qui si controllano i **singoli file** dentro l'archivio (`SHA256SUMS.txt` è il manifest interno). Se una riga dice `FAILED`, il file è corrotto: riestrai da un archivio appena ritrasferito e ripeti.

> [!warning] Non incollare il testo degli script nella shell
> Le righe lunghe si spezzano nel copia/incolla e producono errori assurdi tipo `line 201: 201: command not found`. Trasferisci sempre i **file** (o l'archivio) e verifica con `sha256sum -c`.

---

## 4. Usare gli script

```bash
~/minibolt-update/mb-update.sh
```

Si apre un menu:

```
  1) Tool di build   (Rustup + Cargo, Node + NPM)
  2) Bitcoin Core    (binari precompilati, con verifica firma/checksum/timestamp)
  3) Electrs         (compilazione dal sorgente, firma git del tag)
  4) BTC RPC Explorer (git fetch/reset + npm install)
  5) Tutti in sequenza: 1 -> 2 -> 3 -> 4
  q) Esci
```

Ogni script è **autonomo**: puoi anche lanciarne uno solo.

```bash
~/minibolt-update/mb-update-bitcoin-core.sh
~/minibolt-update/mb-update-electrs.sh
```

Regole d'uso:

- **Mai come root e mai con `sudo` davanti**: gli script rifiutano di partire da root e chiedono loro quello che serve con `sudo -v` (una volta sola, tenendo viva la sessione per tutta la durata).
- **Ordine consigliato** per un aggiornamento completo: tool di build → Bitcoin Core → Electrs → BTC RPC Explorer.
- **Electrs in `tmux`**: compila RocksDB e Rust, 15–30 minuti.
- La **versione da installare viene sempre chiesta**, con il default proposto (ultima release pubblicata). Per Bitcoin Core lo script verifica che i file esistano davvero su `bitcoincore.org` prima di scaricare.
- Volendo, il launcher si può mettere nel `PATH`:
  ```bash
  sudo ln -s /home/admin/minibolt-update/mb-update.sh /usr/local/bin/mb-update
  ```
  Il launcher trova i suoi file anche da symlink (usa `readlink -f`), quindi dopo basta scrivere `mb-update` da qualsiasi cartella.

---

## 5. Cosa fa ogni script

### Tool di build (`mb-update-buildtools.sh`)

- **Rustup + Cargo**: `rustup update`, oppure installazione da zero (profilo `minimal`) se mancano.
- **Node + NPM**: dal repository ufficiale **NodeSource**, con la major **chiesta** (default: ultima LTS). Per l'upgrade di major (es. 20 → 22) usa il percorso completo della guida.
- Prima dell'upgrade di Node **ferma** `btcrpcexplorer` e `thunderhub`, e li **riavvia** alla fine.
- Ti mostra le versioni finali di `rustc`, `cargo`, `node`, `npm`.

### Bitcoin Core (`mb-update-bitcoin-core.sh`)

1. Scarica dalla versione scelta: tarball dei binari, `SHA256SUMS`, `SHA256SUMS.asc`, `SHA256SUMS.ots`.
2. **Signature check**: importa le chiavi dei builder da `bitcoin-core/guix.sigs` e verifica con `gpg --verify` le firme del file dei checksum (attende almeno una firma valida).
3. **Checksum check**: `sha256sum --ignore-missing --check SHA256SUMS` sul tarball scaricato.
4. **Timestamp check**: OpenTimestamps (`ots verify`) — se è "Pending confirmation" chiede conferma esplicita (la guida stessa ammette di poter procedere).
5. Estrae i binari, li installa in `/usr/local/bin`, riavvia `bitcoind` e verifica la versione via `bitcoin-cli`.
6. Offre (con conferma) una copia di sicurezza dei binari precedenti e la pulizia di `/tmp`.

### Electrs (`mb-update-electrs.sh`)

1. **Preflight `LimitNOFILE`** (nuovo in 1.1): l'unit `electrs.service` della guida **non** imposta il limite dei file aperti, quindi il processo eredita il soft limit di default (1024) mentre RocksDB tiene aperto un file per ogni SST dell'indice (migliaia) → `Too many open files` e indicizzazione interrotta. Se il drop-in manca, lo script spiega il problema, chiede conferma e lo crea (`LimitNOFILE=65536`).
2. Preflight: `rustup`/`cargo` presenti, `git`, `curl`, `systemctl`; dipendenze di sistema via `apt`.
3. Ricompila **librocksdb** dal sorgente (tag indicato dalla guida; compilazione lunga).
4. Clona il tag di Electrs scelto, crea `allowed_signers` e verifica la **firma git** della release con `git verify-tag -v`.
5. `cargo build --locked --release`, installa il binario in `/usr/local/bin`, riavvia `electrs` e offre il journal. Alla fine legge il **soft limit effettivo** da `/proc/<pid>/limits` — non da `systemctl show`, che stampa il *hard* limit e nasconde il problema.

### BTC RPC Explorer (`mb-update-btc-rpc-explorer.sh`)

- Come utente `btcrpcexplorer`: stop del servizio, `git fetch` + `git reset --hard origin/<branch>` + `git clean -fd` (oppure checkout di un **tag/commit pinnato**), `npm install`, lettura della versione da `package.json`, restart del servizio.
- **Non** esegue mai `npm audit fix` (lo dice la guida: può rompere il codice).
- **Dove cerca l'installazione.** Il percorso previsto dalla guida è `/home/btcrpcexplorer/btc-rpc-explorer`. Se lì non trova un repository git, lo script **non si ferma**: prova a dedurre la cartella dalla unit systemd `btcrpcexplorer` (prima `WorkingDirectory`, poi il percorso presente nell'`ExecStart`) e, se non basta, cerca una cartella `btc-rpc-explorer` in `/home`, `/opt`, `/srv`, `/usr/local`. Quando la trova altrove te lo dice (`Installazione trovata qui: …`) e prosegue.
- **I controlli sul repository girano come root** (`sudo`, già attivo nello script): la home di `btcrpcexplorer` è tipicamente `drwxr-x---`, quindi tu che sei `admin` non puoi nemmeno attraversarla e un controllo fatto senza `sudo` **direbbe che il repository non esiste** pur essendoci. Se il tuo `sudo ls -la` mostra l'installazione ma lo script non la trova, il sospetto numero uno è questo (le versioni dello script precedenti a questa avevano esattamente quel difetto).
- **Installazione in un percorso diverso** (o non rilevata): indicala tu.

  ```bash
  ./mb-update-btc-rpc-explorer.sh /percorso/btc-rpc-explorer              # come argomento
  MB_BTCEXP_DIR=/percorso/btc-rpc-explorer ./mb-update-btc-rpc-explorer.sh # come variabile
  ```

- Se non trova nulla, il messaggio d'errore stampa i comandi per capire cosa c'è sul nodo. Tieni presente che **questo script aggiorna, non installa**: se BTC RPC Explorer non è mai stato installato (o gira in un container Docker), va prima installato seguendo la guida.

---

## 6. Sicurezza e password

- **Nessun controllo viene saltato in silenzio.** Se `sha256sum`, `gpg --verify` o `git verify-tag` falliscono, lo script stampa `STOP` e non installa nulla (exit code ≠ 0). L'unica deroga è il timestamp OpenTimestamps "Pending confirmation", con conferma esplicita.
- Dove la guida **non** prevede un controllo (RocksDB, upgrade di BTC RPC Explorer) lo script lo dichiara a video.
- **Le password non vengono mai salvate**: né su disco, né in file di log, né nella history, né in variabili d'ambiente. Non viene usato `sudo -S` né alcuna pipe con la password: l'autenticazione passa dal prompt nativo di `sudo`.
- Gli script **non** modificano la tua configurazione: `bitcoin.conf`, `electrs.conf`, `.env` e le unit systemd restano come sono. Non toccano le directory dati (a parte quelle di build).
- Un **Ctrl-C** (tipico sull'ultimo `journalctl -fu`) viene segnalato come `Terminato da un segnale (exit 130)`, **non** come errore: quello che era già stato fatto resta valido e puoi rilanciare lo stesso script.
- **Anche il repository è blindato**, non solo il pacchetto: release immutabili, tag firmati obbligatori e non spostabili, nessuna automazione. È il motivo per cui una release già scaricata non può cambiare sotto i piedi — dettagli in [`SECURITY.md`](SECURITY.md) §«Postura di sicurezza del repository».

---

## 7. Gotcha e domande frequenti

> [!warning] Electrs 0.12 richiede `rest=1` su bitcoind e una reindicizzazione
> Electrs **0.12.0** è passato al motore `bindex`, che (1) richiede **Bitcoin Core 31+**, (2) usa l'interfaccia **REST** di bitcoind → serve **`rest=1`** in `bitcoin.conf`, e (3) ha un **nuovo formato di indice → va reindicizzato**.
> Sintomo se manca `rest=1`: `GET http://127.0.0.1:8332/rest/blockhashbyheight/0.bin failed: StatusCode(404)` → `failed to open index` → servizio in `failed`. Con la 0.11.x questo non succedeva, perché il REST non veniva usato.

Come procedere in quel caso:

```bash
sudo cp /data/bitcoin/bitcoin.conf /data/bitcoin/bitcoin.conf.bak-$(date +%F)
sudo nano /data/bitcoin/bitcoin.conf         # aggiungi:  rest=1
sudo systemctl restart bitcoind
curl -s http://127.0.0.1:8332/rest/blockhashbyheight/0.bin | xxd -p -c 32   # deve dare l'hash del blocco genesi
sudo systemctl stop electrs
sudo mv /data/electrs/db /data/electrs/db.electrs-0.11-$(date +%F)          # nuovo formato: accantona il vecchio
sudo systemctl start electrs                 # parte la reindicizzazione (ore)
journalctl -fu electrs
```

Finché l'indice non è completo, wallet e explorer danno errori su saldi e indirizzi: è normale. Il vecchio indice accantonato è spazio da recuperare **dopo** che la nuova indicizzazione è arrivata in fondo.

> [!warning] `electrs` muore con `Too many open files` durante l'indicizzazione
> Il soft limit dei file aperti è **1024**, ma RocksDB (`max_open_files=-1`) tiene aperto **un file per ogni SST** dell'indice — su un indice reale sono migliaia (≈3.700 file / ≈77 GB nel caso che ha originato questo preflight). Il processo esaurisce i descrittori e si ferma. La unit della guida non imposta `LimitNOFILE`, quindi il limite effettivo resta il default. Rimedio (una volta sola):
>
> ```bash
> sudo mkdir -p /etc/systemd/system/electrs.service.d
> printf '[Service]\nLimitNOFILE=65536\n' | sudo tee /etc/systemd/system/electrs.service.d/10-nofile.conf
> sudo systemctl daemon-reload
> sudo systemctl restart electrs
> ```
>
> **Occhio a come lo verifichi**: `systemctl show -p LimitNOFILE electrs` stampa il **hard** limit (spesso 524288) e sembra tutto a posto anche quando il problema c'è. Il valore che conta è quello del processo:
>
> ```bash
> sudo grep -i 'open files' /proc/$(systemctl show -p MainPID --value electrs)/limits   # prima colonna = soft
> ```
>
> Dallo script 1.1 questo controllo (drop-in + soft limit effettivo) è un passo dello script stesso.

**Il nodo si è riavviato ma la versione è vecchia?** Controlla il *daemon*, non solo il client: `bitcoin-cli getnetworkinfo | grep -i subversion` deve mostrare la nuova versione.

**`Repository git non trovato in /home/btcrpcexplorer/btc-rpc-explorer`?** L'utente `btcrpcexplorer` esiste ma il repository non risulta. Due cause, in ordine di frequenza: **(a)** la home dell'utente è `drwxr-x---` e i controlli fatti come `admin` non la attraversano — questo script fa le sonde con `sudo`, quindi aggiornalo se hai una versione vecchia; **(b)** l'installazione è davvero altrove, oppure non è un repository git (installata da archivio). Verifica con `sudo test -d /home/btcrpcexplorer/btc-rpc-explorer/.git && echo "repo git OK"` e guarda da dove parte il servizio: `systemctl cat btcrpcexplorer | grep -E 'ExecStart|WorkingDirectory'`. Lo script cerca da solo (unit systemd, poi i percorsi tipici) e, se l'installazione è altrove, passala come argomento (`./mb-update-btc-rpc-explorer.sh /percorso/btc-rpc-explorer`). Se il servizio non esiste affatto, l'explorer non è installato (o gira in un container): va prima installato dalla guida.

**`electrs`/`btcrpcexplorer` non riparte dopo l'upgrade di Node?** Quel passaggio ferma e riavvia i due servizi: i log sono in `journalctl -fu electrs` / `-fu btcrpcexplorer`.

**Durante la compilazione di Electrs il nodo è lento?** È normale: usa tutti i core. Evita di lanciare in parallelo il launcher per Node/NPM (fermerebbe e riavvierebbe gli stessi servizi).

**Disco pieno a metà indice?** Tieni d'occhio `df -h /data`: un disco pieno fa fallire Electrs con un errore poco chiaro.

---

## 8. Verifica dopo l'aggiornamento

```bash
bitcoin-cli getnetworkinfo | grep -i subversion          # versione del daemon Bitcoin Core
bitcoin-cli getblockchaininfo | grep -E '"blocks"|"headers"|verificationprogress'
systemctl is-active bitcoind electrs btcrpcexplorer
journalctl -fu electrs                                    # indicizzazione / stato
```

---

## 9. Stato dei test e limiti dichiarati

- Sintassi verificata (`bash -n`) su tutti i file; flusso completo provato in **sandbox** con stub di `sudo`, `systemctl`, `apt`, `gpg`, `git`, `wget`: ogni script arriva in fondo con exit 0.
- **Gate provati su release reali**: checksum di Bitcoin Core (`…tar.gz: OK`), firma GPG del file `SHA256SUMS` (chiavi dei builder importate, firme `Good`), `git verify-tag` della release di Electrs (`Good "git" signature`).
- **Test negativi**: con un `SHA256SUMS` alterato lo script si ferma con `STOP. Il file scaricato non coincide con il riferimento ufficiale`; con una firma GPG contraffatta `STOP. Non installare binari la cui firma non e' verificata`. In entrambi i casi nessuna installazione.
- **Preflight `LimitNOFILE`** (1.1) provato in sandbox nei tre casi: drop-in assente + risposta «no» (non crea niente), drop-in assente + «sì» (crea il file con il contenuto atteso), drop-in già presente (lo riconosce e non lo tocca).
- **1.1 nasce dall'uso su un nodo reale**: gli script sono stati eseguiti su un MiniBolt (Ubuntu 22.04) il 2026-10-16; le correzioni di questa versione vengono da lì (vedi [`CHANGELOG.md`](CHANGELOG.md)).
- **Non testati automaticamente** (dipendono dal tuo nodo): i passi che toccano il sistema — `apt install`, `sudo install`, `systemctl restart`, compilazione di RocksDB — vanno eseguiti e osservati sul nodo. Le versioni proposte come default cambiano nel tempo: lo script chiede sempre conferma prima di scaricare.

---

Licenza [MIT](LICENSE). Nessuna garanzia. Le procedure riprodotte sono quelle della guida [MiniBolt](https://minibolt.minibolt.info) — se la guida cambia, gli script vanno riallineati.
---

## English version

# MiniBolt — update scripts

**Bitcoin Core · Electrs · BTC RPC Explorer · Rustup/Cargo · Node/NPM**

Five bash scripts that update a [MiniBolt](https://minibolt.minibolt.info) node by reproducing **step by step** the procedures of the official guide: the same commands, in the same order, as if they were copied and pasted one by one into the terminal — but with **blocking signature and checksum checks**: if a verification does not pass, the script stops and **installs nothing**.

> [!tip] Where this package comes from
> The official distribution channel is **this repository**: every version ships as a **signed release** (GPG signature + `sha256`), and the instructions to verify it are in **§3** — read them before extracting the archive.
> - Signing key, fingerprint, how to report a problem: [`SECURITY.md`](SECURITY.md)
> - What changes in each version: [`CHANGELOG.md`](CHANGELOG.md)
> - License: [MIT](LICENSE)

> [!warning] Before you start — read this
> These scripts **install, compile and restart services** on your node, with `sudo`.
> - Make a **backup** (VM snapshot or disk image) before updating. On a node with active Lightning channels, consider a wallet backup as well.
> - They are meant for a node installed **following the MiniBolt guide**: if you changed paths, users or systemd units, adapt them first.
> - No warranty of any kind: your node is your responsibility. If you can, try them on a test node first.

---

## 1. Requirements

| Item | Detail |
|---|---|
| System | Ubuntu / Debian, a working MiniBolt node |
| User | **`admin`** with `sudo` (the scripts **refuse** to run as root) |
| Services | systemd units `bitcoind`, `electrs`, `btcrpcexplorer` (and `thunderhub` if you have it) |
| Commands | `bash`, `curl`, `wget`, `gpg`, `git`, `tar`, `sha256sum`, `systemctl` |
| Optional | `ots` (OpenTimestamps) for the Bitcoin Core timestamp, `tmux` for long builds |
| Space and time | a few GB free in `/tmp` and in `/data`; **Electrs 15–30 minutes** of compilation |

---

## 2. Package contents

| File | What it updates | Guide section |
|---|---|---|
| `mb-update.sh` | **launcher** with a single menu (optional: the others stay standalone) | — |
| `mb-update-buildtools.sh` | **Rustup + Cargo**, **Node + NPM** | `/bonus-guides/system/rustup-cargo`, `/bonus-guides/system/nodejs-npm` |
| `mb-update-bitcoin-core.sh` | **Bitcoin Core** (precompiled binaries, Option 1) | `/bitcoin/bitcoin/bitcoin-core#option-1-using-precompiled-binaries` |
| `mb-update-electrs.sh` | **Electrs** (compiled from source, with RocksDB) | `/bonus-guides/bitcoin/electrs` |
| `mb-update-btc-rpc-explorer.sh` | **BTC RPC Explorer** | `/bitcoin/bitcoin/btc-rpc-explorer` |
| `README.md` (this file) | — | — |
| `LICENSE`, `SECURITY.md`, `CHANGELOG.md` | MIT license, security notes, version history | — |
| `keys/stibax-minibolt.asc` | public signing key — handy to keep next to the archive, but **on its own it proves nothing**: compare the fingerprint (§3.4) | — |
| `SHA256SUMS.txt` | checksums of the files **inside** the archive, to verify after extraction | — |
| `minibolt-update-scripts-1.1.tar.gz.sha256` | **outside the archive**: checksum of the archive itself, to verify **before** extracting it | — |
| `minibolt-update-scripts-1.1.tar.gz.asc` | **outside the archive**: GPG signature of the archive, to verify **before** extracting it | — |
| `stibax-minibolt.asc` | **outside the archive**: public signing key (also in `keys/` in the repository) | — |

---

## 3. Getting the scripts onto the node

Two routes: **download** the release directly on the node (simpler — the node already has everything it needs) or **transfer** the files from your PC with `ssh`/`scp`. Either way you end up with the same files in `~`, and the **signature must be verified before extracting** the archive.

### 3.1 Downloading the release directly on the node

On the node (`ssh admin@nodo`) you only need `curl` and `gpg`:

```bash
cd ~
curl -fLO https://github.com/Stibax/Minibolt_scripts_update/releases/latest/download/minibolt-update-scripts-1.1.tar.gz
curl -fLO https://github.com/Stibax/Minibolt_scripts_update/releases/latest/download/minibolt-update-scripts-1.1.tar.gz.sha256
curl -fLO https://github.com/Stibax/Minibolt_scripts_update/releases/latest/download/minibolt-update-scripts-1.1.tar.gz.asc
curl -fLO https://github.com/Stibax/Minibolt_scripts_update/releases/latest/download/stibax-minibolt.asc
```

`-f` makes the command fail if the file does not exist (instead of saving an HTML error page), `-L` follows redirects. For a **specific version**, replace `latest` with the version tag (`.../releases/download/v1.1/...`) and the number inside the file names.

Then go to **§3.4** for the verification.

### 3.2 Alternatively: transfer the files from your PC (port 22)

You only need `ssh`/`scp` (or `rsync`): no other tool. From here on the example uses `admin@nodo` — replace it with the IP or the hostname of your node.

There are **three** files to transfer: the archive `minibolt-update-scripts-1.1.tar.gz`, its checksum `….sha256` and the signature `….asc`. In the commands I refer to them as `minibolt-update-scripts-1.1.tar.gz*`, so all of them are picked up.

```bash
scp minibolt-update-scripts-1.1.tar.gz* admin@nodo:/home/admin/
```

If you prefer `rsync` (it resumes if the connection drops, it shows the progress):

```bash
rsync -avP minibolt-update-scripts-1.1.tar.gz* admin@nodo:/home/admin/
```

With a default `~/.ssh/config` — the configuration that works for most cases — it gets even shorter:

```sshconfig
Host nodo
    HostName 192.168.1.50      # IP o nome del tuo nodo
    User admin
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

```bash
scp minibolt-update-scripts-1.1.tar.gz* nodo:/home/admin/
rsync -avP minibolt-update-scripts-1.1.tar.gz* nodo:/home/admin/
ssh nodo                                     # per lavorare sul nodo
```

### 3.3 If the SSH port is not 22

Careful, they are different flags in the two commands:

```bash
scp -P 2222 minibolt-update-scripts-1.1.tar.gz* admin@nodo:/home/admin/      # -P maiuscola
rsync -avP -e "ssh -p 2222" minibolt-update-scripts-1.1.tar.gz* admin@nodo:/home/admin/
```

In `scp` the port flag is **`-P`** (uppercase); lowercase `-p` means "preserve the timestamps" and the number is interpreted as a file → an error like `scp: stat local "2222": No such file or directory`.

### 3.4 Verifying the signature (authenticity)

This is the check that really counts: it says that the archive was signed with the private key of whoever publishes the package. That key lives on an **OpenPGP smartcard** and does not exist on disk.

```bash
gpg --import stibax-minibolt.asc        # solo la prima volta
gpg --verify minibolt-update-scripts-1.1.tar.gz.asc minibolt-update-scripts-1.1.tar.gz
```

You must see `Good signature from "Vladx <vladx@vladtech.org>"` and, right after it, the fingerprint:

```
8CE3 522D 2DDF 1EEE 5349  19A4 476E C750 0847 4F71
```

**Compare that fingerprint** with the one published in [`SECURITY.md`](SECURITY.md), in [`keys/README.md`](keys/README.md) and on [keys.openpgp.org](https://keys.openpgp.org/search?q=8CE3522D2DDF1EEE534919A4476EC75008474F71). If it does not match, **do not extract anything**.

> [!note] `WARNING: This key is not certified with a trusted signature` is normal
> `gpg` is saying that it has *not verified on its own* the identity of that key — not that the signature is fake (`Good signature` has already passed). That verification is up to you, comparing the fingerprint over a channel other than the one you downloaded the archive from.

### 3.5 Verifying that the archive is intact (before extracting it)

On the node, check that the archive arrived whole by comparing it with its `.sha256`:

```bash
ssh admin@nodo
cd ~
sha256sum -c minibolt-update-scripts-1.1.tar.gz.sha256
# minibolt-update-scripts-1.1.tar.gz: OK
```

- `OK` → the archive is intact, continue.
- `FAILED` or `No such file or directory` → the transfer is incomplete or corrupted: **transfer it again** (both files) and repeat.
- In any case, compare the hash with the one **published by whoever gave you the package** (in the message, on the release page, in the README): that way you also verify that you received the right file and not a different copy.

> [!note] What this check protects against (and what it does not)
> The `.sha256` is there to catch a **transfer that went wrong** or an archive modified by mistake. It does **not** prove the authenticity of the package: whoever can alter the archive can alter its `.sha256` too. That requires a **signature** from whoever distributes it (`gpg --verify`, if whoever hands it to you provides one). Always verify the hash you were given over a channel other than the one you downloaded the archive from.

### 3.6 Extracting and verifying the files

```bash
tar xzf minibolt-update-scripts-1.1.tar.gz          # crea la cartella minibolt-update/
cd minibolt-update
chmod +x *.sh
sha256sum -c SHA256SUMS.txt                         # tutte le righe devono dire OK
```

Here you check the **individual files** inside the archive (`SHA256SUMS.txt` is the internal manifest). If a line says `FAILED`, that file is corrupted: extract again from an archive you have just transferred again and repeat.

> [!warning] Do not paste the script text into the shell
> Long lines get broken in the copy/paste and produce nonsense errors like `line 201: 201: command not found`. Always transfer the **files** (or the archive) and verify with `sha256sum -c`.

---

## 4. Using the scripts

```bash
~/minibolt-update/mb-update.sh
```

A menu opens:

```
  1) Tool di build   (Rustup + Cargo, Node + NPM)
  2) Bitcoin Core    (binari precompilati, con verifica firma/checksum/timestamp)
  3) Electrs         (compilazione dal sorgente, firma git del tag)
  4) BTC RPC Explorer (git fetch/reset + npm install)
  5) Tutti in sequenza: 1 -> 2 -> 3 -> 4
  q) Esci
```

Every script is **standalone**: you can also run just one of them.

```bash
~/minibolt-update/mb-update-bitcoin-core.sh
~/minibolt-update/mb-update-electrs.sh
```

Usage rules:

- **Never as root and never with `sudo` in front**: the scripts refuse to start as root and ask for what they need themselves with `sudo -v` (once only, keeping the session alive for the whole run).
- **Recommended order** for a full update: build tools → Bitcoin Core → Electrs → BTC RPC Explorer.
- **Electrs in `tmux`**: it compiles RocksDB and Rust, 15–30 minutes.
- **The version to install is always requested**, with the default offered (latest published release). For Bitcoin Core the script checks that the files really exist on `bitcoincore.org` before downloading.
- If you want, the launcher can be put in the `PATH`:
  ```bash
  sudo ln -s /home/admin/minibolt-update/mb-update.sh /usr/local/bin/mb-update
  ```
  The launcher finds its files even through a symlink (it uses `readlink -f`), so after that you just type `mb-update` from any directory.

---

## 5. What each script does

### Build tools (`mb-update-buildtools.sh`)

- **Rustup + Cargo**: `rustup update`, or an installation from scratch (`minimal` profile) if they are missing.
- **Node + NPM**: from the official **NodeSource** repository, with the major version **requested at the prompt** (default: latest LTS). For the major upgrade (e.g. 20 → 22) it uses the full path of the guide.
- Before the Node upgrade it **stops** `btcrpcexplorer` and `thunderhub`, and **restarts** them at the end.
- It shows you the final versions of `rustc`, `cargo`, `node`, `npm`.

### Bitcoin Core (`mb-update-bitcoin-core.sh`)

1. Downloads, for the chosen version: the binaries tarball, `SHA256SUMS`, `SHA256SUMS.asc`, `SHA256SUMS.ots`.
2. **Signature check**: imports the builder keys from `bitcoin-core/guix.sigs` and verifies with `gpg --verify` the signatures on the checksum file (waits for at least one valid signature).
3. **Checksum check**: `sha256sum --ignore-missing --check SHA256SUMS` on the downloaded tarball.
4. **Timestamp check**: OpenTimestamps (`ots verify`) — if it is "Pending confirmation" it asks for explicit confirmation (the guide itself admits you can proceed).
5. Extracts the binaries, installs them in `/usr/local/bin`, restarts `bitcoind` and verifies the version via `bitcoin-cli`.
6. Offers (with confirmation) a safety copy of the previous binaries and the cleanup of `/tmp`.

### Electrs (`mb-update-electrs.sh`)

1. **`LimitNOFILE` preflight** (new in 1.1): the `electrs.service` unit of the guide does **not** set the open-file limit, so the process inherits the default soft limit (1024) while RocksDB keeps one file open for every SST of the index (thousands) → `Too many open files` and indexing aborted. If the drop-in is missing, the script explains the problem, asks for confirmation and creates it (`LimitNOFILE=65536`).
2. Preflight: `rustup`/`cargo` present, `git`, `curl`, `systemctl`; system dependencies via `apt`.
3. Recompiles **librocksdb** from source (tag given in the guide; long compilation).
4. Clones the chosen Electrs tag, creates `allowed_signers` and verifies the **git signature** of the release with `git verify-tag -v`.
5. `cargo build --locked --release`, installs the binary in `/usr/local/bin`, restarts `electrs` and offers the journal. At the end it reads the **effective soft limit** from `/proc/<pid>/limits` — not from `systemctl show`, which prints the *hard* limit and hides the problem.

### BTC RPC Explorer (`mb-update-btc-rpc-explorer.sh`)

- As user `btcrpcexplorer`: stop of the service, `git fetch` + `git reset --hard origin/<branch>` + `git clean -fd` (or checkout of a **pinned tag/commit**), `npm install`, read of the version from `package.json`, restart of the service.
- It **never** runs `npm audit fix` (the guide says so: it can break the code).
- **Where it looks for the installation.** The path the guide expects is `/home/btcrpcexplorer/btc-rpc-explorer`. If it does not find a git repository there, the script **does not stop**: it tries to infer the directory from the `btcrpcexplorer` systemd unit (first `WorkingDirectory`, then the path present in `ExecStart`) and, if that is not enough, it searches for a `btc-rpc-explorer` directory in `/home`, `/opt`, `/srv`, `/usr/local`. When it finds it elsewhere it tells you (`Installazione trovata qui: …`) and continues.
- **The checks on the repository run as root** (`sudo`, already active in the script): the home of `btcrpcexplorer` is typically `drwxr-x---`, so you as `admin` cannot even traverse it and a check made without `sudo` **would say that the repository does not exist** although it is there. If your `sudo ls -la` shows the installation but the script does not find it, this is suspect number one (script versions before this one had exactly that defect).
- **Installation in a different path** (or not detected): point it out yourself.

  ```bash
  ./mb-update-btc-rpc-explorer.sh /percorso/btc-rpc-explorer              # come argomento
  MB_BTCEXP_DIR=/percorso/btc-rpc-explorer ./mb-update-btc-rpc-explorer.sh # come variabile
  ```

- If it finds nothing, the error message prints the commands to understand what is on the node. Keep in mind that **this script updates, it does not install**: if BTC RPC Explorer was never installed (or runs in a Docker container), install it first following the guide.

---

## 6. Security and passwords

- **No check is skipped silently.** If `sha256sum`, `gpg --verify` or `git verify-tag` fail, the script prints `STOP` and installs nothing (exit code ≠ 0). The only exception is the OpenTimestamps "Pending confirmation" timestamp, with explicit confirmation.
- Where the guide does **not** provide a check (RocksDB, BTC RPC Explorer upgrade) the script says so on screen.
- **Passwords are never stored**: neither on disk, nor in log files, nor in the history, nor in environment variables. Neither `sudo -S` nor any pipe with the password is used: authentication goes through the native prompt of `sudo`.
- The scripts do **not** modify your configuration: `bitcoin.conf`, `electrs.conf`, `.env` and the systemd units stay as they are. They do not touch the data directories (apart from the build ones).
- A **Ctrl-C** (typical on the final `journalctl -fu`) is reported as `Terminato da un segnale (exit 130)`, **not** as an error: what was already done remains valid and you can re-run the same script.
- **The repository is locked down too**, not only the package: immutable releases, mandatory signed tags that cannot be moved, no automation. That is why a release you have already downloaded cannot change under your feet — details in [`SECURITY.md`](SECURITY.md) §"Repository security posture".

---

## 7. Gotchas and FAQ

> [!warning] Electrs 0.12 requires `rest=1` on bitcoind and a reindex
> Electrs **0.12.0** moved to the `bindex` engine, which (1) requires **Bitcoin Core 31+**, (2) uses the **REST** interface of bitcoind → you need **`rest=1`** in `bitcoin.conf`, and (3) has a **new index format → it must be reindexed**.
> Symptom when `rest=1` is missing: `GET http://127.0.0.1:8332/rest/blockhashbyheight/0.bin failed: StatusCode(404)` → `failed to open index` → service in `failed`. With 0.11.x this did not happen, because REST was not used.

How to proceed in that case:

```bash
sudo cp /data/bitcoin/bitcoin.conf /data/bitcoin/bitcoin.conf.bak-$(date +%F)
sudo nano /data/bitcoin/bitcoin.conf         # aggiungi:  rest=1
sudo systemctl restart bitcoind
curl -s http://127.0.0.1:8332/rest/blockhashbyheight/0.bin | xxd -p -c 32   # deve dare l'hash del blocco genesi
sudo systemctl stop electrs
sudo mv /data/electrs/db /data/electrs/db.electrs-0.11-$(date +%F)          # nuovo formato: accantona il vecchio
sudo systemctl start electrs                 # parte la reindicizzazione (ore)
journalctl -fu electrs
```

Until the index is complete, wallets and explorers throw errors on balances and addresses: that is normal. The old index you set aside is space to reclaim **after** the new indexing has reached the end.

> [!warning] `electrs` dies with `Too many open files` during indexing
> The soft limit on open files is **1024**, but RocksDB (`max_open_files=-1`) keeps **one file open for every SST** of the index — on a real index that is thousands (≈3,700 files / ≈77 GB in the case that gave rise to this preflight). The process runs out of descriptors and stops. The unit of the guide does not set `LimitNOFILE`, so the effective limit stays at the default. Remedy (once only):
>
> ```bash
> sudo mkdir -p /etc/systemd/system/electrs.service.d
> printf '[Service]\nLimitNOFILE=65536\n' | sudo tee /etc/systemd/system/electrs.service.d/10-nofile.conf
> sudo systemctl daemon-reload
> sudo systemctl restart electrs
> ```
>
> **Watch out how you verify it**: `systemctl show -p LimitNOFILE electrs` prints the **hard** limit (often 524288) and looks all right even when the problem is there. The value that counts is the one of the process:
>
> ```bash
> sudo grep -i 'open files' /proc/$(systemctl show -p MainPID --value electrs)/limits   # prima colonna = soft
> ```
>
> Since script 1.1 this check (drop-in + effective soft limit) is a step of the script itself.

**The node rebooted but the version is old?** Check the *daemon*, not only the client: `bitcoin-cli getnetworkinfo | grep -i subversion` must show the new version.

**`Repository git non trovato in /home/btcrpcexplorer/btc-rpc-explorer`?** The `btcrpcexplorer` user exists but the repository is not found. Two causes, in order of frequency: **(a)** the home of the user is `drwxr-x---` and the checks made as `admin` do not traverse it — this script does its probes with `sudo`, so update it if you have an old version; **(b)** the installation really is elsewhere, or it is not a git repository (installed from an archive). Check with `sudo test -d /home/btcrpcexplorer/btc-rpc-explorer/.git && echo "repo git OK"` and look at where the service starts from: `systemctl cat btcrpcexplorer | grep -E 'ExecStart|WorkingDirectory'`. The script searches by itself (systemd unit, then the typical paths) and, if the installation is elsewhere, pass it as an argument (`./mb-update-btc-rpc-explorer.sh /percorso/btc-rpc-explorer`). If the service does not exist at all, the explorer is not installed (or runs in a container): it must be installed from the guide first.

**`electrs`/`btcrpcexplorer` does not restart after the Node upgrade?** That step stops and restarts both services: the logs are in `journalctl -fu electrs` / `-fu btcrpcexplorer`.

**Is the node slow while Electrs compiles?** It is normal: it uses all the cores. Avoid running the launcher for Node/NPM in parallel (it would stop and restart the same services).

**Disk full halfway through the index?** Keep an eye on `df -h /data`: a full disk makes Electrs fail with a rather unclear error.

---

## 8. Verifying after the update

```bash
bitcoin-cli getnetworkinfo | grep -i subversion          # versione del daemon Bitcoin Core
bitcoin-cli getblockchaininfo | grep -E '"blocks"|"headers"|verificationprogress'
systemctl is-active bitcoind electrs btcrpcexplorer
journalctl -fu electrs                                    # indicizzazione / stato
```

---

## 9. Test status and stated limits

- Syntax checked (`bash -n`) on all the files; the full flow tried in a **sandbox** with stubs for `sudo`, `systemctl`, `apt`, `gpg`, `git`, `wget`: every script reaches the end with exit 0.
- **Gates tried on real releases**: checksum of Bitcoin Core (`…tar.gz: OK`), GPG signature of the `SHA256SUMS` file (builder keys imported, `Good` signatures), `git verify-tag` of the Electrs release (`Good "git" signature`).
- **Negative tests**: with a tampered `SHA256SUMS` the script stops with `STOP. Il file scaricato non coincide con il riferimento ufficiale`; with a forged GPG signature, `STOP. Non installare binari la cui firma non e' verificata`. In both cases no installation.
- **`LimitNOFILE` preflight** (1.1) tried in the sandbox in the three cases: drop-in missing + answer «no» (it creates nothing), drop-in missing + «yes» (it creates the file with the expected content), drop-in already present (it recognises it and does not touch it).
- **1.1 comes out of use on a real node**: the scripts were run on a MiniBolt (Ubuntu 22.04) on 2026-10-16; the fixes of this version come from there (see [`CHANGELOG.md`](CHANGELOG.md)).
- **Not automatically tested** (they depend on your node): the steps that touch the system — `apt install`, `sudo install`, `systemctl restart`, compilation of RocksDB — must be run and observed on the node. The versions offered as defaults change over time: the script always asks for confirmation before downloading.

---

License [MIT](LICENSE). No warranty. The procedures reproduced are those of the [MiniBolt](https://minibolt.minibolt.info) guide — if the guide changes, the scripts need to be realigned.
