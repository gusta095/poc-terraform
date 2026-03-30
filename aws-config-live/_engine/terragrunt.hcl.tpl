# ============================================================
# GERADO AUTOMATICAMENTE — não edite este arquivo.
# Edite o arquivo YAML neste diretório e rode: tg-init
# ============================================================

locals {
  # Busca o primeiro .yml/.yaml do diretório e carrega como objeto
  _yaml_files = tolist(setunion(fileset(get_terragrunt_dir(), "*.yml"), fileset(get_terragrunt_dir(), "*.yaml")))
  config      = yamldecode(file("${get_terragrunt_dir()}/${local._yaml_files[0]}"))
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

__DEP_SECTION__terraform {
  source = "git::https://github.com/gusta-lab/terraform-aws-blueprints.git//components/${local.config.kind}?ref=v${local.config.version}"
}

__INPUTS_BLOCK__
