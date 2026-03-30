#!/usr/bin/env python3
"""
tg-init — Gerador de stubs Terragrunt a partir de arquivos YAML declarativos.

Converte arquivos YAML de componentes em `terragrunt.hcl` prontos para uso,
eliminando a necessidade de escrever HCL manualmente para novos recursos.

Features:
  - Geração automática do stub a partir do YAML (kind, version, spec)
  - Resolução de dependências por nome curto ('gustalab-xyz') ou sufixo
    ('public/gustalab-xyz') — sem caminhos relativos longos
  - Scaffold recursivo de dependências: garante que todas as deps também
    tenham terragrunt.hcl antes do terragrunt plan/apply
  - Âncora automática em account.hcl via format() — robusto a refatorações
    de estrutura de diretórios
  - Retrocompatível com caminhos relativos legados (começam com '..')
  - Idempotente: não sobrescreve se o conteúdo já estiver atualizado
  - Modo recursivo: quando rodado num diretório pai, processa todos os
    subdiretórios com YAML automaticamente
"""

import sys
import subprocess
import yaml
from pathlib import Path

# Cores para output no terminal
VERDE    = "\033[1;32m"
VERMELHO = "\033[1;31m"
CIANO    = "\033[1;36m"
NEGRITO  = "\033[1m"
RESET    = "\033[0m"

# Diretórios ignorados na busca recursiva (caches do terraform/terragrunt)
DIRS_IGNORADOS = {".terragrunt-cache", ".terraform"}

# ---------------------------------------------------------------------------
# Funções auxiliares
# ---------------------------------------------------------------------------

def find_repo_root() -> Path:
    """Retorna a raiz do repositório git ou encerra com mensagem de erro."""
    resultado = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if resultado.returncode != 0:
        sys.exit(f"{VERMELHO}❌ Raiz do repositório git não encontrada.{RESET}")
    return Path(resultado.stdout.strip())

def collect_yaml_dirs(base: Path) -> list[Path]:
    """
    Retorna lista de diretórios que contêm YAML de componente.
    - Se o próprio diretório base contiver YAML → retorna só ele.
    - Caso contrário → busca recursiva, excluindo caches.
    """
    # Verifica o próprio diretório antes de buscar recursivamente
    if any(base.glob("*.yml")) or any(base.glob("*.yaml")):
        return [base]

    dirs_vistos: set[Path] = set()
    dirs_encontrados: list[Path] = []

    todos_yamls = sorted(base.rglob("*.yml")) + sorted(base.rglob("*.yaml"))
    for yaml_file in todos_yamls:
        # Ignora arquivos dentro de diretórios de cache
        if DIRS_IGNORADOS.intersection(yaml_file.relative_to(base).parts):
            continue
        dir_pai = yaml_file.parent
        if dir_pai not in dirs_vistos:
            dirs_vistos.add(dir_pai)
            dirs_encontrados.append(dir_pai)
    return dirs_encontrados

def find_yaml(diretorio: Path) -> Path | None:
    """Retorna o primeiro arquivo YAML encontrado no diretório, ou None."""
    return next(diretorio.glob("*.yml"), None) or next(diretorio.glob("*.yaml"), None)

# ---------------------------------------------------------------------------
# Índice de diretórios do repo (construído uma vez por execução)
# ---------------------------------------------------------------------------

def build_dir_index(repo_root: Path) -> list[Path]:
    """Retorna todos os diretórios do repo, excluindo caches."""
    return [
        p for p in repo_root.rglob("*")
        if p.is_dir() and not DIRS_IGNORADOS.intersection(p.parts)
    ]

# ---------------------------------------------------------------------------
# Resolução de nome curto para config_path
# ---------------------------------------------------------------------------

def _search_dir_index(short: str, dir_index: list[Path], repo_root: Path) -> list[Path]:
    """Busca no índice de diretórios pelo sufixo informado. Suporta nome exato
    ('gustalab-xyz') ou sufixo parcial ('public/gustalab-xyz') para desambiguar."""
    return [
        p for p in dir_index
        if str(p.relative_to(repo_root)) == short
        or str(p.relative_to(repo_root)).endswith("/" + short)
    ]

def get_dep_dirs(dep_list: list, dir_index: list[Path], repo_root: Path, caller_dir: Path) -> list[Path]:
    """Retorna os Path absolutos das dependências declaradas (para scaffold recursivo)."""
    dirs = []
    for item in dep_list:
        for _, path_str in item.items():
            path_str = str(path_str)
            if path_str.startswith(".."):
                dirs.append((caller_dir / path_str).resolve())
            else:
                matches = _search_dir_index(path_str.strip("/"), dir_index, repo_root)
                if len(matches) == 1:
                    dirs.append(matches[0])
    return dirs

def find_dep_path(short_name: str, dir_index: list[Path], repo_root: Path, caller_dir: Path) -> str:
    """
    Resolve nome curto ('gustalab-xyz' ou 'public/gustalab-xyz') para uma
    expressão format() do Terragrunt ancorada em account.hcl.
    Caminhos relativos (começam com '..') são retornados como estão.
    """
    if short_name.startswith(".."):
        return f'"{short_name}"'

    matches = _search_dir_index(short_name.strip("/"), dir_index, repo_root)

    if len(matches) == 0:
        sys.exit(f"{VERMELHO}❌ Dependência não encontrada: '{short_name}'{RESET}")
    if len(matches) > 1:
        sugestoes = "\n".join(f"   - {p.relative_to(repo_root)}" for p in matches)
        sys.exit(
            f"{VERMELHO}❌ Ambíguo: '{short_name}' encontrou {len(matches)} matches:\n"
            f"{sugestoes}\n"
            f"   Seja mais específico.{RESET}"
        )

    target = matches[0]
    account_root = next(
        (p for p in [caller_dir, *caller_dir.parents] if (p / "account.hcl").exists()),
        None,
    )
    if account_root is None:
        sys.exit(f"{VERMELHO}❌ account.hcl não encontrado acima de {caller_dir}{RESET}")

    rel = target.relative_to(account_root)
    return f'format("%s/{rel}", dirname(find_in_parent_folders("account.hcl")))'

