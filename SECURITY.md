# Sicurezza

## La chiave di firma

| Campo | Valore |
|---|---|
| UID | `Vladx <vladx@vladtech.org>` |
| Fingerprint | `8CE3 522D 2DDF 1EEE 5349  19A4 476E C750 0847 4F71` |
| Pubblicata su | [keys.openpgp.org](https://keys.openpgp.org/search?q=8CE3522D2DDF1EEE534919A4476EC75008474F71) |
| Privata | **smartcard OpenPGP** (Nitrokey `000F 37D46AC3`): non esiste su disco |

I tag `v*` e gli archivi delle release sono firmati con questa chiave. Per la
verifica completa (tre livelli: firma, archivio, contenuto) vedi il **README**,
sezione «Verificare una release».

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
