#!/usr/bin/env bash
# Ralph — minimal headless Arch install for the Dell OptiPlex 7070 Micro.
# Run from the Arch live ISO as root:  bash ralph-arch-install.sh
# WIPES /dev/nvme0n1. LUKS2 on root, TPM2 (PCR 7) auto-unlock so it still boots
# unattended; the passphrase keyslot stays as the recovery path.
set -euo pipefail
trap 'echo "!! FAILED at line $LINENO" >&2' ERR

DISK=/dev/nvme0n1
HOSTNAME=ralph
USERNAME=andy
TIMEZONE=Australia/Sydney        # change if wrong
LOCALE=en_AU.UTF-8               # change if wrong
KERNEL=linux-lts
CRYPTNAME=cryptroot              # LUKS on the root partition, TPM2 auto-unlock
NOPASSWD_SUDO=1                  # 0 = sudo asks for password
PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEWOSsTOrKgUOqchahfAl+tm0KCHjTiJGR9rIgMVD6jP andy@framework'

[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }
[[ -d /run/archiso ]] || { echo "this is meant for the live ISO"; exit 1; }

# --- safety: refuse anything that isn't the small internal NVMe ------------
SIZE=$(lsblk -bndo SIZE "$DISK")
MODEL=$(lsblk -ndo MODEL "$DISK" | xargs)
TRAN=$(lsblk -ndo TRAN "$DISK")
(( SIZE < 400*1000*1000*1000 )) || { echo "$DISK is $SIZE bytes — too big, refusing"; exit 1; }
[[ $TRAN != usb ]] || { echo "$DISK is USB — refusing"; exit 1; }
echo "Target: $DISK — $MODEL, $((SIZE/1000/1000/1000))GB"
read -rp "Type WIPE to destroy it: " ok; [[ $ok == WIPE ]] || exit 1

# --- partition + filesystems ----------------------------------------------
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI "$DISK"
sgdisk -n2:0:0    -t2:8300 -c2:ROOT "$DISK"
partprobe "$DISK"; udevadm settle

mkfs.fat -F32 -n EFI "${DISK}p1"
cryptsetup close $CRYPTNAME 2>/dev/null || true
echo "== LUKS passphrase (keyslot 0, kept as the fallback for broken TPM) =="
cryptsetup luksFormat --type luks2 "${DISK}p2"
cryptsetup open "${DISK}p2" $CRYPTNAME
DEV=/dev/mapper/$CRYPTNAME
mkfs.btrfs -L ralph -f "$DEV"

OPTS="noatime,compress=zstd:3,ssd,discard=async"
mount "$DEV" /mnt
btrfs subvolume create /mnt/@{,home,log,pkg,snapshots}
umount /mnt
mount -o "$OPTS",subvol=@ "$DEV" /mnt
mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
mount -o "$OPTS",subvol=@home      "$DEV" /mnt/home
mount -o "$OPTS",subvol=@log       "$DEV" /mnt/var/log
mount -o "$OPTS",subvol=@pkg       "$DEV" /mnt/var/cache/pacman/pkg
mount -o "$OPTS",subvol=@snapshots "$DEV" /mnt/.snapshots
mount "${DISK}p1" /mnt/boot                       # ESP at /boot = lazy systemd-boot

# --- base system ----------------------------------------------------------
pacstrap -K /mnt base base-devel "$KERNEL" "${KERNEL}-headers" linux-firmware \
  intel-ucode btrfs-progs cryptsetup tpm2-tss tpm2-tools iwd openssh sudo git vim
genfstab -U /mnt >> /mnt/etc/fstab

# root lives on the mapper, LUKS device opening is done in initramfs
ROOT_UUID=$(blkid -s UUID -o value "$DEV")
LUKS_UUID=$(blkid -s UUID -o value "${DISK}p2")

# systemd-based initramfs so sd-encrypt can unseal the TPM2 keyslot
sed -i 's/^MODULES=.*/MODULES=(tpm_tis tpm_crb)/' /mnt/etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard block sd-encrypt filesystems fsck)/' \
  /mnt/etc/mkinitcpio.conf
printf '%s UUID=%s none luks,discard,tpm2-device=auto\n' \
  "$CRYPTNAME" "$LUKS_UUID" > /mnt/etc/crypttab.initramfs

cat > /mnt/root/setup.sh <<EOF
set -euo pipefail
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i "s/^#\($LOCALE\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' $HOSTNAME $HOSTNAME > /etc/hosts

echo 'root password:'; passwd
useradd -m -G wheel -s /bin/bash $USERNAME
echo '$USERNAME password:'; passwd $USERNAME
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

install -d -m 700 /home/$USERNAME/.ssh
echo '$PUBKEY' > /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys
EOF
[[ $NOPASSWD_SUDO == 1 ]] || sed -i 's/NOPASSWD: ALL/ALL/' /mnt/root/setup.sh
chmod +x /mnt/root/setup.sh
arch-chroot /mnt /root/setup.sh

# --- bootloader -----------------------------------------------------------
arch-chroot /mnt bootctl install
cat > /mnt/boot/loader/loader.conf <<'EOF'
default arch-lts.conf
timeout 3
editor no
EOF
cat > /mnt/boot/loader/entries/arch-lts.conf <<EOF
title   Arch Linux (LTS)
linux   /vmlinuz-$KERNEL
initrd  /intel-ucode.img
initrd  /initramfs-$KERNEL.img
options root=/dev/mapper/$CRYPTNAME rw rootflags=subvol=@ quiet nowatchdog
EOF
arch-chroot /mnt mkinitcpio -P

# --- TPM2 auto-unlock: unattended boot, passphrase still works if it breaks ---
echo "== enrolling TPM2 keyslot (PCR 7), re-enter the LUKS passphrase =="
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "${DISK}p2"
cryptsetup luksDump "${DISK}p2" | grep -E '^\s+[0-9]+: luks2'

# --- networking: iwd (wifi) + systemd-networkd, DHCP on anything ----------
mkdir -p /mnt/etc/iwd /mnt/etc/systemd/network /mnt/etc/ssh/sshd_config.d
printf '[General]\nEnableNetworkConfiguration=false\n' > /mnt/etc/iwd/main.conf
cat > /mnt/etc/systemd/network/25-wired.network <<'EOF'
[Match]
Name=en* eth*
[Network]
DHCP=yes
EOF
cat > /mnt/etc/systemd/network/25-wireless.network <<'EOF'
[Match]
Name=wl*
[Network]
DHCP=yes
[DHCPv4]
RouteMetric=600
EOF
ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
arch-chroot /mnt systemctl enable systemd-networkd systemd-resolved iwd \
  systemd-timesyncd sshd fstrim.timer

# carry the live ISO's wifi credentials over so the box comes up online
mkdir -p /mnt/var/lib/iwd && chmod 700 /mnt/var/lib/iwd
cp -a /var/lib/iwd/*.psk /mnt/var/lib/iwd/ 2>/dev/null || echo "!! no iwd PSK found — wifi will need nmtui/iwctl once"

# --- ssh: key only --------------------------------------------------------
cat > /mnt/etc/ssh/sshd_config.d/10-hardening.conf <<EOF
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers $USERNAME
EOF

rm -f /mnt/root/setup.sh
echo
echo "=== done. LUKS UUID=$LUKS_UUID, root=/dev/mapper/$CRYPTNAME ==="
echo "reboot, pull the USB, F12 -> internal drive"
