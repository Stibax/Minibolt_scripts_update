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
| `keys/vladx-minibolt.asc` | chiave pubblica di firma — comoda da avere accanto all'archivio, ma **da sola non prova niente**: confronta il fingerprint (sezione 3.4) | — |
| `SHA256SUMS.txt` | checksum dei file **dentro** l'archivio, da verificare dopo l'estrazione | — |
| `minibolt-update-scripts-1.1.tar.gz.sha256` | **fuori dall'archivio**: checksum dell'archivio stesso, da verificare **prima** di estrarlo | — |
| `minibolt-update-scripts-1.1.tar.gz.asc` | **fuori dall'archivio**: firma GPG dell'archivio, da verificare **prima** di estrarlo | — |
| `vladx-minibolt.asc` | **fuori dall'archivio**: chiave pubblica di firma (anche in `keys/` nel repository) | — |

---

## 3. Portare gli script sul nodo

Due strade: **scaricare** la release direttamente sul nodo (più semplice — il nodo ha già tutto quello che serve) oppure **trasferire** i file dal tuo PC con `ssh`/`scp`. In entrambi i casi si finisce con gli stessi file in `~`, e la **firma va verificata prima di estrarre** l'archivio.

### 3.1 Scaricare la release direttamente sul nodo

Sul nodo (`ssh admin@nodo`) servono solo `curl` o `wget`, e `gpg`. Meglio puntare al **tag della versione** che vuoi installare, così sai esattamente cosa stai verificando:

```bash
cd ~
V=1.1
BASE=https://github.com/Stibax/Minibolt_scripts_update/releases/download/v$V

curl -fLO $BASE/minibolt-update-scripts-$V.tar.gz
curl -fLO $BASE/minibolt-update-scripts-$V.tar.gz.sha256
curl -fLO $BASE/minibolt-update-scripts-$V.tar.gz.asc
curl -fLO $BASE/vladx-minibolt.asc
```

