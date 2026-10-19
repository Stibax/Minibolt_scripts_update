🇬🇧 English · 🇮🇹 [Versione italiana](README.md)

# Public signing key

`vladx-minibolt.asc` is the key with which the tags and the archives of
this repository are signed.

| Field | Value |
|---|---|
| UID | `Vladx <vladx@vladtech.org>` |
| Fingerprint | `8CE3 522D 2DDF 1EEE 5349  19A4 476E C750 0847 4F71` |
| Algorithm | ed25519 (primary, `[SC]`), cv25519 (`[E]`), rsa3072 (`[A]`) |
| Created | 2026-05-03 |
| Where the private key lives | **OpenPGP smartcard** (Nitrokey), serial `000F 37D46AC3` — it does not exist on disk |

## Where to get it (in order of preference)

1. **keys.openpgp.org** (it verifies the identity via email):
   ```
   gpg --keyserver hkps://keys.openpgp.org --recv-keys 8CE3522D2DDF1EEE534919A4476EC75008474F71
   ```
2. The file `keys/vladx-minibolt.asc` of this repository (convenient, but it is served
   by GitHub: on its own it proves nothing about the key — compare its **fingerprint**
   with the one published on keys.openpgp.org, or with the one on the author's site).

Comparing the fingerprint by voice, over a channel other than the one you
downloaded the script from, is the only verification that really counts.
