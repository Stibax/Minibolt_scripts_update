🇬🇧 English · 🇮🇹 [Versione italiana](README.md)

# MiniBolt — update scripts

**Bitcoin Core · Electrs · BTC RPC Explorer · Rustup/Cargo · Node/NPM**

Five bash scripts that update a [MiniBolt](https://minibolt.minibolt.info) node by reproducing **step by step** the procedures of the official guide: the same commands, in the same order, as if they were copied and pasted one by one into the terminal — but with **blocking signature and checksum checks**: if a verification does not pass, the script stops and **installs nothing**.

> [!TIP]
> Where this package comes from
> The official distribution channel is **this repository**: every version ships as a **signed release** (GPG signature + `sha256`), and the instructions to verify it are in **section 3** — read them before extracting the archive.
> - Signing key, fingerprint, how to report a problem: [`SECURITY.en.md`](SECURITY.en.md)
> - What changes in each version: [`CHANGELOG.md`](CHANGELOG.md)
> - License: [MIT](LICENSE)

> [!WARNING]
> Before you start — read this
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
| `README.en.md` (this file) | — | — |
| `LICENSE`, `SECURITY.en.md`, `CHANGELOG.md` | MIT license, security notes, version history | — |
| `keys/vladx-minibolt.asc` | public signing key — handy to keep next to the archive, but **on its own it proves nothing**: compare the fingerprint (section 3.4) | — |
| `SHA256SUMS.txt` | checksums of the files **inside** the archive, to verify after extraction | — |
| `minibolt-update-scripts-1.1.tar.gz.sha256` | **outside the archive**: checksum of the archive itself, to verify **before** extracting it | — |
| `minibolt-update-scripts-1.1.tar.gz.asc` | **outside the archive**: GPG signature of the archive, to verify **before** extracting it | — |
| `vladx-minibolt.asc` | **outside the archive**: public signing key (also in `keys/` in the repository) | — |

---

## 3. Getting the scripts onto the node

Two routes: **download** the release directly on the node (simpler — the node already has everything it needs) or **transfer** the files from your PC with `ssh`/`scp`. Either way you end up with the same files in `~`, and the **signature must be verified before extracting** the archive.

### 3.1 Downloading the release directly on the node

On the node (`ssh admin@nodo`) you only need `curl` or `wget`, plus `gpg`. It is better to point at the **tag of the version** you want to install, so you know exactly what you are verifying:

```bash
cd ~
V=1.1
BASE=https://github.com/Stibax/Minibolt_scripts_update/releases/download/v$V

curl -fLO $BASE/minibolt-update-scripts-$V.tar.gz
curl -fLO $BASE/minibolt-update-scripts-$V.tar.gz.sha256
curl -fLO $BASE/minibolt-update-scripts-$V.tar.gz.asc
curl -fLO $BASE/vladx-minibolt.asc
```

`-f` makes the command fail if the file does not exist (instead of saving an HTML error page), `-L` follows redirects, `-O` keeps the remote file name. With `wget` it is the same four files, one line each:

```bash
wget https://github.com/Stibax/Minibolt_scripts_update/releases/download/v1.1/minibolt-update-scripts-1.1.tar.gz
wget https://github.com/Stibax/Minibolt_scripts_update/releases/download/v1.1/minibolt-update-scripts-1.1.tar.gz.sha256
wget https://github.com/Stibax/Minibolt_scripts_update/releases/download/v1.1/minibolt-update-scripts-1.1.tar.gz.asc
wget https://github.com/Stibax/Minibolt_scripts_update/releases/download/v1.1/vladx-minibolt.asc
```

**What `latest` means.** `.../releases/latest/download/<file>` is an alias that GitHub always resolves to the **newest published release** (not a draft, not a pre-release): handy because you do not need to know the number, but the **file name** inside the URL still contains the version (`…-1.1.tar.gz`), so it has to be updated when a new version comes out. For a precise version — or for a link that never changes, to put in your own script — use the **tag**, as above.

> [!TIP]
> You can also take the links by hand: on the release page, **right-click → "Copy link address"** on each asset, then paste it after `curl -fLO` or `wget`. That is already the URL **with the tag**, so it points exactly at that version: it is the most error-proof way to download a specific version.

> [!NOTE]
> In **1.1** the key file is still called `stibax-minibolt.asc`; from **1.2** it is `vladx-minibolt.asc`, because the name follows the key UID (`Vladx`). If you install 1.1, download the old name — or fetch the key from the keyserver (section 3.4), which does not depend on the file name.

Then go to **section 3.4** to import the key and verify the signature.

### 3.2 Alternatively: transfer the files from your PC (port 22)

You only need `ssh`/`scp` (or `rsync`): no other tool. From here on the example uses `admin@nodo` — replace it with the IP or the hostname of your node.

There are **four** files to transfer: the archive `minibolt-update-scripts-1.1.tar.gz`, its checksum `….sha256`, the signature `….asc` and the **public key** `vladx-minibolt.asc` (in 1.1: `stibax-minibolt.asc`). In the commands below `minibolt-update-scripts-1.1.tar.gz*` picks up the first three; the key is written by name. If you prefer, the key does **not** need to be transferred: on the node you fetch it from the keyserver with one command (section 3.4).

```bash
scp minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc admin@nodo:/home/admin/
```

If you prefer `rsync` (it resumes if the connection drops, it shows the progress):

```bash
rsync -avP minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc admin@nodo:/home/admin/
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
scp minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc nodo:/home/admin/
rsync -avP minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc nodo:/home/admin/
ssh nodo                                     # per lavorare sul nodo
```

### 3.3 If the SSH port is not 22

Careful, they are different flags in the two commands:

```bash
scp -P 2222 minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc admin@nodo:/home/admin/      # -P maiuscola
rsync -avP -e "ssh -p 2222" minibolt-update-scripts-1.1.tar.gz* vladx-minibolt.asc admin@nodo:/home/admin/
```

In `scp` the port flag is **`-P`** (uppercase); lowercase `-p` means "preserve the timestamps" and the number is interpreted as a file → an error like `scp: stat local "2222": No such file or directory`.

### 3.4 Public key and signature verification (authenticity)

This is the check that really counts: it says that the archive was signed with the private key of whoever publishes the package. That key lives on an **OpenPGP smartcard** and does not exist on disk, so only the public half is around.

#### a) Importing the public key — three ways, same result

**1. From the file** (you downloaded it with the archive, or whoever gives you the package passed it to you):

```bash
gpg --import vladx-minibolt.asc          # in 1.1: stibax-minibolt.asc
gpg --list-keys --with-fingerprint 476EC75008474F71   # shows fingerprint and UID
```

**2. From the keyserver** (no file to transfer; the key is published on keys.openpgp.org, which verifies the email of the UID):

```bash
gpg --keyserver hkps://keys.openpgp.org --recv-keys 8CE3522D2DDF1EEE534919A4476EC75008474F71
```

**3. From the fingerprint alone** (the safest case: the fingerprint reaches you over a channel other than the download — by voice, from the author's site, from a signed message). The commands are those of point 2: the fingerprint *is* the identifier, nothing else is needed. If instead you have an `.asc` file and want to know **which key it contains** before importing it:

```bash
gpg --show-keys --with-fingerprint vladx-minibolt.asc
```

In all three cases the key in your keyring must have this fingerprint:

```
8CE3 522D 2DDF 1EEE 5349  19A4 476E C750 0847 4F71
```

**Compare that fingerprint** with the one published in [`SECURITY.md`](SECURITY.en.md), in [`keys/README.en.md`](keys/README.en.md) and on [keys.openpgp.org](https://keys.openpgp.org/search?q=8CE3522D2DDF1EEE534919A4476EC75008474F71). If it does not match, **do not extract anything**.

#### b) Verifying the signature of the archive

```bash
gpg --verify minibolt-update-scripts-1.1.tar.gz.asc minibolt-update-scripts-1.1.tar.gz
```

You must see `Good signature from "Vladx <vladx@vladtech.org>"` and, right after it, the same fingerprint.

> [!NOTE]
> `WARNING: This key is not certified with a trusted signature` is normal
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

> [!NOTE]
> What this check protects against (and what it does not)
> The `.sha256` is there to catch a **transfer that went wrong** or an archive modified by mistake. It does **not** prove the authenticity of the package: whoever can alter the archive can alter its `.sha256` too. That requires a **signature** from whoever distributes it (`gpg --verify`, if whoever hands it to you provides one). Always verify the hash you were given over a channel other than the one you downloaded the archive from.

### 3.6 Extracting and verifying the files

> [!IMPORTANT]
> **Where the files end up**: the archive contains a single folder, `minibolt-update/`, and it is extracted **into the folder you are in**. If you are in `~` as user `admin`, it ends up in **`/home/admin/minibolt-update/`**: that is where you find the scripts, the `README.md` and the `SHA256SUMS.txt`. The scripts are **not** installed anywhere: they stay in that folder and you run them from there.

```bash
cd ~                                              # if you are not there already: the destination folder
tar xzf minibolt-update-scripts-1.1.tar.gz          # crea la cartella minibolt-update/
cd minibolt-update
chmod +x *.sh
sha256sum -c SHA256SUMS.txt                         # tutte le righe devono dire OK
```

Here you check the **individual files** inside the archive (`SHA256SUMS.txt` is the internal manifest). If a line says `FAILED`, that file is corrupted: extract again from an archive you have just transferred again and repeat.

> [!WARNING]
> Do not paste the script text into the shell
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

Every script starts with **preflight checks** (the checks made **before** touching the system — commands present, versions, limits, configuration) and then asks for an overall confirmation (`Procedo? (S)`), plus targeted confirmations on the steps that deviate from the guide. Where a remedy is **not** automated the script says so explicitly: under each component you find what it does and what is left to you.

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

#### Why the electrs update may not succeed

Two different failures that look alike only because in both cases `electrs` ends up in `failed`:

| | Symptom | Cause | Fix | Who applies it |
|---|---|---|---|---|
| **A** | in the journal `failed to open index` and `GET http://127.0.0.1:8332/rest/blockhashbyheight/0.bin failed: StatusCode(404)` | electrs **0.12.0** moved to the `bindex` engine: it uses the **REST interface** of bitcoind, requires **Bitcoin Core 31+** and has a **new index format** | `rest=1` in `bitcoin.conf` + **reindexing** | **you, by hand** for adding it and reindexing; from 1.2 the script **checks** `rest=1` and stops if it is missing |
| **B** | `Too many open files (os error 24)`: the process dies halfway through indexing | the **soft limit on descriptors** is 1024 and RocksDB keeps **one file open per SST** of the index (thousands), because the default of `max_open_files` is `-1` | systemd drop-in `LimitNOFILE=65536` | **the script**, at step 0 (it asks for confirmation) |

**Versions.** The jump that changes the rules is **0.11.1 → 0.12.0**. Failure **A** exists *only* from 0.12.0 onwards: 0.11.x did not use REST and worked with the same configuration. Failure **B** does not depend on the version, it depends on **how big the index is**: it shows up when electrs tries to open more files than the process is allowed.

##### A — bindex: why `rest=1` and a reindex are needed

The [electrs v0.12.0](https://github.com/romanz/electrs/releases/tag/v0.12.0) release notes, under *Switch to bindex*, say:

> requires Bitcoin Core 31+ · uses REST API server (`-rest=1`) · new index format - requires reindexing!

Without `rest=1` the service does not start at all: `bindex` queries bitcoind over REST (`/rest/blockhashbyheight/…`), gets a 404, and the journal shows `failed to open index`. With `rest=1` but the **old index** still in `/data/electrs/db` it does not start either, because the format changed: it has to be set aside and rebuilt from scratch (hours of work on a mainnet node).

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

`bitcoin.conf` is edited with `nano` (or `sudo -u bitcoin nano`) and **not** with `sudo sed -i`: `sed -i` recreates the file owned by `root` and `bitcoind` no longer starts.

From **1.2** the script **checks** `rest=1` before compiling (once it knows which version to install): if it is missing, it shows you the symptom and stops there — instead of letting you compile for twenty minutes and find a dead service at the end. It does **not** modify `bitcoin.conf`: that stays in your hands, because it is a `bitcoind` file with delicate permissions.

Until the index is complete, wallets and explorers throw errors on balances and addresses: that is normal. The space of the old index is reclaimed **after** the new indexing has reached the end.

##### B — "Too many open files": the descriptor ceiling

RocksDB opens one descriptor for every `.sst` file of the index and, with the default `max_open_files = -1`, keeps **all** of them open. The `electrs.service` unit of the guide does not set `LimitNOFILE`, so the process inherits the systemd default soft limit: **1024**. On a real index (≈3,700 `.sst` files, ≈77 GB) the arithmetic does not add up and `electrs` dies with `Too many open files (os error 24)` halfway through indexing — sometimes after hours, once the index has grown.

The fix, once only — this is exactly what **step 0 of the script** does, asking for confirmation:

```bash
sudo mkdir -p /etc/systemd/system/electrs.service.d
printf '[Service]\nLimitNOFILE=65536\n' | sudo tee /etc/systemd/system/electrs.service.d/10-nofile.conf
sudo systemctl daemon-reload
sudo systemctl restart electrs
```

The trap is in **how you verify it**: `systemctl show -p LimitNOFILE electrs` prints the **hard** limit (usually `524288`) and looks all right even when the problem is there. The value that counts is the one of the process:

```bash
sudo grep -i 'open files' /proc/$(systemctl show -p MainPID --value electrs)/limits    # prima colonna = soft
```

It must show `65536` in the **first** column (`Max open files 65536 65536`).

##### Sources

- **electrs v0.12.0**, release notes (under *Switch to bindex*): <https://github.com/romanz/electrs/releases/tag/v0.12.0>
- **RocksDB `max_open_files`**, default `-1` ("If max_open_files is -1, DB will open all files"): <https://github.com/facebook/rocksdb/blob/main/include/rocksdb/options.h>
- **romanz/electrs issue #109 "Too many open files"** — same diagnosis, solved by raising the limit (`ulimit -n 131072`): <https://github.com/romanz/electrs/issues/109>
- **systemd**, `LimitNOFILE` directive in `systemd.exec`: <https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html>
- **Bitcoin Core**, REST interface (`-rest`): <https://github.com/bitcoin/bitcoin/blob/master/doc/REST-interface.md>

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
- **The repository is locked down too**, not only the package: immutable releases, mandatory signed tags that cannot be moved, no automation. That is why, once you have downloaded a release, it can no longer be modified — details in [`SECURITY.md`](SECURITY.en.md), section "Repository security posture".

---

## 7. Gotchas and FAQ

> [!TIP]
> **Electrs: the two ways the update can fail** — missing `rest=1` (bindex, from 0.12.0) and `Too many open files` (descriptor limit). Causes, fixes, starting/target versions and sources are collected in one place: **section 5, "Why the electrs update may not succeed"**.

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
