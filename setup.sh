#!/usr/bin/env bash

# =============================================================================
# setup.sh - Automação da configuração pessoal do CachyOs
#
# Fluxo:
#   1. Atualização do sistema  (sudo pacman -Syu --noconfirm)
#   2. Ranking de mirrors      (sudo cachyos-rate-mirrors)
#   3. Instalação de pacotes:
#      3a. Repositorio (pacman)  -> packages/pacman.txt
#      3b. AUR (yay)             -> packages/aur.txt
#      3c. Flatpak               -> packages/flatpak.txt
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Variáveis globais
# -----------------------------------------------------------------------------
DEBUG=false
DRY_RUN=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${SCRIPT_DIR}/packages"

# -----------------------------------------------------------------------------
# Funções auxiliares
# -----------------------------------------------------------------------------

# run_cmd: executa um comando (ou apenas o exibe em modo dry-run)
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

# is_installed: verifica (só leitura) se um pacote já está instalado
# Uso: is_installed <gestor> <nome>
# Nota: consultas de idempotência não alteram estado, por isso não passam por run_cmd
is_installed() {
    local pm="$1"
    local name="$2"

    case "$pm" in
        pacman | yay)
            pacman -Q "$name" &>/dev/null
            ;;
        flatpak)
            flatpak info "$name" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# read_package_file: imprime os pacotes válidos de um arquivo (ignora linhas vazias e comentários)
# Uso: read_package_file <arquivo>
read_package_file() {
    local file="$1"
    local pkg

    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" == \#* ]] && continue
        echo "$pkg"
    done < "$file"
}

# print_help: imprime a ajuda do script
print_help() {
    cat <<'EOF'
setup.sh - Automação da configuração pessoal do CachyOs

Uso:
  setup.sh [opções]

Opções:
  -n, --dry-run   Apenas exibe comandos sem executar
  -d, --debug     Ativa o modo debug com 'set -x'
  -h, --help      Exibe esta ajuda

Etapas:
  1. Atualização do sistema    (sudo pacman -Syu --noconfirm)
  2. Ranking de mirrors        (sudo cachyos-rate-mirrors)
  3. Instalação de pacotes:
     3a. Repositorio (pacman)  (packages/pacman.txt)
     3b. AUR (yay)             (packages/aur.txt)
     3c. Flatpak               (packages/flatpak.txt)
EOF
}

# parse_args: analisa os argumentos da linha de comando
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n | --dry-run)
                DRY_RUN=true
                shift
                ;;
            -d | --debug)
                DEBUG=true
                shift
                ;;
            -h | --help)
                print_help
                exit 0
                ;;
            *)
                echo "Erro: opção desconhecida '$1'" >&2
                print_help >&2
                exit 1
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Etapas de configuração
# -----------------------------------------------------------------------------

# setup_system_update: atualiza o sistema via pacman
setup_system_update() {
    echo ">>> [1/3] Atualizando o sistema..."
    run_cmd sudo pacman -Syu --noconfirm
    echo ">>> [1/3] Sistema atualizado"
}

# setup_mirrors: ranquea los mirrors do CachyOS
setup_mirrors() {
    echo ">>> [2/3] Ranqueando mirrors (cachyos-rate-mirrors)..."

    if ! command -v cachyos-rate-mirrors &>/dev/null; then
        echo ">>> Erro: 'cachyos-rate-mirrors' não está instalado" >&2
        exit 1
    fi

    run_cmd sudo cachyos-rate-mirrors
    echo ">>> [2/3] Mirrors ranqueados"
}

# setup_pacman_packages: instala os pacotes listados em packages/pacman.txt
setup_pacman_packages() {
    local file="${PACKAGES_DIR}/pacman.txt"
    local -a pkgs=()
    local -a to_install=()
    local pkg

    echo ">>> [3a/3] Instalando pacotes do repositório (pacman)..."

    if [[ ! -f "$file" ]]; then
        echo ">>> Erro: arquivo '$file' não encontrado" >&2
        exit 1
    fi

    mapfile -t pkgs < <(read_package_file "$file")

    for pkg in "${pkgs[@]}"; do
        if is_installed pacman "$pkg"; then
            echo ">>> [$pkg] já está instalado, omitindo"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ "${#to_install[@]}" -gt 0 ]]; then
        echo ">>> Instalando: ${to_install[*]}"
        run_cmd sudo pacman -S --needed --noconfirm "${to_install[@]}"
        echo ">>> [3a/3] Pacotes pacman instalados"
    else
        echo ">>> [3a/3] Nenhum pacote pacman pendente"
    fi
}

# setup_aur_packages: instala os pacotes AUR listados em packages/aur.txt via yay
setup_aur_packages() {
    local file="${PACKAGES_DIR}/aur.txt"
    local -a pkgs=()
    local -a to_install=()
    local pkg

    echo ">>> [3b/3] Instalando pacotes AUR (yay)..."

    if ! command -v yay &>/dev/null; then
        echo ">>> Erro: 'yay' não está instalado" >&2
        exit 1
    fi

    if [[ ! -f "$file" ]]; then
        echo ">>> Erro: arquivo '$file' não encontrado" >&2
        exit 1
    fi

    mapfile -t pkgs < <(read_package_file "$file")

    for pkg in "${pkgs[@]}"; do
        if is_installed yay "$pkg"; then
            echo ">>> [$pkg] já está instalado, omitendo"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ "${#to_install[@]}" -gt 0 ]]; then
        echo ">>> Instalando: ${to_install[*]}"
        # ATENÇÃO: yay JAMAIS deve ser executado com sudo
        run_cmd yay -S --needed --noconfirm "${to_install[@]}"
        echo ">>> [3b/3] Pacotes AUR instalados"
    else
        echo ">>> [3b/3] Nenhum pacote AUR pendente"
    fi
}

# setup_flatpak_packages: instala as aplicações Flatpak listadas em packages/flatpak.txt
setup_flatpak_packages() {
    local file="${PACKAGES_DIR}/flatpak.txt"
    local -a pkgs=()
    local -a to_install=()
    local pkg

    echo ">>> [3c/3] Instalando aplicações Flatpak..."

    if ! command -v flatpak &>/dev/null; then
        echo ">>> 'flatpak' não está instalado, omitendo etapa"
        return 0
    fi

    if [[ ! -f "$file" ]]; then
        echo ">>> Erro: arquivo '$file' não encontrado" >&2
        exit 1
    fi

    mapfile -t pkgs < <(read_package_file "$file")

    for pkg in "${pkgs[@]}"; do
        if is_installed flatpak "$pkg"; then
            echo ">>> [$pkg] já está instalado, omitendo"
        else
            to_install+=("$pkg")
        fi
    done

    if [[ "${#to_install[@]}" -gt 0 ]]; then
        echo ">>> Instalando: ${to_install[*]}"
        run_cmd sudo flatpak install --noninteractive flathub "${to_install[@]}"
        echo ">>> [3c/3] Aplicações Flatpak instaladas"
    else
        echo ">>> [3c/3] Nenhum Flatpak pendente"
    fi
}

# main: orquestra a execução do script
main() {
    parse_args "$@"

    if [[ "$DEBUG" == true ]]; then
        echo ">>> Executando em modo de debug"
        export PS4='+ [LINHA ${LINENO}] '
        set -x
    fi

    echo "=== Início da configuração de CachyOs ==="

    setup_system_update
    setup_mirrors
    setup_pacman_packages
    setup_aur_packages
    setup_flatpak_packages

    echo "=== Configuração concluida! ==="
}

main "$@"