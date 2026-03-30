# ==============================================================================
# TESTES: Regras de validação das variáveis do componente SQS
#
# Estes testes verificam que o Terraform rejeita valores fora dos limites
# definidos nos blocos `validation` de variables.tf.
#
# Como funciona:
#   expect_failures = [var.nome_da_variavel]
#   → diz ao terraform test que o plan DEVE falhar nessa variável.
#   Se o plan não falhar, o teste falha.
#
# Pré-requisito: o módulo precisa ser inicializado antes (terraform init baixa
# o módulo de tags do GitLab via SSH).
#
# Como rodar:
#   cd components/application-integration/sqs
#   terraform init
#   terraform test -filter=tests/variable_validations.tftest.hcl
# ==============================================================================

# mock_provider substitui todas as chamadas à AWS por valores fictícios.
# Sem isso, o terraform precisaria de credenciais reais para fazer o plan.
mock_provider "aws" {}

# Variáveis base válidas usadas em todos os runs.
# Cada run sobrescreve apenas a variável que está sendo testada.
# sns_access_arns é necessário para satisfazer a precondition de policy obrigatória.
variables {
  name            = "test-queue"
  environment     = "sandbox"
  aws_region      = "us-east-1"
  account_id      = "123456789012"
  sns_access_arns = ["arn:aws:sns:us-east-1:123456789012:topico-teste"]
}

# ==============================================================================
# visibility_timeout_seconds — intervalo válido: 0 a 43200
# ==============================================================================

run "visibility_timeout_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    visibility_timeout_seconds = 43201
  }

  expect_failures = [var.visibility_timeout_seconds]
}

run "visibility_timeout_negativo_deve_falhar" {
  command = plan

  variables {
    visibility_timeout_seconds = -1
  }

  expect_failures = [var.visibility_timeout_seconds]
}

# ==============================================================================
# message_retention_seconds — intervalo válido: 60 a 1209600
# ==============================================================================

run "message_retention_abaixo_do_minimo_deve_falhar" {
  command = plan

  variables {
    message_retention_seconds = 59
  }

  expect_failures = [var.message_retention_seconds]
}

run "message_retention_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    message_retention_seconds = 1209601
  }

  expect_failures = [var.message_retention_seconds]
}

# ==============================================================================
# max_message_size — intervalo válido: 1024 a 262144 bytes
# ==============================================================================

run "max_message_size_abaixo_do_minimo_deve_falhar" {
  command = plan

  variables {
    max_message_size = 1023
  }

  expect_failures = [var.max_message_size]
}

run "max_message_size_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    max_message_size = 262145
  }

  expect_failures = [var.max_message_size]
}

# ==============================================================================
# delay_seconds — intervalo válido: 0 a 900
# ==============================================================================

run "delay_seconds_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    delay_seconds = 901
  }

  expect_failures = [var.delay_seconds]
}

# ==============================================================================
# receive_wait_time_seconds — intervalo válido: 0 a 20
# ==============================================================================

run "receive_wait_time_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    receive_wait_time_seconds = 21
  }

  expect_failures = [var.receive_wait_time_seconds]
}

# ==============================================================================
# DLQ: dlq_visibility_timeout_seconds — intervalo válido: 0 a 43200
# ==============================================================================

run "dlq_visibility_timeout_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    create_dlq                     = true
    dlq_visibility_timeout_seconds = 43201
  }

  expect_failures = [var.dlq_visibility_timeout_seconds]
}

# ==============================================================================
# DLQ: dlq_message_retention_seconds — intervalo válido: 60 a 1209600
# ==============================================================================

run "dlq_message_retention_abaixo_do_minimo_deve_falhar" {
  command = plan

  variables {
    create_dlq                    = true
    dlq_message_retention_seconds = 59
  }

  expect_failures = [var.dlq_message_retention_seconds]
}

# ==============================================================================
# DLQ: dlq_delay_seconds — intervalo válido: 0 a 900
# ==============================================================================

run "dlq_delay_seconds_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    create_dlq        = true
    dlq_delay_seconds = 901
  }

  expect_failures = [var.dlq_delay_seconds]
}

# ==============================================================================
# DLQ: dlq_receive_wait_time_seconds — intervalo válido: 0 a 20
# ==============================================================================

run "dlq_receive_wait_time_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    create_dlq                    = true
    dlq_receive_wait_time_seconds = 21
  }

  expect_failures = [var.dlq_receive_wait_time_seconds]
}

# ==============================================================================
# Happy path: configuração padrão deve passar sem erros
#
# Verifica que o componente planeja com sucesso quando todas as variáveis
# estão dentro dos limites válidos (usando os defaults).
# ==============================================================================

run "configuracao_padrao_planeia_sem_erros" {
  command = plan
}

# ==============================================================================
# Precondition: ao menos uma policy statement é obrigatória
#
# O componente possui um terraform_data com precondition que impede o apply
# quando nenhum acesso é configurado. Testa que a condição é corretamente
# disparada quando sns_access_arns, s3_access_names e extra_iam_statements
# estão todos vazios.
# ==============================================================================

run "sem_nenhuma_policy_a_precondition_deve_falhar" {
  command = plan

  variables {
    sns_access_arns      = []
    s3_access_names      = []
    extra_iam_statements = []
  }

  expect_failures = [resource.terraform_data.validate_iam_statements]
}

run "create_queue_policy_false_sem_statements_nao_deve_falhar" {
  command = plan

  variables {
    create_queue_policy  = false
    sns_access_arns      = []
    s3_access_names      = []
    extra_iam_statements = []
  }
}

