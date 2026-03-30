# ==============================================================================
# TESTES: Regras de validação das variáveis do componente
#
# Estes testes verificam que o Terraform rejeita valores fora dos limites
# definidos nos blocos `validation` e `terraform_data` preconditions.
#
# Como funciona:
#   expect_failures = [var.nome]                     → validation block
#   expect_failures = [resource.terraform_data.nome] → precondition
#   Se o plan não falhar como esperado, o teste falha.
#
# Como rodar:
#   cd components/containers/ecs/cluster
#   terraform test -filter=tests/variable_validations.tftest.hcl
# ==============================================================================

mock_provider "aws" {}

# Variáveis base válidas. Cada run sobrescreve apenas a variável em teste.
variables {
  environment  = "sandbox"
  cluster_name = "meu-cluster"
}

# ==============================================================================
# cluster_name — tamanho
# ==============================================================================

run "cluster_name_vazio_deve_falhar" {
  command = plan

  variables {
    cluster_name = ""
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_muito_longo_deve_falhar" {
  command = plan

  variables {
    # 256 caracteres — limite é 255
    cluster_name = "a${join("", [for i in range(255) : "b"])}"
  }

  expect_failures = [var.cluster_name]
}

# ==============================================================================
# cluster_name — formato (regex)
# ==============================================================================

run "cluster_name_comecando_com_numero_deve_falhar" {
  command = plan

  variables {
    cluster_name = "1meu-cluster"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_comecando_com_hifen_deve_falhar" {
  command = plan

  variables {
    cluster_name = "-meu-cluster"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_com_caracter_especial_deve_falhar" {
  command = plan

  variables {
    cluster_name = "cluster@prod"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_com_espaco_deve_falhar" {
  command = plan

  variables {
    cluster_name = "meu cluster"
  }

  expect_failures = [var.cluster_name]
}

run "cluster_name_valido_com_hifen_deve_passar" {
  command = plan

  variables {
    cluster_name = "producao-api"
  }
}

run "cluster_name_valido_com_underline_deve_passar" {
  command = plan

  variables {
    cluster_name = "producao_api"
  }
}

run "cluster_name_valido_alfanumerico_deve_passar" {
  command = plan

  variables {
    cluster_name = "cluster01"
  }
}

# ==============================================================================
# cloudwatch_log_group_retention_in_days — valores inválidos
# ==============================================================================

run "log_retention_invalido_deve_falhar" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = 10
  }

  expect_failures = [var.cloudwatch_log_group_retention_in_days]
}

run "log_retention_zero_deve_falhar" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = 0
  }

  expect_failures = [var.cloudwatch_log_group_retention_in_days]
}

run "log_retention_negativo_deve_falhar" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = -1
  }

  expect_failures = [var.cloudwatch_log_group_retention_in_days]
}

run "log_retention_999_deve_falhar" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = 999
  }

  expect_failures = [var.cloudwatch_log_group_retention_in_days]
}

run "log_retention_1_deve_passar" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = 1
  }
}

run "log_retention_365_deve_passar" {
  command = plan

  variables {
    cloudwatch_log_group_retention_in_days = 365
  }
}

# ==============================================================================
# cluster_capacity_providers — valores inválidos
# ==============================================================================

run "capacity_provider_ec2_invalido_deve_falhar" {
  command = plan

  variables {
    cluster_capacity_providers = ["EC2"]
    default_capacity_provider_strategy = {
      FARGATE = { weight = 1 }
    }
  }

  expect_failures = [var.cluster_capacity_providers]
}

run "capacity_provider_desconhecido_deve_falhar" {
  command = plan

  variables {
    cluster_capacity_providers = ["FARGATE", "CUSTOM"]
    default_capacity_provider_strategy = {
      FARGATE = { weight = 1 }
    }
  }

  expect_failures = [var.cluster_capacity_providers]
}

run "capacity_providers_duplicados_devem_falhar" {
  command = plan

  variables {
    cluster_capacity_providers = ["FARGATE", "FARGATE"]
  }

  expect_failures = [var.cluster_capacity_providers]
}

run "capacity_providers_validos_devem_passar" {
  command = plan

  variables {
    cluster_capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  }
}

# ==============================================================================
# Precondition: strategy com provider não listado em cluster_capacity_providers
# ==============================================================================

run "strategy_com_provider_nao_listado_deve_falhar" {
  command = plan

  variables {
    cluster_capacity_providers = ["FARGATE"]

    default_capacity_provider_strategy = {
      FARGATE_SPOT = {
        weight = 1
      }
    }
  }

  expect_failures = [resource.terraform_data.validate_capacity_provider_strategy]
}

run "strategy_alinhada_com_providers_deve_passar" {
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

# ==============================================================================
# Precondition: base e weight devem ser >= 0
# ==============================================================================

run "strategy_base_zero_deve_passar" {
  command = plan

  variables {
    default_capacity_provider_strategy = {
      FARGATE = {
        base   = 0
        weight = 1
      }
    }
  }
}

run "strategy_nulls_devem_passar" {
  command = plan

  variables {
    default_capacity_provider_strategy = {
      FARGATE = {}
    }
  }
}

# ==============================================================================
# Happy path: configuração padrão deve passar sem erros
# ==============================================================================

run "configuracao_padrao_planeia_sem_erros" {
  command = plan
}
