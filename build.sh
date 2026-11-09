#!/usr/bin/env bash
# ============================================================
# Build Script - BC-250 Gaming ISO
# ============================================================
# Automatiza:
#   1. instalação das dependências de build no host (via sudo pacman);
#   2. compilação dos pacotes AUR / PKGBUILDs locais (makepkg, como usuário);
#   3. montagem de um repositório local usado apenas durante o build;
#   4. geração da ISO com mkarchiso.
#
# IMPORTANTE: rode como usuário normal (NÃO como root).
#   makepkg se recusa a rodar como root; mkarchiso funciona rootless.
# ============================================================

set -euo pipefail

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "\n${BLUE}==>${NC} $*"; }

# Remove um diretório criado pelo mkarchiso. O mkarchiso roda em user
# namespace e deixa diretórios com bits de escrita removidos (ex.: /dev, /proc
# com modo 0555), então um "rm -rf" comum falha com "Permissão negada".
# Nesse caso repetimos a remoção dentro do mesmo mapeamento de namespace.
clean_dir() {
    local dir="$1"
    [[ -e "$dir" ]] || return 0
    rm -rf "$dir" 2>/dev/null && return 0
    if command -v unshare >/dev/null 2>&1; then
        unshare --map-auto --map-root-user rm -rf "$dir" 2>/dev/null && return 0
    fi
    log_warn "Não foi possível remover completamente: $dir"
    return 0
}

PROFILE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$PROFILE_DIR/out"
WORK_DIR="$PROFILE_DIR/work"
LOCAL_REPO="$PROFILE_DIR/localrepo"
AUR_DIR="$PROFILE_DIR/.build/aur"
LOG_DIR="$PROFILE_DIR/.build/logs"

# Pacotes AUR reais (repositório aur.archlinux.org), compilados como usuário.
AUR_PACKAGES=(
    bc250-control-center-git
    cyan-skillfish-governor-smu
)

# PKGBUILDs locais simples (scripts), compilados a partir de pkgbuilds/.
SCRIPT_PACKAGES=(
    bc250-40cu-unlock
    bc250-core-unlock
    bc250-cu-live-manager
)

# Dependências do host necessárias para montar a ISO.
HOST_DEPS=(
    archiso mkinitcpio base-devel git curl wget
    diffutils patch bc python libnewt
    libxi libxrandr libglvnd libxcb libxkbcommon
    squashfs-tools libisoburn mtools dosfstools zstd
)

SKIP_DEPS=0
CLEAN=0
KEEP_WORK=0
WITH_EXTRA=0
RUN_ISO=1

EXTRA_PKGS=()
FAILED_PKGS=()

usage() {
    cat <<EOF
Uso: ./build.sh [opções]

Opções:
  --skip-deps     Não instala dependências do host via sudo pacman
  --clean         Remove work/, out/ e localrepo/ antes de começar
  --keep-work     Mantém o diretório work/ do mkarchiso após o build
  --with-extra    Tenta compilar também os PKGBUILDs experimentais de pkgbuilds/
  --no-iso        Apenas compila pacotes e prepara o repositório local
  -h, --help      Mostra esta ajuda

O script deve ser executado como usuário normal (NÃO root).
O sudo será solicitado apenas para instalar pacotes do sistema.
EOF
}

while (( $# )); do
    case "$1" in
        --skip-deps)  SKIP_DEPS=1 ;;
        --clean)      CLEAN=1 ;;
        --keep-work)  KEEP_WORK=1 ;;
        --with-extra) WITH_EXTRA=1 ;;
        --no-iso)     RUN_ISO=0 ;;
        -h|--help)    usage; exit 0 ;;
        *) log_error "Opção desconhecida: $1"; usage; exit 2 ;;
    esac
    shift
done

# ------------------------------------------------------------
# Verificações iniciais
# ------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
    log_error "Não execute este script como root."
    log_error "O makepkg recusa rodar como root. Rode como seu usuário normal:"
    log_error "    ./build.sh"
    exit 1
fi

for cmd in pacman makepkg repo-add mkarchiso mksquashfs xorriso; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Comando obrigatório não encontrado: $cmd"
        log_error "Rode sem --skip-deps para instalar as dependências."
        exit 1
    fi
done

for path in profiledef.sh packages.x86_64 pacman.conf airootfs efiboot syslinux; do
    if [[ ! -e "$PROFILE_DIR/$path" ]]; then
        log_error "Arquivo/diretório obrigatório do perfil ausente: $path"
        exit 1
    fi
done

mkdir -p "$OUT_DIR" "$LOG_DIR" "$AUR_DIR" "$LOCAL_REPO"

