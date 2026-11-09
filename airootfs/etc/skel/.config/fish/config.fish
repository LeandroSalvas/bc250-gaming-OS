# ============================================================
# Fish - configuração do usuário live "deck" (BC-250 Gaming)
# ============================================================

set -gx PATH /usr/local/bin $PATH
set -gx XDG_CURRENT_DESKTOP KDE
set -gx GTK_THEME Breeze-Dark

# --- Atualização do sistema ---
alias update "sudo pacman -Syu"

# --- Ferramentas BC-250 realmente incluídas ---
alias bc-control "bc250-control-center"
alias bc-cu-live "sudo bc250-cu-live-manager"
alias bc-cores "sudo bc250-unlock-cores"
alias bc-governor "systemctl --user status cyan-skillfish-governor-smu 2>/dev/null; systemctl status cyan-skillfish-governor-smu 2>/dev/null"

# --- Sensores / monitoramento ---
alias temps "sensors 2>/dev/null || echo 'Execute: sudo modprobe nct6687'"
alias gpu "cat /sys/class/drm/card*/device/pp_dpm_sclk 2>/dev/null"

# --- Informações rápidas ---
alias bc-info "echo 'BC-250 Gaming'; uname -r; echo; lspci -nn | grep -iE 'vga|display'"

# Mensagem de boas-vindas (apenas em shell interativo)
if status is-interactive
    echo "========================================="
    echo "  Boas-vindas ao BC-250 Gaming ISO!"
    echo "  Usuário: deck"
    echo "  Kernel:  "(uname -r)
    echo "  Ambiente: KDE Plasma"
    echo "========================================="
end
