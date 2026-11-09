#!/usr/bin/env bash
# ============================================================
# Teste da ISO BC-250 Gaming em QEMU
# ============================================================
# Uso: ./test-qemu.sh [caminho-da-iso]
# Requer: qemu-full (ou qemu-desktop) e, para UEFI, edk2-ovmf.
#   sudo pacman -S --needed qemu-full edk2-ovmf
# ============================================================

set -euo pipefail

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

PROFILE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------
# Localiza a ISO
# ------------------------------------------------------------
ISO="${1:-}"
if [[ -z "$ISO" ]]; then
    ISO="$(find "$PROFILE_DIR/out" -maxdepth 1 -type f -name 'bc250-gaming-*.iso' 2>/dev/null | sort | tail -n1 || true)"
fi

if [[ -z "$ISO" || ! -f "$ISO" ]]; then
    log_error "ISO não encontrada."
    log_error "Execute ./build.sh primeiro para gerar a ISO em out/."
    exit 1
fi

# ------------------------------------------------------------
# Verifica QEMU
# ------------------------------------------------------------
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    log_error "qemu-system-x86_64 não encontrado."
    log_error "Instale com: sudo pacman -S --needed qemu-full edk2-ovmf"
    exit 1
fi

# ------------------------------------------------------------
# Aceleração
# ------------------------------------------------------------
ACCEL=()
CPU=()
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    ACCEL=(-accel kvm)
    CPU=(-cpu host)
    log_info "Aceleração KVM disponível."
else
    ACCEL=(-accel tcg)
    CPU=(-cpu max)
    log_warn "KVM indisponível (/dev/kvm ausente ou sem permissão). Usando emulação TCG (lenta)."
    log_warn "Para habilitar: adicione seu usuário ao grupo kvm e garanta que a virtualização esteja ativa."
fi

# ------------------------------------------------------------
# Firmware (UEFI se OVMF estiver disponível; senão SeaBIOS)
# ------------------------------------------------------------
FIRMWARE=()
for ovmf in \
    /usr/share/edk2/x64/OVMF.fd \
    /usr/share/edk2-ovmf/x64/OVMF.fd \
    /usr/share/ovmf/x64/OVMF.fd; do
    if [[ -f "$ovmf" ]]; then
        FIRMWARE=(-bios "$ovmf")
        log_info "Firmware UEFI: $ovmf"
        break
    fi
done
if (( ${#FIRMWARE[@]} == 0 )); then
    log_warn "OVMF não encontrado; usando BIOS padrão (SeaBIOS)."
    log_warn "Para UEFI: sudo pacman -S --needed edk2-ovmf"
fi

# ------------------------------------------------------------
# Display
# ------------------------------------------------------------
DISPLAY_ARGS=()
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    DISPLAY_ARGS=(-display gtk)
elif [[ -n "${DISPLAY:-}" ]]; then
    DISPLAY_ARGS=(-display gtk)
else
    DISPLAY_ARGS=(-display none -vnc 127.0.0.1:0)
    log_warn "Nenhum display gráfico detectado. Usando VNC em 127.0.0.1:0."
fi

log_info "=========================================="
log_info " ISO:      $ISO"
log_info " Memória:  4G"
log_info " CPUs:     4"
log_info " Saída:    Ctrl+A, X para encerrar (console) / feche a janela"
log_info "=========================================="

exec qemu-system-x86_64 \
    "${ACCEL[@]}" \
    "${CPU[@]}" \
    -m 4G \
    -smp 4 \
    -cdrom "$ISO" \
    -boot d \
    -vga std \
    "${DISPLAY_ARGS[@]}" \
    -usb \
    -device usb-tablet \
    -device usb-kbd \
    -netdev user,id=net0 \
    -device rtl8139,netdev=net0 \
    "${FIRMWARE[@]}"
