# Self-service OpenPGP publication for cum.army

`modules/wks.nix`, imported by the mailserver module, runs GnuPG's Web Key
Service (WKS). Users submit keys and confirm ownership through email; published
keys are runtime state, not a mapping of keys in Nix. Caddy serves the resulting
Web Key Directory (WKD) at:

```text
https://openpgpkey.cum.army/.well-known/openpgpkey/cum.army/
```

## Before deployment

- Point `openpgpkey.cum.army` at cumserver in DNS. Add an AAAA record only if
  IPv6 reaches its ports 80/443. Caddy manages the HTTPS certificate.
- Reserve `key-submission@cum.army` for WKS. Postfix routes it directly to the
  service, ahead of catch-all aliases; it is not an IMAP account.
- Build cumserver on a Linux build host. The dedicated GnuPG package explicitly
  sets its compile-time sendmail path to NixOS's Postfix wrapper.
- Deploy through the usual workflow, then verify:

  ```sh
  curl --fail https://openpgpkey.cum.army/.well-known/openpgpkey/cum.army/submission-address
  gpg-wks-client --verbose --supported you@cum.army
  ```

## Users: publish or update a key

Use a WKS-capable client, or GnuPG's `gpg-wks-client`. Thunderbird can discover
keys through WKD but does not currently provide built-in WKS publication
([upstream issue](https://bugzilla.mozilla.org/show_bug.cgi?id=1695048)).

The command-line workflow below requires the user's personal key in **their
own local GnuPG keyring**, and an msmtp account named `cum-army` configured with
their SMTP credentials (`mail.cum.army`, port 465, implicit TLS). A key kept only
inside Thunderbird is not automatically available to GnuPG. Never send a
personal private key to cumserver or put it in this repository.

1. Ensure the key has signing and encryption capabilities and contains your
   exact email address as a user ID. Find its fingerprint with `gpg --list-keys`.
2. Submit your key from your own device:

   ```sh
   set -o pipefail
   gpg-wks-client --create YOUR_FINGERPRINT you@cum.army \
     | msmtp --account=cum-army --read-recipients
   ```

   The client discovers the service's submission address and public key over
   WKD, and builds the publication request. We pipe generated email to msmtp
   rather than relying on the client's compile-time sendmail path.
3. A confirmation email arrives in your normal mailbox. Save the original
   message as `confirmation.eml` (in Thunderbird: Save As > File), then run:

   ```sh
   gpg-wks-client --receive < confirmation.eml \
     | msmtp --account=cum-army --read-recipients
   ```

   GnuPG decrypts the challenge with your private key, verifies it, and creates
   the confirmation response. The server publishes the key only after receiving
   a valid response. Requests expire after three days.
4. Check publication:

   ```sh
   gpg-wks-client --verbose --check you@cum.army
   ```

Repeat the same workflow after extending a key's expiry or replacing it with a
new key. Each email identity, including aliases, must be confirmed separately.
No rebuild or administrator approval is needed. Other clients may cache older
keys; publication does not force anyone to encrypt email.

WKS does not provide a general account-management API. GnuPG's server does not
implement its `--revoke-key` command, and removing a published key still needs
an administrator. Keep your personal revocation certificate safely offline.

## Server state and operations

- `wks-init.service` creates/reuses a service signing/encryption key on the host
  and publishes its public half. This service key is **not a user's mail key**.
- Postfix passes submissions and confirmations to `gpg-wks-server` as `wks`.
  Procmail discards daemon/loop-marked mail and defers failed processing for
  retry. Malformed requests can therefore stay queued until Postfix expires
  them; inspect the queue if submissions repeatedly fail.
- Normal challenge/response is retained; `auth-submit` is not enabled.
- Caddy exposes only `hu/*`, `policy`, and `submission-address`. The private
  keyring and pending challenges are never web-served.
- `wks-cleanup.timer` removes expired pending requests daily.
- `restic-backups-wks` backs up `/var/lib/wks` as root when mail backups are
  enabled; its repository and credentials are shared with the mail backup.

Persistent layout:

```text
/var/lib/wks/
  gnupg/                    service keyring; private, mode 0700
  domains/cum.army/
    submission-address      key-submission@cum.army
    policy                  confirmation-based publication
    hu/                     published public keys
    pending/                unconfirmed requests; private, mode 0700
```

Inspect service logs and the Postfix queue:

```sh
journalctl -u wks-init -u wks-cleanup -u postfix
postqueue -p
```

Remove a published key administratively:

```sh
sudo -u wks /run/current-system/sw/bin/wks-admin --remove-key you@cum.army
```

Back up and restore the complete state directory with ownership and permissions
preserved. Do not delete the service keyring during redeployment: users need a
stable service identity, and in-flight submissions depend on its private key.