if (( CLEAN )); then
    log_step "Limpando artefatos anteriores"
    clean_dir "$WORK_DIR"
    clean_dir "$OUT_DIR"
    clean_dir "$LOCAL_REPO"
    mkdir -p "$OUT_DIR" "$LOCAL_REPO"
fi

# ------------------------------------------------------------
# Dependências do host
# ------------------------------------------------------------
install_dependencies() {
    log_step "Instalando dependências do host"
    log_info "Pacotes: ${HOST_DEPS[*]}"
    sudo pacman -S --needed --noconfirm "${HOST_DEPS[@]}"
}

# ------------------------------------------------------------
# Compilação de pacotes
# ------------------------------------------------------------
build_pkgbuild() {
    local dir="$1"
    local name
    name="$(basename "$dir")"
    local log_file="$LOG_DIR/${name}.log"

    if [[ ! -f "$dir/PKGBUILD" ]]; then
        log_warn "PKGBUILD não encontrado em $dir, pulando."
        return 1
    fi

    log_info "Compilando ${name}..."
    # --force garante que o artefato seja sempre regerado a partir do PKGBUILD atual.
    if ( cd "$dir" && makepkg -sf --noconfirm >"$log_file" 2>&1 ); then
        log_info "OK: ${name}"
        return 0
    else
        log_warn "Falha ao compilar ${name} (log: $log_file)"
        tail -n 25 "$log_file" | sed 's/^/    /'
        return 1
    fi
}

prepare_aur_pkg() {
    local pkg="$1"
    local dir="$AUR_DIR/$pkg"

    # Mensagens vão para stderr para não contaminar o caminho retornado no stdout.
    if [[ -d "$dir/.git" ]]; then
        log_info "Atualizando PKGBUILD AUR: $pkg" >&2
        git -C "$dir" pull --ff-only --quiet >&2 2>&1 \
            || log_warn "Não foi possível atualizar $pkg; usando versão local." >&2
    else
        log_info "Baixando PKGBUILD AUR: $pkg" >&2
        rm -rf "$dir"
        if ! git clone "https://aur.archlinux.org/${pkg}.git" "$dir" >&2 2>&1; then
            log_error "Falha ao clonar PKGBUILD AUR: $pkg" >&2
            return 1
        fi
    fi

    if [[ ! -f "$dir/PKGBUILD" ]]; then
        log_error "PKGBUILD AUR ausente: $pkg" >&2
        return 1
    fi

    printf '%s\n' "$dir"
}

