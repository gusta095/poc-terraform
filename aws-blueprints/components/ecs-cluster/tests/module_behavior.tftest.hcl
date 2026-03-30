# ==============================================================================
# TESTES: Comportamento do módulo com diferentes configurações
#
# Estes testes exercitam o componente real com mock_provider, verificando que
# combinações de flags e configurações planejam sem erros.
#
# Como rodar:
#   cd components/containers/ecs/cluster
#   terraform test -filter=tests/module_behavior.tftest.hcl
# ==============================================================================

mock_provider "aws" {}

# Variáveis base válidas para todos os runs.
variables {
  environment  = "sandbox"
  cluster_name = "meu-cluster"
}

# ==============================================================================
# Configuração padrão
# ==============================================================================

run "configuracao_padrao_planeia_sem_erros" {
  command = plan
}

# ==============================================================================
# Observabilidade
# ==============================================================================

run "enhanced_observability_ativo_planeia_sem_erros" {
  command = plan

  variables {
    enhanced_observability = true
  }
}

# ==============================================================================
# Capacity providers — variações
# ==============================================================================

run "somente_fargate_planeia_sem_erros" {
  command = plan

  variables {
    cluster_capacity_providers = ["FARGATE"]

    default_capacity_provider_strategy = {
      FARGATE = {
        base   = 1
        weight = 1
      }
    }
  }
}

run "somente_fargate_spot_planeia_sem_erros" {
  command = plan

  variables {
    cluster_capacity_providers = ["FARGATE_SPOT"]

    default_capacity_provider_strategy = {
      FARGATE_SPOT = {
        weight = 1
      }
    }
  }
}

run "fargate_e_spot_com_estrategia_customizada_planejam_sem_erros" {
  command = plan

  variables {
    cluster_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

    default_capacity_provider_strategy = {
      FARGATE = {
        base   = 2
        weight = 3
      }
      FARGATE_SPOT = {
        weight = 1
      }
    }
  }
}

run "strategy_sem_base_planeia_sem_erros" {
  command = plan

  variables {
    default_capacity_provider_strategy = {
      FARGATE = {
        weight = 1
      }
    }
  }
}

run "strategy_sem_weight_planeia_sem_erros" {
  command = plan

  variables {
    default_capacity_provider_strategy = {
      FARGATE = {
        base = 0
      }
    }
  }
}

# ==============================================================================
# Log retention — boundary values
# ==============================================================================

run "log_retention_1_dia_planeia_sem_erros" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = 1
  }
}

run "log_retention_30_dias_planeia_sem_erros" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = 30
  }
}

run "log_retention_365_dias_planeia_sem_erros" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = 365
  }
}

# ==============================================================================
# Tags customizadas
# ==============================================================================

run "tags_customizadas_planejam_sem_erros" {
  command = plan

  variables {
    tags = {
      team        = "platform"
      cost-center = "infra-001"
    }
  }
}

# ==============================================================================
# Configuração completa
# ==============================================================================

run "configuracao_completa_planeia_sem_erros" {
  command = plan

  variables {
    cluster_name = "producao-api"

    enhanced_observability = true

    cloudwatch_log_group_retention_in_days = 90

    cluster_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

    default_capacity_provider_strategy = {
      FARGATE = {
        base   = 2
        weight = 3
      }
      FARGATE_SPOT = {
        weight = 1
      }
    }

    tags = {
      team        = "platform"
      cost-center = "infra-001"
    }
  }
}
