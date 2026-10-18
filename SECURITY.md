🇮🇹 Italiano · 🇬🇧 [English version](SECURITY.en.md)

# Sicurezza

## La chiave di firma

| Campo | Valore |
|---|---|
| UID | `Vladx <vladx@vladtech.org>` |
| Fingerprint | `8CE3 522D 2DDF 1EEE 5349  19A4 476E C750 0847 4F71` |
| Pubblicata su | [keys.openpgp.org](https://keys.openpgp.org/search?q=8CE3522D2DDF1EEE534919A4476EC75008474F71) |
| Privata | **smartcard OpenPGP** (Nitrokey `000F 37D46AC3`): non esiste su disco |

I tag `v*` e gli archivi delle release sono firmati con questa chiave. Per la
verifica completa (tre livelli: firma, archivio, contenuto) vedi il **[README](README.md)**:
**sezione 3.4** (firma), **sezione 3.5** (archivio), **sezione 3.6** (contenuto).

**Confronta il fingerprint su un canale diverso** da quello da cui hai scaricato
l'archivio: una firma valida prova che l'archivio viene da chi possiede quella
chiave, non *chi* è quella persona.

## Se la chiave cambia

La privata sta su una smartcard: non può essere esfiltrata da un backup, ma **si
può perdere o rompere la card**, e in quel caso la chiave viene sostituita.
Una release firmata con una chiave diversa da quella qui sopra va considerata
**sospetta** finché non hai verificato il nuovo fingerprint fuori banda (una
release firmata non è una prova di identità: verifica sempre il fingerprint).
Il fingerprint aggiornato compare in questo file, in `keys/README.md` e su
keys.openpgp.org.

## Cosa fanno questi script (e cosa non fanno)

Cosa fanno: riproducono con `sudo` gli stessi passi della guida MiniBolt
(compilazione, installazione in `/usr/local/bin`, riavvio di `bitcoind` /
`electrs` / servizi via `systemctl`). Prima di installare qualcosa eseguono i
controlli della guida — firma GPG dei builder di Bitcoin Core, `sha256sum` dei
binari, `git verify-tag` sulle release di Electrs — e **si fermano** se una
verifica non passa.

Cosa non fanno:

- non contattano altri host all'infrastruttura dichiarata nel README
  (`bitcoincore.org`, `github.com`, i repository ufficiali dei progetti);
- non raccolgono, non inviano e non registrano da nessuna parte dati del tuo
  nodo, del wallet o della configurazione;
- non chiedono né salvano password: l'unica password richiesta è quella di
  `sudo`, letta da `sudo` stesso e usata solo per la durata dello script;
- non scaricano ed eseguono script remoti (`curl | bash` non esiste, qui).

## Postura di sicurezza del repository

Non è verificabile solo il pacchetto: anche il repository è configurato perché quello che hai già scaricato **non possa cambiare sotto i piedi**.

| Impostazione | Stato | Perché |
|---|---|---|
| **Release immutabili** | attiva | una release pubblicata, con i suoi asset, non si può più modificare né cancellare: se serve un cambiamento si pubblica una versione nuova, e la 1.1 resta quella che hai verificato |
| **Ruleset `main protetto`** | attivo | `main` non si può cancellare né riscrivere con un force-push; i push normali restano possibili |
| **Ruleset `tag v*`** | attivo | i tag non si possono spostare su un altro commit né cancellare, e **devono** essere firmati (`Require signed commits`): un tag firmato una volta non può diventare un altro commit |
| **Actions disattivate** | — | nessuna CI: un'automazione che firmasse avrebbe bisogno della chiave privata nei secret di GitHub, cioè dell'unica cosa che non deve uscire dalla smartcard |
| **Secret scanning + push protection** | attivi | se un domani un file con un segreto finisse in un commit, GitHub ferma il push |
| **Private vulnerability reporting** | attivo | il canale privato per segnalare un problema, senza aprire una issue pubblica |
| **Nessun collaboratore, nessun token** | — | l'unico accesso in scrittura è una **deploy key limitata a questo repository** (non all'account) |
| **Features** | Issues on; Wiki, Projects, Discussions off | meno superficie: una sola porta per le segnalazioni |

**Conseguenza pratica**: se un file di questo repository apparisse cambiato senza una release nuova, o un tag puntasse a un commit diverso, è un'**anomalia** — il repository non lo permette. E vale la pena dirlo perché è la differenza fra "mi fido di quello che c'è adesso" e "posso verificare quello che c'era quando l'ho scaricato".

> I commit del ramo `main` **non** sono firmati: la build e il push li fa una macchina separata, quindi non c'è una chiave di firma dei commit da custodire. La garanzia crittografica sta sul **tag** e sull'**archivio**, entrambi firmati, con il tag vincolato al commit. La catena è: *contenuto → manifest verificato → archivio firmato → tag firmato → commit*.

## Segnalare un problema

- **Problema di sicurezza** (uno script può installare qualcosa di non
  verificato, una verifica è aggirabile, un percorso è scrivibile da altri):
  usa il **private vulnerability reporting** di GitHub —
  tab **Security** → **Report a vulnerability**. Non aprire una issue pubblica.
- **Bug normale** (lo script si ferma, un percorso non torna, un messaggio è
  sbagliato): va bene una **issue pubblica**, allega l'output dello script.

## Limiti dichiarati

Questo non è codice sottoposto ad audit. I test fatti sono quelli elencati nel
README («Stato dei test e limiti dichiarati»): sintassi, flusso completo in
sandbox, gate di firma/checksum provati su release reali, test negativi.
Gli script presuppongono un nodo installato **seguendo la guida MiniBolt**: se
hai spostato percorsi, utenti o unit systemd, adattali prima di eseguirli.

Nessuna garanzia: sei tu il responsabile del tuo nodo. Fai un backup (snapshot
della VM o immagine del disco) prima di aggiornare.
