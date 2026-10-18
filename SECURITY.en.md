🇬🇧 English · 🇮🇹 [Versione italiana](SECURITY.md)

# Security

## The signing key

| Field | Value |
|---|---|
| UID | `Vladx <vladx@vladtech.org>` |
| Fingerprint | `8CE3 522D 2DDF 1EEE 5349  19A4 476E C750 0847 4F71` |
| Published on | [keys.openpgp.org](https://keys.openpgp.org/search?q=8CE3522D2DDF1EEE534919A4476EC75008474F71) |
| Private | **OpenPGP smartcard** (Nitrokey `000F 37D46AC3`): it does not exist on disk |

The `v*` tags and the release archives are signed with this key. For the full
verification (three levels: signature, archive, contents) see the **[README](README.en.md)**:
**section 3.4** (signature), **section 3.5** (archive), **section 3.6** (contents).

**Compare the fingerprint on a channel other than** the one you downloaded the
archive from: a valid signature proves that the archive comes from whoever
holds that key, not *who* that person is.

## If the key changes

The private key lives on a smartcard: it cannot be exfiltrated from a backup, but
**the card can be lost or break**, and in that case the key is replaced.
A release signed with a key other than the one above must be considered
**suspicious** until you have verified the new fingerprint out of band (a
signed release is not a proof of identity: always verify the fingerprint).
The updated fingerprint appears in this file, in `keys/README.en.md` and on
keys.openpgp.org.

## What these scripts do (and what they do not do)

What they do: they reproduce with `sudo` the same steps of the MiniBolt guide
(compilation, installation in `/usr/local/bin`, restart of `bitcoind` /
`electrs` / services via `systemctl`). Before installing anything they run the
checks of the guide — GPG signature of the Bitcoin Core builders, `sha256sum` of
the binaries, `git verify-tag` on the Electrs releases — and **they stop** if a
verification does not pass.

What they do not do:

- they do not contact hosts other than the infrastructure declared in the README
  (`bitcoincore.org`, `github.com`, the official repositories of the projects);
- they do not collect, do not send and do not record anywhere data about your
  node, your wallet or your configuration;
- they do not ask for or store passwords: the only password requested is the one
  of `sudo`, read by `sudo` itself and used only for the duration of the script;
- they do not download and run remote scripts (`curl | bash` does not exist, here).

## Repository security posture

It is not only the package that is verifiable: the repository too is configured so that what you have already downloaded **cannot change under your feet**.

| Setting | State | Why |
|---|---|---|
| **Immutable releases** | enabled | a published release, with its assets, can no longer be modified or deleted: if a change is needed a new version is published, and 1.1 stays the one you verified |
| **`main protected` ruleset** | enabled | `main` cannot be deleted or rewritten with a force-push; normal pushes remain possible |
| **`tag v*` ruleset** | enabled | tags cannot be moved to another commit or deleted, and they **must** be signed (`Require signed commits`): a tag signed once cannot become another commit |
| **Actions disabled** | — | no CI: an automation that signed would need the private key in the GitHub secrets, that is, the only thing that must not leave the smartcard |
| **Secret scanning + push protection** | enabled | if one day a file with a secret ended up in a commit, GitHub stops the push |
| **Private vulnerability reporting** | enabled | the private channel to report a problem, without opening a public issue |
| **No collaborators, no tokens** | — | the only write access is a **deploy key limited to this repository** (not to the account) |
| **Features** | Issues on; Wiki, Projects, Discussions off | less surface: a single door for the reports |

**Practical consequence**: if a file of this repository appeared changed without a new release, or a tag pointed to a different commit, that would be an **anomaly** — the repository does not allow it. And it is worth saying, because it is the difference between "I trust what is there now" and "I can verify what was there when I downloaded it".

> The commits of the `main` branch are **not** signed: the build and the push are done by a separate machine, so there is no commit signing key to keep. The cryptographic guarantee rests on the **tag** and on the **archive**, both signed, with the tag bound to the commit. The chain is: *contents → verified manifest → signed archive → signed tag → commit*.

## Reporting a problem

- **Security problem** (a script can install something unverified, a check can be
  bypassed, a path is writable by others): use the **private vulnerability
  reporting** of GitHub — **Security** tab → **Report a vulnerability**. Do not
  open a public issue.
- **Ordinary bug** (the script stops, a path is wrong, a message is
  wrong): a **public issue** is fine, attach the output of the script.

## Stated limits

This is not audited code. The tests made are those listed in the
README ("Test status and stated limits"): syntax, full flow in
sandbox, signature/checksum gates tried on real releases, negative tests.
The scripts assume a node installed **following the MiniBolt guide**: if
you moved paths, users or systemd units, adapt them before running them.

No warranty: your node is your responsibility. Make a backup (snapshot
of the VM or disk image) before updating.