# ==============================================================================
# max_receive_count — intervalo válido: 1 a 1000
# ==============================================================================

run "max_receive_count_zero_deve_falhar" {
  command = plan

  variables {
    create_dlq        = true
    max_receive_count = 0
  }

  expect_failures = [var.max_receive_count]
}

run "max_receive_count_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    create_dlq        = true
    max_receive_count = 1001
  }

  expect_failures = [var.max_receive_count]
}

run "max_receive_count_no_limite_minimo_deve_passar" {
  command = plan

  variables {
    create_dlq        = true
    max_receive_count = 1
  }
}

run "max_receive_count_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    create_dlq        = true
    max_receive_count = 1000
  }
}

# ==============================================================================
# Limites inferiores das variáveis DLQ que não foram testados
# ==============================================================================

run "dlq_visibility_timeout_negativo_deve_falhar" {
  command = plan

  variables {
    create_dlq                     = true
    dlq_visibility_timeout_seconds = -1
  }

  expect_failures = [var.dlq_visibility_timeout_seconds]
}

run "dlq_message_retention_acima_do_limite_deve_falhar" {
  command = plan

  variables {
    create_dlq                    = true
    dlq_message_retention_seconds = 1209601
  }

  expect_failures = [var.dlq_message_retention_seconds]
}

run "dlq_receive_wait_time_negativo_deve_falhar" {
  command = plan

  variables {
    create_dlq                    = true
    dlq_receive_wait_time_seconds = -1
  }

  expect_failures = [var.dlq_receive_wait_time_seconds]
}

run "delay_seconds_negativo_deve_falhar" {
  command = plan

  variables {
    delay_seconds = -1
  }

  expect_failures = [var.delay_seconds]
}

run "receive_wait_time_negativo_deve_falhar" {
  command = plan

  variables {
    receive_wait_time_seconds = -1
  }

  expect_failures = [var.receive_wait_time_seconds]
}

run "dlq_delay_seconds_negativo_deve_falhar" {
  command = plan

  variables {
    create_dlq        = true
    dlq_delay_seconds = -1
  }

  expect_failures = [var.dlq_delay_seconds]
}

# ==============================================================================
# Limites exatos válidos (fronteiras que devem ser aceitas)
#
# Previnem off-by-one nos blocos `validation`: se a condição fosse `> 0`
# em vez de `>= 0`, o valor 0 seria rejeitado indevidamente.
# ==============================================================================

run "visibility_timeout_no_limite_minimo_deve_passar" {
  command = plan

  variables {
    visibility_timeout_seconds = 0
  }
}

run "visibility_timeout_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    visibility_timeout_seconds = 43200
  }
}

run "message_retention_no_limite_minimo_deve_passar" {
  command = plan

  variables {
    message_retention_seconds = 60
  }
}

run "message_retention_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    message_retention_seconds = 1209600
  }
}

run "max_message_size_no_limite_minimo_deve_passar" {
  command = plan

  variables {
    max_message_size = 1024
  }
}

run "max_message_size_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    max_message_size = 262144
  }
}

run "delay_seconds_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    delay_seconds = 900
  }
}

run "receive_wait_time_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    receive_wait_time_seconds = 20
  }
}

run "dlq_visibility_timeout_no_limite_minimo_deve_passar" {
  command = plan

  variables {
    create_dlq                     = true
    dlq_visibility_timeout_seconds = 0
  }
}

run "dlq_visibility_timeout_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    create_dlq                     = true
    dlq_visibility_timeout_seconds = 43200
  }
}

run "dlq_message_retention_no_limite_minimo_deve_passar" {
  command = plan

  variables {
    create_dlq                    = true
    dlq_message_retention_seconds = 60
  }
}

run "dlq_message_retention_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    create_dlq                    = true
    dlq_message_retention_seconds = 1209600
  }
}

run "dlq_delay_seconds_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    create_dlq        = true
    dlq_delay_seconds = 900
  }
}

run "dlq_receive_wait_time_no_limite_maximo_deve_passar" {
  command = plan

  variables {
    create_dlq                    = true
    dlq_receive_wait_time_seconds = 20
  }
}

# ==============================================================================
# fifo_throughput_limit — valores válidos: perQueue, perMessageGroupId
# ==============================================================================

run "fifo_throughput_limit_valor_invalido_deve_falhar" {
  command = plan

  variables {
    fifo_throughput_limit = "invalido"
  }

  expect_failures = [var.fifo_throughput_limit]
}

run "fifo_throughput_limit_per_queue_deve_passar" {
  command = plan

  variables {
    fifo_queue            = true
    fifo_throughput_limit = "perQueue"
  }
}

run "fifo_throughput_limit_per_message_group_deve_passar" {
  command = plan

  variables {
    fifo_queue            = true
    fifo_throughput_limit = "perMessageGroupId"
  }
}

# ==============================================================================
# Preconditions: opções FIFO em filas não-FIFO devem falhar
# ==============================================================================

run "content_based_deduplication_em_fila_nao_fifo_deve_falhar" {
  command = plan

  variables {
    fifo_queue                  = false
    content_based_deduplication = true
  }

  expect_failures = [resource.terraform_data.validate_fifo_options]
}

run "fifo_throughput_limit_em_fila_nao_fifo_deve_falhar" {
  command = plan

  variables {
    fifo_queue            = false
    fifo_throughput_limit = "perQueue"
  }

  expect_failures = [resource.terraform_data.validate_fifo_options]
}
