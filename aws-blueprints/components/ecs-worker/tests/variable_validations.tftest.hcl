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
#   cd components/containers/ecs/service-worker
#   terraform init
#   terraform test -filter=tests/variable_validations.tftest.hcl
# ==============================================================================

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

# Variáveis base válidas. Cada run sobrescreve apenas a variável em teste.
variables {
  environment      = "sandbox"
  vpc_primary_name = "vpc-sandbox"
  cluster_name     = "cluster-sandbox"
  worker_name      = "worker-test"
  image            = "nginx:latest"
}

# ==============================================================================
# cpu — valores válidos: 256, 512, 1024, 2048, 4096
# ==============================================================================

run "cpu_valor_invalido_deve_falhar" {
  command = plan

  variables {
    cpu = 128
  }

  expect_failures = [var.cpu]
}

run "cpu_valor_invalido_alto_deve_falhar" {
  command = plan

  variables {
    cpu = 8192
  }

  expect_failures = [var.cpu]
}

run "cpu_256_deve_passar" {
  command = plan

  variables {
    cpu    = 256
    memory = 512
  }
}

run "cpu_4096_deve_passar" {
  command = plan

  variables {
    cpu    = 4096
    memory = 8192
  }
}

# ==============================================================================
# memory — combinação inválida com cpu
# ==============================================================================

run "memory_incompativel_com_cpu_deve_falhar" {
  command = plan

  variables {
    cpu    = 256
    memory = 4096
  }

  expect_failures = [var.memory]
}

run "memory_abaixo_do_minimo_para_cpu_deve_falhar" {
  command = plan

  variables {
    cpu    = 512
    memory = 512
  }

  expect_failures = [var.memory]
}

# ==============================================================================
# propagate_tags — valores válidos: SERVICE, TASK_DEFINITION
# ==============================================================================

run "propagate_tags_invalido_deve_falhar" {
  command = plan

  variables {
    propagate_tags = "INVALID"
  }

  expect_failures = [var.propagate_tags]
}

run "propagate_tags_service_deve_passar" {
  command = plan

  variables {
    propagate_tags = "SERVICE"
  }
}

run "propagate_tags_task_definition_deve_passar" {
  command = plan

  variables {
    propagate_tags = "TASK_DEFINITION"
  }
}

# ==============================================================================
# autoscale_strategy — valores válidos: cpu, memory, sqs_messages_scaling
# ==============================================================================

run "autoscale_strategy_invalida_deve_falhar" {
  command = plan

  variables {
    autoscale_strategy = ["cpu", "invalid_strategy"]
  }

  expect_failures = [var.autoscale_strategy]
}

run "autoscale_strategy_vazia_deve_passar" {
  command = plan

  variables {
    autoscale_strategy = []
  }
}

# ==============================================================================
# log_retention_days — valores válidos: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365
# ==============================================================================

run "log_retention_valor_invalido_deve_falhar" {
  command = plan

  variables {
    log_retention_days = 10
  }

  expect_failures = [var.log_retention_days]
}

run "log_retention_zero_deve_falhar" {
  command = plan

  variables {
    log_retention_days = 0
  }

  expect_failures = [var.log_retention_days]
}

run "log_retention_1_dia_deve_passar" {
  command = plan

  variables {
    log_retention_days = 1
  }
}

run "log_retention_365_dias_deve_passar" {
  command = plan

  variables {
    log_retention_days = 365
  }
}

# ==============================================================================
# worker_name — formato ECS
# ==============================================================================

run "worker_name_com_caractere_invalido_deve_falhar" {
  command = plan

  variables {
    worker_name = "worker name!"
  }

  expect_failures = [var.worker_name]
}

run "worker_name_valido_deve_passar" {
  command = plan

  variables {
    worker_name = "my-worker_01"
  }
}

# ==============================================================================
# autoscaling_min — não pode ser negativo
# ==============================================================================

run "autoscaling_min_negativo_deve_falhar" {
  command = plan

  variables {
    autoscaling_min = -1
  }

  expect_failures = [var.autoscaling_min]
}

# ==============================================================================
# autoscaling_max — deve ser pelo menos 1
# ==============================================================================

run "autoscaling_max_zero_deve_falhar" {
  command = plan

  variables {
    autoscaling_max = 0
  }

  expect_failures = [var.autoscaling_max]
}

# ==============================================================================
# autoscaling_min > autoscaling_max — precondition
# ==============================================================================

run "autoscaling_min_maior_que_max_deve_falhar" {
  command = plan

  variables {
    autoscaling_min = 5
    autoscaling_max = 2
  }

  expect_failures = [resource.terraform_data.validate_autoscaling_range]
}

run "autoscaling_min_igual_ao_max_deve_passar" {
  command = plan

  variables {
    autoscaling_min = 3
    autoscaling_max = 3
  }
}

run "autoscaling_min_menor_que_max_deve_passar" {
  command = plan

  variables {
    autoscaling_min = 1
    autoscaling_max = 10
  }
}

# ==============================================================================
# sqs_messages_scaling sem fila configurada — precondition
# ==============================================================================

run "sqs_messages_scaling_sem_fila_deve_falhar" {
  command = plan

  variables {
    autoscale_strategy = ["cpu", "sqs_messages_scaling"]
    sqs_access_arns    = []
    sqs_specific_name  = ""
  }

  expect_failures = [resource.terraform_data.validate_sqs_scaling]
}

run "sqs_messages_scaling_com_sqs_access_arns_deve_passar" {
  command = plan

  variables {
    autoscale_strategy = ["sqs_messages_scaling"]
    sqs_access_arns    = ["arn:aws:sqs:us-east-1:123456789012:minha-fila"]
  }
}

run "sqs_messages_scaling_com_sqs_specific_name_deve_passar" {
  command = plan

  variables {
    autoscale_strategy = ["sqs_messages_scaling"]
    sqs_specific_name  = "minha-fila-legada"
  }
}

# ==============================================================================
# cluster_arn e cluster_name — mutuamente exclusivos
# ==============================================================================

run "cluster_arn_e_cluster_name_juntos_deve_falhar" {
  command = plan

  variables {
    cluster_arn  = "arn:aws:ecs:us-east-1:123456789012:cluster/my-cluster"
    cluster_name = "my-cluster"
  }

  expect_failures = [var.cluster_arn]
}

run "apenas_cluster_arn_deve_passar" {
  command = plan

  variables {
    cluster_arn  = "arn:aws:ecs:us-east-1:123456789012:cluster/my-cluster"
    cluster_name = ""
  }
}

run "cluster_arn_e_cluster_name_vazios_deve_falhar" {
  command = plan

  variables {
    cluster_arn  = ""
    cluster_name = ""
  }

  expect_failures = [var.cluster_arn]
}

# ==============================================================================
# Happy path: configuração padrão deve passar sem erros
# ==============================================================================

run "configuracao_padrao_planeia_sem_erros" {
  command = plan
}