collect_artifacts() {
    local dir="$1"
    local -a files=()
    mapfile -t files < <(find "$dir" -maxdepth 1 -type f -name '*.pkg.tar.zst' -print)
    if (( ${#files[@]} > 0 )); then
        cp -f "${files[@]}" "$LOCAL_REPO/"
    fi
}

# ------------------------------------------------------------
# Repositório local (usado apenas no build)
# ------------------------------------------------------------
setup_local_repo() {
    log_step "Montando repositório local"
    mkdir -p "$LOCAL_REPO"

    local -a pkgs=()
    mapfile -t pkgs < <(find "$LOCAL_REPO" -maxdepth 1 -type f -name '*.pkg.tar.zst' -print)

    if (( ${#pkgs[@]} == 0 )); then
        log_warn "Nenhum pacote local encontrado; o repositório local não será usado."
        rm -f "$LOCAL_REPO"/bc250-local.db* "$LOCAL_REPO"/bc250-local.files* 2>/dev/null || true
        return 0
    fi

    repo-add --quiet --remove "$LOCAL_REPO/bc250-local.db.tar.gz" "${pkgs[@]}"
    log_info "Repositório local: ${#pkgs[@]} pacote(s)."
}

write_build_pacman_conf() {
    local conf="$WORK_DIR/pacman-build.conf"
    mkdir -p "$WORK_DIR"
    cp "$PROFILE_DIR/pacman.conf" "$conf"

    if [[ -f "$LOCAL_REPO/bc250-local.db.tar.gz" ]]; then
        cat >>"$conf" <<EOF

[bc250-local]
SigLevel = Optional TrustAll
Server = file://$LOCAL_REPO
EOF
    fi

    printf '%s\n' "$conf"
}

# ------------------------------------------------------------
# Módulo nct6687 (sensores/fans)
# ------------------------------------------------------------
# O pacote linux-cachyos-bc250 já compila e empacota nct6687.ko
# (usr/lib/modules/<kver>/kernel/drivers/hwmon/nct6687.ko.zst), então não é
# necessário copiar o módulo DKMS do host (que poderia ter versão diferente).
install_nct6687_module() {
    log_step "Módulo nct6687 (sensores/fans)"

    # Remove cópias antigas de módulos DKMS do host, se existirem no overlay.
    rm -rf "$PROFILE_DIR"/airootfs/usr/lib/modules/*/updates/dkms/nct6687.ko* 2>/dev/null || true

    local repo_kver
    repo_kver="$(pacman -Si linux-cachyos-bc250 2>/dev/null \
        | awk -F': ' '/^Versão|^Version/{print $2; exit}')"
    log_info "Kernel do repositório: linux-cachyos-bc250 ${repo_kver:-desconhecido}"
    log_info "O driver nct6687 é fornecido pelo próprio pacote do kernel."
    log_info "Carregamento no boot: modules-load.d/nct6687.conf + bc250-load-modules.service."
}

# ------------------------------------------------------------
# Geração da ISO
# ------------------------------------------------------------
generate_iso() {
    local conf
    conf="$(write_build_pacman_conf)"

    local -a args=(-v -C "$conf" -o "$OUT_DIR" -w "$WORK_DIR")
    if (( ${#EXTRA_PKGS[@]} > 0 )); then
        args+=(-p "${EXTRA_PKGS[*]}")
    fi
    if (( ! KEEP_WORK )); then
        args+=(-r)
    fi

    log_step "Gerando ISO com mkarchiso"
    log_info "Pacotes extras: ${EXTRA_PKGS[*]:-nenhum}"
    log_info "Saída: $OUT_DIR"

    mkarchiso "${args[@]}" "$PROFILE_DIR"

    # O -r do mkarchiso pode falhar em diretórios com modo 0555 criados no
    # namespace; garantimos a limpeza com o helper acima.
    if (( ! KEEP_WORK )); then
        clean_dir "$WORK_DIR"
    fi
}

# ------------------------------------------------------------
# Fluxo principal
# ------------------------------------------------------------
main() {
    log_info "========================================"
    log_info " Build BC-250 Gaming ISO"
    log_info "========================================"
    log_info "Perfil: $PROFILE_DIR"

    if (( ! SKIP_DEPS )); then
        install_dependencies
    else
        log_warn "Pulando instalação de dependências (--skip-deps)."
    fi

    # Diretório de trabalho sempre limpo para evitar builds incrementais quebrados
    clean_dir "$WORK_DIR"

    log_step "Compilando pacotes AUR"
    local pkg dir
    for pkg in "${AUR_PACKAGES[@]}"; do
        if dir="$(prepare_aur_pkg "$pkg")"; then
            if build_pkgbuild "$dir"; then
                collect_artifacts "$dir"
                EXTRA_PKGS+=("$pkg")
            else
                FAILED_PKGS+=("$pkg")
            fi
        else
            FAILED_PKGS+=("$pkg")
        fi
    done

    log_step "Compilando PKGBUILDs locais"
    for pkg in "${SCRIPT_PACKAGES[@]}"; do
        dir="$PROFILE_DIR/pkgbuilds/$pkg"
        if build_pkgbuild "$dir"; then
            collect_artifacts "$dir"
            EXTRA_PKGS+=("$pkg")
        else
            FAILED_PKGS+=("$pkg")
        fi
    done

    if (( WITH_EXTRA )); then
        log_step "Compilando PKGBUILDs experimentais (--with-extra)"
        for dir in "$PROFILE_DIR"/pkgbuilds/*/; do
            [[ -f "$dir/PKGBUILD" ]] || continue
            pkg="$(basename "$dir")"
            # Já compilados acima
            [[ " ${SCRIPT_PACKAGES[*]} " == *" $pkg "* ]] && continue
            if build_pkgbuild "$dir"; then
                collect_artifacts "$dir"
                EXTRA_PKGS+=("$pkg")
            else
                FAILED_PKGS+=("$pkg")
            fi
        done
    fi

    setup_local_repo
    install_nct6687_module

    if (( RUN_ISO )); then
        generate_iso

        log_step "Build concluído"
        local iso
        iso="$(find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' | head -n1 || true)"
        if [[ -n "$iso" ]]; then
            log_info "ISO gerada: $iso"
            log_info "Tamanho: $(du -h "$iso" | cut -f1)"
            log_info "Teste com: ./test-qemu.sh"
        else
            log_error "mkarchiso terminou, mas nenhuma ISO foi encontrada em $OUT_DIR."
            exit 1
        fi
    else
        log_step "Pacotes prontos (--no-iso). Repositório local em $LOCAL_REPO"
    fi

    if (( ${#FAILED_PKGS[@]} > 0 )); then
        log_warn "Pacotes que falharam (não serão incluídos na ISO): ${FAILED_PKGS[*]}"
        log_warn "Logs em: $LOG_DIR"
    fi
}

main "$@"