# ---------------------------------------------------------------------------
# Geração dos blocos de dependency
# ---------------------------------------------------------------------------

def build_dependency_blocks(dep_list: list, dir_index: list[Path], repo_root: Path, caller_dir: Path) -> tuple[str, str]:
    """
    Gera blocos `dependency "name" {}` a partir de uma lista de {name: path}.
    Retorna (dep_section, inputs_block).
    """
    blocos = []
    nomes  = []

    for item in dep_list:
        for nome, path in item.items():
            nomes.append(nome)
            config_path = find_dep_path(str(path), dir_index, repo_root, caller_dir)
            blocos.append(f'dependency "{nome}" {{\n  config_path = {config_path}\n}}')

    dep_section  = "\n\n".join(blocos)
    merge_args   = ",\n  ".join([f"dependency.{n}.outputs" for n in nomes] + ["local.config.spec"])
    inputs_block = f"inputs = merge(\n  {merge_args}\n)"
    return dep_section, inputs_block

def resolve_deps(config: dict, dir_index: list[Path], repo_root: Path, caller_dir: Path) -> tuple[str, str]:
    """
    Gera (dep_section, inputs_block) a partir da chave 'dependency' do YAML.
    Se ausente, retorna strings vazias (sem deps).
    """
    dep_obj = config.get("dependency", [])
    if dep_obj:
        return build_dependency_blocks(dep_obj, dir_index, repo_root, caller_dir)
    return "", "inputs = local.config.spec"

# ---------------------------------------------------------------------------
# Renderização e escrita do stub
# ---------------------------------------------------------------------------

def render_template(template: str, dep_section: str, inputs_block: str) -> str:
    """
    Substitui os placeholders __DEP_SECTION__ e __INPUTS_BLOCK__ no template.
    Se não houver deps, __DEP_SECTION__ vira string vazia (sem linha em branco extra).
    """
    sep      = dep_section + "\n\n" if dep_section else ""
    conteudo = template.replace("__DEP_SECTION__", sep)
    conteudo = conteudo.replace("__INPUTS_BLOCK__", inputs_block)
    return conteudo

def scaffold_dir(diretorio: Path, template: str, dir_index: list[Path], repo_root: Path, visited: set | None = None) -> None:
    """Gera ou atualiza o terragrunt.hcl em um diretório. Operação idempotente."""
    if visited is None:
        visited = set()
    if diretorio in visited:
        return
    visited.add(diretorio)

    stub = diretorio / "terragrunt.hcl"

    yaml_file = find_yaml(diretorio)
    if not yaml_file:
        print(f"  {VERMELHO}❌ YAML não encontrado em: {diretorio}{RESET}", file=sys.stderr)
        return

    with open(yaml_file) as f:
        config = yaml.safe_load(f)

    dep_section, inputs_block = resolve_deps(config, dir_index, repo_root, diretorio)
    novo_conteudo = render_template(template, dep_section, inputs_block)

    # Idempotente: não sobrescreve se o conteúdo for idêntico
    if stub.exists() and stub.read_text() == novo_conteudo:
        print(f"  {VERDE}✅ já atualizado:{RESET} {diretorio}")
    else:
        acao   = "Atualizado" if stub.exists() else "Criado"
        sufixo = f" {CIANO}(com dependencies){RESET}" if dep_section else ""
        stub.write_text(novo_conteudo)
        print(f"  {VERDE}✅ {acao}{sufixo}:{RESET} {stub}")

    # Scaffold recursivo das dependências
    dep_dirs = get_dep_dirs(config.get("dependency", []), dir_index, repo_root, diretorio)
    for dep_dir in dep_dirs:
        if find_yaml(dep_dir):
            scaffold_dir(dep_dir, template, dir_index, repo_root, visited)

# ---------------------------------------------------------------------------
# Orquestração principal
# ---------------------------------------------------------------------------

def main() -> None:
    diretorio_alvo = Path.cwd()
    raiz_repo      = find_repo_root()
    caminho_tpl    = raiz_repo / "_engine" / "terragrunt.hcl.tpl"

    if not caminho_tpl.exists():
        sys.exit(f"{VERMELHO}❌ Template não encontrado: {caminho_tpl}{RESET}")

    template = caminho_tpl.read_text()

    dirs = collect_yaml_dirs(diretorio_alvo)
    if not dirs:
        sys.exit(
            f"{VERMELHO}❌ Nenhum YAML encontrado em {diretorio_alvo}\n"
            f"   Crie o YAML do componente antes de rodar tg-init.{RESET}"
        )

    dir_index = build_dir_index(raiz_repo)

    print(f"\n{NEGRITO}🚀 tg-init{RESET} — {CIANO}{diretorio_alvo}{RESET}")
    print(f"{NEGRITO}   {len(dirs)} diretório(s) encontrado(s){RESET}\n")

    visited: set[Path] = set()
    for diretorio in dirs:
        scaffold_dir(diretorio, template, dir_index, raiz_repo, visited)
    print()

if __name__ == "__main__":
    main()
