# CachyOs Setup - Guia para IA

Esse documento fornece um guia para modelos de IA trabalharem no CachyOs Setup.

## Overview

Este projeto consistem em um conjunto de arquivos de configuração pessoal (dotfiles) do CachyOs junto de um script para automatizar essa configuração, instalação de pacotes e programas utilitários.

## Estrutura

- `setup.sh`: contém o script de instalação e configuração
- Diretórios dedicados na raiz do projeto para cada recurso/programa (e.g. `zsh/`, `hyprland/`, `fastfetch/`).
- `packages/`: diretório contendo arquivos de texto (`pacman.txt`, `aur.txt`) com a lista de pacotes a serem instalados (um por linha).

## Stack

- **Linguagem:** shell script
- **Gerenciador de pacotes:** `pacman` e `yay` (AUR)
- **Linter de Qualidade:** `shellcheck`

## Comportamento & Segurança

- O script DEVE começar rigorosamente com `set -euo pipefail`
- Usar SEMPRE `run_cmd` para executar comandos, nunca chamar comandos diretamente (exceto `echo`)
- Antes de qualquer instalação de pacote ou cópia de arquivos, **verifique idempotência** (se o pacote já está instalado ou se o arquivo/diretório já existe)
- Imprimir mensagem clara de início e fim de etapa
- Arquivos de configuração DEVEM ser copiados (`cp -r`)
- Se uma pasta/arquivo de configuração já existir no sistema do usuário (ex: `~/.config/foo`), criar um backup com a extensão `*.bak` antes de sobrescrever ou criar links simbólicos.
- Permitir execução em _Dry Run_ (`--dry-run`) e _Debug_ (`--debug`).

## Padrões de Código e Sintaxe

- **ShellCheck:** Todo o código deve ser compatível e aprovado pelo `shellcheck`.
- **Aspas em Variáveis:** Todas as variáveis devem ser estritamente entreaspadas (ex: `"$VAR"` em vez de `$VAR`)
- **Funções Modulares:** Criar funções pequenas para cada ação. Funções de configuração devem seguir o padrão `setup_<recurso>` (ex: `setup_zsh`, `setup_hyprland`)
- **Orquestração:** Centralizar a lógica de execução dentro de uma função `main()`
- **Privilégios Root:**
  - Comandos do sistema que exigem root DEVEM usar `sudo` explícito dentro do `run_cmd` (ex: `run_cmd sudo pacman -S --needed --noconfirm <pkg>`)
  - **ATENÇÃO:** AUR helpers (`yay`) JAMAIS devem ser executados com `sudo`.
- **Instalação Não-Interativa:** Passar sempre as flags `--needed --noconfirm` para comandos de instalação
- **Pipes e Redirecionamentos:** Como `run_cmd` executa argumentos diretamente, comandos com pipes (`|`) ou redirecionamentos (`>`) devem ser encapsulados em funções auxiliares ou executados via `bash -c`

## Variáveis globais

Variáveis globals que devem ficar no topo do script:

- DEBUG (valor inicial `false`)
- DRY_RUN (valor inicial `false`)

## Flags

O script aceita estas flags via argumentos:

| Flag              | Descrição                          |
| ----------------- | ---------------------------------- |
| `--dry-run`, `-n` | Apenas exibe comandos sem executar |
| `--debug`, `-d`   | Ativa modo debug com `set -x`      |
| `--help`, `-h`    | Exibe ajuda                        |

## Implementação padrão

### Dry run

```bash
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}
```

### Debug

```bash
if [[ "$DEBUG" == true ]]; then
  echo ">>> Executando em modo de debug"
  export PS4='+ [LINHA ${LINENO}] '
  set -x
fi
```

## Fluxo de commits

- Todo commit DEVE seguir estritamente o padrão `conventional commits`

```
<tipo>[escopo opcional]: <descrição>

[corpo opcional]
```

- SEMPRE faça os commits em português, mantendo apenas o tipo em inglês (e.g. `feat`, `chore`...)
- Sempre crie branches separadas para cada funcionalidade (`feature/<nome>`) para permitir testes manuais em uma máquina virtual.
- Solicite aprovação do usuário para a tarefa antes de realizar o commit final e o push para o GitHub.