`-f` fa fallire il comando se il file non esiste (invece di salvare una pagina HTML d'errore), `-L` segue i redirect, `-O` tiene il nome del file remoto. Con `wget` sono gli stessi quattro file, una riga ciascuno:

```bash
wget https://github.com/Stibax/Minibolt_scripts_update/releases/download/v1.1/minibolt-update-scripts-1.1.tar.gz
wget https://github.com/Stibax/Minibolt_scripts_update/releases/download/v1.1/minibolt-update-scripts-1.1.tar.gz.sha256
wget https://github.com/Stibax/Minibolt_scripts_update/releases/download/v1.1/minibolt-update-scripts-1.1.tar.gz.asc
wget https://github.com/Stibax/Minibolt_scripts_update/releases/download/v1.1/vladx-minibolt.asc
```

**Cosa significa `latest`.** `.../releases/latest/download/<file>` è un alias che GitHub risolve **sempre all'ultima release pubblicata** (non bozza, non pre-release): è comodo perché non devi sapere il numero, ma il **nome del file** dentro l'URL resta quello della versione (`…-1.1.tar.gz`), quindi va aggiornato quando esce una versione nuova. Per una versione precisa — o per un link che non cambi mai, da mettere in uno script tuo — usa il **tag**, come sopra.

> [!TIP]
> Puoi anche prendere i link a mano: nella pagina della release, **clic destro → «Copia indirizzo del collegamento»** su ciascun asset, poi incollalo dopo `curl -fLO` o `wget`. Quello è già l'URL **con il tag**, quindi punta esattamente a quella versione: è il modo più a prova di errore per scaricare una versione specifica.

> [!NOTE]
> Nella **1.1** il file della chiave si chiama ancora `stibax-minibolt.asc`; dalla **1.2** è `vladx-minibolt.asc`, perché il nome segue l'UID della chiave (`Vladx`). Se installi la 1.1, scarica il vecchio nome — oppure prendi la chiave dal keyserver (sezione 3.4), che non dipende dal nome del file.

Poi passa alla **sezione 3.4** per importare la chiave e verificare la firma.

### 3.2 In alternativa: trasferire i file dal tuo PC (porta 22)

Serve solo `ssh`/`scp` (o `rsync`): nessun altro strumento. Da qui in poi l'esempio usa `admin@nodo` — sostituisci con l'IP o il nome del tuo nodo.

I file da trasferire sono **quattro**: l'archivio `minibolt-update-scripts-1.1.tar.gz`, il suo checksum `….sha256`, la firma `….asc` e la **chiave pubblica** `vladx-minibolt.asc` (nella 1.1: `stibax-minibolt.asc`). Nei comandi seguenti `minibolt-update-scripts-1.1.tar.gz*` prende i primi tre, la chiave la scrivo per nome. Se preferisci, la chiave **non** serve trasferirla: sul nodo la prendi dal keyserver con un comando (sezione 3.4).

```bash
scp minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc admin@nodo:/home/admin/
```

Se preferisci `rsync` (riprende se la connessione cade, mostra il progresso):

```bash
rsync -avP minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc admin@nodo:/home/admin/
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
scp minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc nodo:/home/admin/
rsync -avP minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc nodo:/home/admin/
ssh nodo                                     # per lavorare sul nodo
```

### 3.3 Se la porta SSH non è la 22

Attenzione, sono flag diversi nei due comandi:

```bash
scp -P 2222 minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc admin@nodo:/home/admin/      # -P maiuscola
rsync -avP -e "ssh -p 2222" minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc admin@nodo:/home/admin/
```

In `scp` la porta è **`-P`** (maiuscola); `-p` minuscola significa "preserva i timestamp" e il numero viene interpretato come un file → errore tipo `scp: stat local "2222": No such file or directory`.

### 3.4 Chiave pubblica e verifica della firma (autenticità)

Questa è la verifica che conta davvero: dice che l'archivio è stato firmato con la chiave privata di chi pubblica il pacchetto. Quella chiave sta su una **smartcard OpenPGP** e non esiste su disco, quindi in giro c'è solo la parte pubblica.

#### a) Importare la chiave pubblica — tre modi, stesso risultato

**1. Dal file** (lo hai scaricato con l'archivio, o te l'ha passato chi ti dà il pacchetto):

```bash
gpg --import vladx-minibolt.asc          # nella 1.1: stibax-minibolt.asc
gpg --list-keys --with-fingerprint 476EC75008474F71   # mostra fingerprint e UID
```

**2. Dal keyserver** (nessun file da trasferire; la chiave è pubblicata su keys.openpgp.org, che verifica l'email dell'UID):

```bash
gpg --keyserver hkps://keys.openpgp.org --recv-keys 8CE3522D2DDF1EEE534919A4476EC75008474F71
```

**3. Solo dal fingerprint** (il caso più sicuro: il fingerprint ti arriva da un canale diverso dal download — a voce, dal sito dell'autore, da un messaggio firmato). I comandi sono quelli del punto 2: il fingerprint è l'identificativo, non serve altro. Se invece hai un file `.asc` e vuoi sapere **che chiave contiene** prima di importarlo:

```bash
gpg --show-keys --with-fingerprint vladx-minibolt.asc
```

In tutti e tre i casi la chiave in portachiavi deve avere questo fingerprint:

```
8CE3 522D 2DDF 1EEE 5349  19A4 476E C750 0847 4F71
```

**Confrontalo** con quello pubblicato in [`SECURITY.md`](SECURITY.md), in [`keys/README.md`](keys/README.md) e su [keys.openpgp.org](https://keys.openpgp.org/search?q=8CE3522D2DDF1EEE534919A4476EC75008474F71) — e, se puoi, con quello che l'autore ha comunicato su un canale suo. Se non coincide, **non estrarre niente**.

#### b) Verificare la firma dell'archivio

```bash
gpg --verify minibolt-update-scripts-1.1.tar.gz.asc minibolt-update-scripts-1.1.tar.gz
```

Deve uscire `Good signature from "Vladx <vladx@vladtech.org>"` e, subito dopo, lo stesso fingerprint.

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

> [!IMPORTANT]
> **Dove finiscono i file**: l'archivio contiene una sola cartella, `minibolt-update/`, e si estrae **nella cartella in cui ti trovi**. Se sei in `~` come utente `admin`, finisce in **`/home/admin/minibolt-update/`**: è lì che trovi gli script, il `README.md` e il `SHA256SUMS.txt`. Gli script **non** si installano da nessuna parte: restano in quella cartella, e li lanci da lì.

```bash
cd ~                                              # se non ci sei già: la cartella di destinazione
tar xzf minibolt-update-scripts-1.1.tar.gz          # crea /home/admin/minibolt-update/
cd ~/minibolt-update
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

Ogni script apre con dei **controlli preliminari** (*preflight*: le verifiche fatte **prima** di toccare il sistema — comandi presenti, versioni, limiti, configurazione) e poi chiede una conferma complessiva (`Procedo? (S)`), più conferme puntuali sui passi che si discostano dalla guida. Dove un rimedio **non** è automatizzato lo script lo dice esplicitamente: sotto ogni componente è indicato cosa fa lui e cosa resta a te.

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

#### Perché l'aggiornamento di electrs può non riuscire

Due guasti diversi, che si somigliano solo perché in entrambi i casi `electrs` finisce in `failed`:

| | Sintomo | Causa | Rimedio | Chi lo applica |
|---|---|---|---|---|
| **A** | nel journal `failed to open index` e `GET http://127.0.0.1:8332/rest/blockhashbyheight/0.bin failed: StatusCode(404)` | electrs **0.12.0** è passato al motore `bindex`: usa l'**interfaccia REST** di bitcoind, richiede **Bitcoin Core 31+** e ha un **formato di indice nuovo** | `rest=1` in `bitcoin.conf` + **reindicizzazione** | **tu, a mano** per aggiunta e reindicizzazione; dalla 1.2 lo script **controlla** `rest=1` e si ferma se manca |
| **B** | `Too many open files (os error 24)`: il processo muore a metà indicizzazione | il **soft limit dei descrittori** è 1024 e RocksDB tiene aperto **un file per ogni SST** dell'indice (migliaia), perché il default di `max_open_files` è `-1` | drop-in systemd `LimitNOFILE=65536` | **lo script**, al Passo 0 (chiede conferma) |

**Versioni.** Il salto che cambia le regole è **0.11.1 → 0.12.0**. Il guasto **A** esiste *solo* a partire dalla 0.12.0: la 0.11.x non usava REST e con la stessa configurazione funzionava. Il guasto **B** non dipende dalla versione, dipende da **quanto è grande l'indice**: si manifesta quando electrs prova ad aprire più file di quanti il processo può averne.

##### A — bindex: perché serve `rest=1` e una reindicizzazione

Le note della release [electrs v0.12.0](https://github.com/romanz/electrs/releases/tag/v0.12.0), alla voce *Switch to bindex*, dicono:

> requires Bitcoin Core 31+ · uses REST API server (`-rest=1`) · new index format - requires reindexing!

Senza `rest=1` il servizio non parte affatto: `bindex` interroga bitcoind via REST (`/rest/blockhashbyheight/…`), trova 404, e il journal mostra `failed to open index`. Con `rest=1` ma il **vecchio indice** ancora in `/data/electrs/db` non parte lo stesso, perché il formato è cambiato: va accantonato e rifatto da zero (ore di lavoro su un nodo mainnet).

```bash
sudo cp /data/bitcoin/bitcoin.conf /data/bitcoin/bitcoin.conf.bak-$(date +%F)
sudo nano /data/bitcoin/bitcoin.conf            # aggiungi:  rest=1
sudo systemctl restart bitcoind
curl -s http://127.0.0.1:8332/rest/blockhashbyheight/0.bin | xxd -p -c 32   # deve dare l'hash del blocco genesi

sudo systemctl stop electrs
sudo mv /data/electrs/db /data/electrs/db.electrs-0.11-$(date +%F)          # si accantona, non si cancella
sudo systemctl start electrs                     # riparte l'indicizzazione (ore)
journalctl -fu electrs
```

`bitcoin.conf` si modifica con `nano` (o `sudo -u bitcoin nano`) e **non** con `sudo sed -i`: `sed -i` ricrea il file con proprietario `root` e `bitcoind` non riparte più.

Dalla **1.2** lo script **controlla** `rest=1` prima di compilare (quando ha già chiesto quale versione installare): se manca, ti mostra il sintomo e si ferma lì — invece di lasciarti compilare per venti minuti e trovare il servizio morto alla fine. **Non modifica `bitcoin.conf`**: quello resta in mano tua, perché è un file di `bitcoind` con permessi delicati.

Finché l'indice non è completo, wallet ed explorer danno errori su saldi e indirizzi: è normale. Lo spazio del vecchio indice si recupera **dopo** che la nuova indicizzazione è arrivata in fondo.

##### B — "Too many open files": il tetto dei descrittori

RocksDB apre un descrittore per ogni file `.sst` dell'indice e, con il default `max_open_files = -1`, li tiene **tutti** aperti. La unit `electrs.service` della guida non imposta `LimitNOFILE`, quindi il processo eredita il soft limit di default di systemd: **1024**. Su un indice reale (≈3.700 file `.sst`, ≈77 GB) il conto non torna e `electrs` muore con `Too many open files (os error 24)` a metà indicizzazione — a volte dopo diverse ore, quando l'indice è cresciuto.

Rimedio, una volta sola — è esattamente quello che fa il **Passo 0 dello script**, chiedendo conferma:

```bash
sudo mkdir -p /etc/systemd/system/electrs.service.d
printf '[Service]\nLimitNOFILE=65536\n' | sudo tee /etc/systemd/system/electrs.service.d/10-nofile.conf
sudo systemctl daemon-reload
sudo systemctl restart electrs
```

La trappola è nel modo di **verificare**: `systemctl show -p LimitNOFILE electrs` stampa il **hard** limit (di solito `524288`) e sembra tutto a posto anche quando il problema c'è. Il valore che conta è quello del processo:

```bash
sudo grep -i 'open files' /proc/$(systemctl show -p MainPID --value electrs)/limits    # prima colonna = soft
```

Deve dire `65536` nella **prima** colonna (`Max open files 65536 65536`).

##### Fonti

- **electrs v0.12.0**, note della release (voce *Switch to bindex*): <https://github.com/romanz/electrs/releases/tag/v0.12.0>
- **RocksDB `max_open_files`**, default `-1` («If max_open_files is -1, DB will open all files»): <https://github.com/facebook/rocksdb/blob/main/include/rocksdb/options.h>
- **romanz/electrs issue #109 «Too many open files»** — stessa diagnosi, risolta alzando il limite (`ulimit -n 131072`): <https://github.com/romanz/electrs/issues/109>
- **systemd**, direttiva `LimitNOFILE` in `systemd.exec`: <https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html>
- **Bitcoin Core**, interfaccia REST (`-rest`): <https://github.com/bitcoin/bitcoin/blob/master/doc/REST-interface.md>

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
- **Anche il repository è blindato**, non solo il pacchetto: release immutabili, tag firmati obbligatori e non spostabili, nessuna automazione. È il motivo per cui, una volta scaricata, una release non può più essere modificata — dettagli in [`SECURITY.md`](SECURITY.md), sezione «Postura di sicurezza del repository».

---

## 7. Gotcha e domande frequenti

> [!TIP]
> **Electrs: i due modi in cui l'aggiornamento può fallire** — `rest=1` mancante (bindex, dalla 0.12.0) e `Too many open files` (limite dei descrittori). Cause, rimedi, versioni di partenza/arrivo e fonti sono raccolti in un solo posto: **sezione 5, «Perché l'aggiornamento di electrs può non riuscire»**.

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
