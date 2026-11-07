#!/usr/bin/env bash
# Ralph — finish the install after ralph-arch-install.sh stopped at line 120.
# Idempotent: safe to run twice. Run as root from the live ISO.
set -euo pipefail
trap 'echo "!! FAILED at line $LINENO" >&2' ERR

USERNAME=andy
[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }
mountpoint -q /mnt || { echo "/mnt is not mounted — is the install still there?"; exit 1; }

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

mkdir -p /mnt/var/lib/iwd && chmod 700 /mnt/var/lib/iwd
cp -a /var/lib/iwd/*.psk /mnt/var/lib/iwd/ 2>/dev/null || echo "!! no iwd PSK found — wifi will need iwctl once"

cat > /mnt/etc/ssh/sshd_config.d/10-hardening.conf <<EOF
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers $USERNAME
EOF

rm -f /mnt/root/setup.sh

# --- checks ---------------------------------------------------------------
echo
echo "== wifi credentials";  ls /mnt/var/lib/iwd/ 2>/dev/null || echo "  NONE"
echo "== authorized_keys";   ls -l /mnt/home/$USERNAME/.ssh/authorized_keys 2>/dev/null || echo "  MISSING"
echo "== boot entries";      ls /mnt/boot/loader/entries/ 2>/dev/null || echo "  MISSING"
echo "== secured units";     arch-chroot /mnt systemctl is-enabled systemd-networkd iwd sshd 2>&1
echo "== luks slots";        cryptsetup luksDump /dev/nvme0n1p2 | grep -iE '^\s+[0-9]:|systemd-tpm2' || true
echo "== fstab root";        grep -E 'subvol=@\s' /mnt/etc/fstab || true
echo
echo "=== finish done ==="
