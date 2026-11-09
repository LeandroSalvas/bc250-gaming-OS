#!/usr/bin/env bash
# shellcheck disable=SC2034
# ============================================================
# BC-250 Gaming ISO - archiso profile definition
# Baseado no perfil releng oficial do archiso.
# ============================================================

iso_name="bc250-gaming"
iso_label="BC250GAMING_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Projeto BC-250 <https://github.com/MastaG/linux-cachyos-bc250>"
iso_application="BC-250 Gaming Live/Install ISO"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/bc250-live-setup"]="0:0:755"
  ["/usr/local/bin/bc250-load-modules"]="0:0:755"
  ["/usr/local/bin/bc250-welcome"]="0:0:755"
  ["/usr/local/bin/bc250-cleanup-target"]="0:0:755"
  ["/etc/skel/Desktop/install-system.desktop"]="0:0:755"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/deck"]="0:0:440"
)
