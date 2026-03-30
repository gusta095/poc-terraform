# ==============================================================================
# TESTES: Lógica de seleção de estratégia e nome da fila para autoscaling
#
# Regras de negócio testadas:
#   - autoscaling_policies_keys reflete as estratégias configuradas
#   - scaling_queue_name prioriza sqs_specific_name sobre ARN
#   - scaling_queue_name extrai o nome da fila do ARN SQS (índice 5 do split por ":")
#   - Quando nenhuma fonte é configurada, scaling_queue_name é "" (sem crash)
#
# Como rodar:
#   cd components/containers/ecs/service-worker
#   terraform test -filter=tests/autoscaling.tftest.hcl
# ==============================================================================

# ------------------------------------------------------------------------------
# Cenário 1: Estratégia padrão (cpu + memory)
# ------------------------------------------------------------------------------
run "estrategia_padrao_contem_cpu_e_memory" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  assert {
    condition     = contains(output.autoscaling_policies_keys, "cpu")
    error_message = "Estratégia padrão deve conter 'cpu'"
  }

  assert {
    condition     = contains(output.autoscaling_policies_keys, "memory")
    error_message = "Estratégia padrão deve conter 'memory'"
  }

  assert {
    condition     = length(output.autoscaling_policies_keys) == 2
    error_message = "Estratégia padrão deve conter exatamente 2 políticas. Count: ${length(output.autoscaling_policies_keys)}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 2: Apenas cpu
# ------------------------------------------------------------------------------
run "apenas_cpu_resulta_em_uma_politica" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    autoscale_strategy = ["cpu"]
  }

  assert {
    condition     = length(output.autoscaling_policies_keys) == 1
    error_message = "Apenas 'cpu' deve resultar em 1 política. Count: ${length(output.autoscaling_policies_keys)}"
  }

  assert {
    condition     = contains(output.autoscaling_policies_keys, "cpu")
    error_message = "A política 'cpu' deve estar presente"
  }
}

# ------------------------------------------------------------------------------
# Cenário 3: Todas as estratégias juntas
# ------------------------------------------------------------------------------
run "todas_estrategias_geram_tres_politicas" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    autoscale_strategy = ["cpu", "memory", "sqs_messages_scaling"]
    sqs_access_arns    = ["arn:aws:sqs:us-east-1:123456789012:minha-fila"]
  }

  assert {
    condition     = length(output.autoscaling_policies_keys) == 3
    error_message = "Todas as estratégias devem resultar em 3 políticas. Count: ${length(output.autoscaling_policies_keys)}"
  }

  assert {
    condition = (
      contains(output.autoscaling_policies_keys, "cpu") &&
      contains(output.autoscaling_policies_keys, "memory") &&
      contains(output.autoscaling_policies_keys, "sqs_messages_scaling")
    )
    error_message = "As 3 estratégias devem estar presentes nas políticas"
  }
}

# ------------------------------------------------------------------------------
# Cenário 4: scaling_queue_name via sqs_specific_name (prioridade)
#
# Quando sqs_specific_name é fornecido, deve ser usado mesmo que
# sqs_access_arns também esteja preenchido.
# ------------------------------------------------------------------------------
run "sqs_specific_name_tem_prioridade_sobre_arn" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    sqs_specific_name = "fila-especifica"
    sqs_access_arns   = ["arn:aws:sqs:us-east-1:123456789012:outra-fila"]
  }

  assert {
    condition     = output.scaling_queue_name == "fila-especifica"
    error_message = "sqs_specific_name deve ter prioridade. Obtido: '${output.scaling_queue_name}'"
  }
}

# ------------------------------------------------------------------------------
# Cenário 5: scaling_queue_name extraído do ARN SQS
#
# ARN formato: arn:aws:sqs:us-east-1:123456789012:nome-da-fila
# Índice 5 do split(":") = "nome-da-fila"
# ------------------------------------------------------------------------------
run "scaling_queue_name_extraido_do_arn" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    sqs_access_arns = ["arn:aws:sqs:us-east-1:123456789012:fila-de-processamento"]
  }

  assert {
    condition     = output.scaling_queue_name == "fila-de-processamento"
    error_message = "Nome da fila deve ser extraído do ARN. Obtido: '${output.scaling_queue_name}'"
  }
}

# ------------------------------------------------------------------------------
# Cenário 6: Sem sqs_specific_name e sem sqs_access_arns → "" (sem crash)
#
# Antes do fix do P0, coalesce("", "") crashava o plan.
# Agora deve retornar "" de forma segura.
# ------------------------------------------------------------------------------
run "sem_configuracao_sqs_retorna_string_vazia_sem_crash" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  assert {
    condition     = output.scaling_queue_name == ""
    error_message = "Sem configuração SQS, scaling_queue_name deve ser ''. Obtido: '${output.scaling_queue_name}'"
  }
}

# ------------------------------------------------------------------------------
# Cenário 7: Apenas sqs_specific_name → usado diretamente
# ------------------------------------------------------------------------------
run "apenas_sqs_specific_name_usado_diretamente" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    sqs_specific_name = "fila-legada"
  }

  assert {
    condition     = output.scaling_queue_name == "fila-legada"
    error_message = "sqs_specific_name deve ser usado diretamente. Obtido: '${output.scaling_queue_name}'"
  }
}
