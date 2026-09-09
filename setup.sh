#!/usr/bin/env bash

# =============================================================================
# setup.sh - Automação da configuração pessoal do CachyOs
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Variáveis globais
# -----------------------------------------------------------------------------
DEBUG=false
DRY_RUN=false

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
EOF
}

# parse_args: analiza os argumentos da linha de comando
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

# main: orquesta a execução do script
main() {
    parse_args "$@"

    if [[ "$DEBUG" == true ]]; then
        echo ">>> Executando em modo de debug"
        export PS4='+ [LINHA ${LINENO}] '
        set -x
    fi

    echo "Hello World!"
}

main "$@"