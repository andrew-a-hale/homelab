# Ralph: Arch + LUKS + TPM2 installed, Guix 1.5.0 on top (2026-11-07)

**Date:** 2026-11-07
**Status:** done, verified (unattended reboot proven, SSH working).
**Superseded in part:** the Guix layer described here was removed on
[`2026-11-08`](no-guix-2026-11-08.md) — Ralph is pacman only. Keep this file for
the Arch/LUKS/TPM2 half.
**Ticket:** none — greenfield; tracked in [`../../../TODO.md`](../../../TODO.md).

New mini PC arrived and became Ralph, the always-on server. This records the
setup so the box can be rebuilt from a USB stick without rediscovering the
sharp edges.

## Decisions and why

**Arch, not Debian/Ubuntu.** Explicitly requested, and the substrate barely
matters once Guix owns packages: Arch gives pacman for the handful of things
Guix cannot provide (kernel, firmware, cryptsetup, sshd) and nothing else.

**Guix as a foreign distro, not Guix System.** Requested shape. Guix's own
binary installer (`guix-install.sh`, 1.5.0) is used rather than the AUR `guix`
package, because that AUR package was flagged out of date at 1.4.0 while 1.5.0
was released. The installer puts `/gnu` and `/var/guix` on disk, creates the
`guix-daemon` systemd service and the build users, and verifies the GPG
signature of the release tarball — which it did, `PASS Signature is valid`.

**LUKS2 + TPM2 PCR 7 instead of no encryption or a passphrase.** A headless box
must reboot unattended, so a passphrase-only LUKS would mean a keyboard every
power cut. Keyslot 0 keeps the passphrase as the recovery path for exactly the
case the brief allows ("unless there is an error"). Keyslot 1 is the TPM2 token.

**btrfs subvolumes.** `@ @home @log @pkg @snapshots` with
`noatime,compress=zstd:3,ssd,discard=async`, so `/` can be snapshotted before a
pacman update without touching `/home` or the logs that explain what broke.

**systemd-boot with the ESP at `/boot`.** Kernel updates drop images where the
loader already looks; no GRUB script editing, no separate `/efi` to keep in sync.

**systemd initramfs (`sd-encrypt`), not the busybox `encrypt` hook.** Only the
systemd path reads `/etc/crypttab.initramfs`, and only that path can unseal a
`tpm2-device=auto` token.

**iwd + systemd-networkd, no NetworkManager.** iwd was already connected in the
live image, so the live `/var/lib/iwd/<ssid>.psk` is copied into the install and
the box comes up online at first boot with no credentials retyped.

**No swap, no snapper.** 15GB RAM on a 256GB SSD: nothing to hibernate to, and
page cache beats zram for a server. Snapper is deferred — Guix generations plus
manual `btrfs subvolume snapshot` already give rollback, and snapper's prescribing
is real complexity to bolt onto a box that is not yet running anything.

## What broke, and the fix

`ralph-arch-install.sh` died at line 120: `printf > /mnt/etc/iwd/main.conf` with
"No such file or directory". The `iwd` package does not ship `/etc/iwd`, and the
script assumed it did. Fix is `mkdir -p` before writing, now in the script. The
tail was re-run on the box as `ralph-finish.sh` rather than reinstalling.

`guix-install.sh` also aborted once on `Missing commands: wget`. `wget` is not
in Arch's `base`; `pacman -S wget` first.

`git.savannah.gnu.org` returned an HTML error page to Ralph's `curl` where it
served the real script to the laptop; the script was copied over `scp` instead.

## Verified

- `bootctl status` → systemd-boot, Secure Boot disabled (intentionally)
- `findmnt /` → `/dev/mapper/cryptroot[/@]`, btrfs, compression on
- `cryptsetup luksDump` → slots 0 (passphrase) and 1, token `systemd-tpm2`,
  `tpm2-hash-pcrs: 7`
- `systemctl --failed` → empty; `sshd iwd systemd-networkd systemd-resolved
  fstrim.timer` all enabled
- reboot from SSH → back in **26s**, no console interaction, same IP
- `guix --version` → 1.5.0, `guix-daemon` active

## Not done

- Secure Boot with own keys (`sbctl`) → would make PCR 7 meaningful
- Intel AMT → out-of-band console for LUKS-prompt failures
- static IP / DHCP reservation (currently `.26` by lease)
- host firewall on Ralph
- backups of `/home/andy` and `/var/lib`

## Gotcha for next time

`ftp.gnu.org` served the Guix tarball at **106 KB/s** (130MB in 21 minutes) while
the wifi link was -49 dBm and healthy. The bottleneck was the remote host, not
the link — do not go chasing signal strength for a slow download.
