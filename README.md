🇮🇹 Italiano · 🇬🇧 [English version](README.en.md)

# MiniBolt — script di aggiornamento

**Bitcoin Core · Electrs · BTC RPC Explorer · Rustup/Cargo · Node/NPM**

Cinque script bash che aggiornano un nodo [MiniBolt](https://minibolt.minibolt.info) riproducendo **passo per passo** le procedure della guida ufficiale: gli stessi comandi, nello stesso ordine, come se venissero copiati e incollati uno per uno nel terminale — ma con i **controlli di firma e checksum bloccanti**: se una verifica non passa, lo script si ferma e **non installa niente**.

> [!TIP]
> Da dove arriva questo pacchetto
> La distribuzione ufficiale è **questo repository**: ogni versione esce come **release firmata** (firma GPG + `sha256`), e le istruzioni per verificarla sono nella **sezione 3** — leggile prima di estrarre l'archivio.
> - Chiave di firma, fingerprint, come segnalare un problema: [`SECURITY.md`](SECURITY.md)
> - Cosa cambia in ogni versione: [`CHANGELOG.md`](CHANGELOG.md)
> - Licenza: [MIT](LICENSE)

> [!WARNING]
> Prima di iniziare — leggi qui
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
| `keys/stibax-minibolt.asc` | chiave pubblica di firma — comoda da avere accanto all'archivio, ma **da sola non prova niente**: confronta il fingerprint (sezione 3.4) | — |
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

Poi passa alla **sezione 3.4** per la verifica.

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

> [!NOTE]
> `WARNING: This key is not certified with a trusted signature` è normale
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

> [!NOTE]
> Cosa protegge (e cosa no) questo controllo
> Il `.sha256` serve a scoprire un **trasferimento andato storto** o un archivio modificato per errore. **Non** prova l'autenticità del pacchetto: chi può alterare l'archivio può alterare anche il suo `.sha256`. Per quello serve una **firma** di chi distribuisce (`gpg --verify`, se chi te lo passa la fornisce). Verifica sempre l'hash che ti è stato comunicato per un canale diverso da quello con cui hai scaricato l'archivio.

### 3.6 Estrarre e verificare i file

```bash
tar xzf minibolt-update-scripts-1.1.tar.gz          # crea la cartella minibolt-update/
cd minibolt-update
chmod +x *.sh
sha256sum -c SHA256SUMS.txt                         # tutte le righe devono dire OK
```

Qui si controllano i **singoli file** dentro l'archivio (`SHA256SUMS.txt` è il manifest interno). Se una riga dice `FAILED`, il file è corrotto: riestrai da un archivio appena ritrasferito e ripeti.

> [!WARNING]
> Non incollare il testo degli script nella shell
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
- **Anche il repository è blindato**, non solo il pacchetto: release immutabili, tag firmati obbligatori e non spostabili, nessuna automazione. È il motivo per cui una release già scaricata non può cambiare sotto i piedi — dettagli in [`SECURITY.md`](SECURITY.md), sezione «Postura di sicurezza del repository».

---

## 7. Gotcha e domande frequenti

> [!WARNING]
> Electrs 0.12 richiede `rest=1` su bitcoind e una reindicizzazione
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

> [!WARNING]
> `electrs` muore con `Too many open files` durante l'indicizzazione
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
