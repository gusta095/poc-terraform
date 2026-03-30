# ==============================================================================
# TESTES: Comportamento do módulo com diferentes configurações de flags
#
# Estes testes exercitam o componente real (não a fixture) com mock_provider,
# verificando que combinações de flags planejam sem erros. Cobrem os caminhos
# que a fixture não toca: create_dlq, fifo_queue, SSE e combinações.
#
# Como rodar:
#   cd components/application-integration/sqs
#   terraform test -filter=tests/module_behavior.tftest.hcl
# ==============================================================================

mock_provider "aws" {}

# Variáveis base válidas. sns_access_arns satisfaz a precondition obrigatória.
variables {
  name            = "test-queue"
  environment     = "sandbox"
  aws_region      = "us-east-1"
  account_id      = "123456789012"
  sns_access_arns = ["arn:aws:sns:us-east-1:123456789012:topico-teste"]
}

# ==============================================================================
# DLQ
# ==============================================================================

run "create_dlq_planeia_sem_erros" {
  command = plan

  variables {
    create_dlq = true
  }
}

run "dlq_com_max_receive_count_customizado_planeia_sem_erros" {
  command = plan

  variables {
    create_dlq        = true
    max_receive_count = 3
  }
}

run "dlq_com_configuracao_customizada_planeia_sem_erros" {
  command = plan

  variables {
    create_dlq                     = true
    max_receive_count              = 10
    dlq_visibility_timeout_seconds = 60
    dlq_message_retention_seconds  = 86400
    dlq_delay_seconds              = 5
    dlq_receive_wait_time_seconds  = 10
  }
}

run "dlq_outputs_sao_null_quando_create_dlq_false" {
  command = plan

  assert {
    condition     = output.dlq_arn == null
    error_message = "dlq_arn deve ser null quando create_dlq = false"
  }

  assert {
    condition     = output.dlq_url == null
    error_message = "dlq_url deve ser null quando create_dlq = false"
  }

  assert {
    condition     = output.dlq_name == null
    error_message = "dlq_name deve ser null quando create_dlq = false"
  }
}

run "create_queue_policy_false_sem_statements_planeia_sem_erros" {
  command = plan

  variables {
    create_queue_policy  = false
    sns_access_arns      = []
    s3_access_names      = []
    extra_iam_statements = []
  }
}

# ==============================================================================
# FIFO
# ==============================================================================

run "fifo_queue_planeia_sem_erros" {
  command = plan

  variables {
    fifo_queue = true
  }
}

run "fifo_com_dlq_planeia_sem_erros" {
  command = plan

  variables {
    fifo_queue = true
    create_dlq = true
  }
}

# ==============================================================================
# SSE (Server-Side Encryption)
# ==============================================================================

run "sse_desabilitado_planeia_sem_erros" {
  command = plan

  variables {
    sqs_managed_sse_enabled = false
  }
}

run "dlq_sse_desabilitado_planeia_sem_erros" {
  command = plan

  variables {
    create_dlq                  = true
    dlq_sqs_managed_sse_enabled = false
  }
}

run "sse_desabilitado_em_fila_e_dlq_planeia_sem_erros" {
  command = plan

  variables {
    create_dlq                  = true
    sqs_managed_sse_enabled     = false
    dlq_sqs_managed_sse_enabled = false
  }
}

# ==============================================================================
# Acesso por S3
# ==============================================================================

run "s3_access_planeia_sem_erros" {
  command = plan

  variables {
    sns_access_arns = []
    s3_access_names = ["meu-bucket-eventos"]
  }
}

run "sns_e_s3_juntos_planejam_sem_erros" {
  command = plan

  variables {
    s3_access_names = ["meu-bucket-eventos"]
  }
}

# ==============================================================================
# Combinação completa
# ==============================================================================

# ==============================================================================
# KMS
# ==============================================================================

run "kms_master_key_id_planeia_sem_erros" {
  command = plan

  variables {
    kms_master_key_id = "arn:aws:kms:us-east-1:123456789012:key/mrk-abc123"
  }
}

run "dlq_kms_master_key_id_planeia_sem_erros" {
  command = plan

  variables {
    create_dlq        = true
    kms_master_key_id = "arn:aws:kms:us-east-1:123456789012:key/mrk-abc123"
  }
}

run "dlq_kms_separado_da_fila_planeia_sem_erros" {
  command = plan

  variables {
    create_dlq            = true
    kms_master_key_id     = "arn:aws:kms:us-east-1:123456789012:key/mrk-fila"
    dlq_kms_master_key_id = "arn:aws:kms:us-east-1:123456789012:key/mrk-dlq"
  }
}

# ==============================================================================
# FIFO completo
# ==============================================================================

run "fifo_com_content_based_deduplication_planeia_sem_erros" {
  command = plan

  variables {
    fifo_queue                  = true
    content_based_deduplication = true
  }
}

run "fifo_com_throughput_limit_planeia_sem_erros" {
  command = plan

  variables {
    fifo_queue            = true
    fifo_throughput_limit = "perMessageGroupId"
  }
}

run "fifo_completo_planeia_sem_erros" {
  command = plan

  variables {
    fifo_queue                  = true
    content_based_deduplication = true
    fifo_throughput_limit       = "perMessageGroupId"
    create_dlq                  = true
    kms_master_key_id           = "arn:aws:kms:us-east-1:123456789012:key/mrk-abc123"
  }
}

# ==============================================================================
# Configuração completa
# ==============================================================================

run "configuracao_completa_planeia_sem_erros" {
  command = plan

  variables {
    fifo_queue                     = true
    content_based_deduplication    = true
    fifo_throughput_limit          = "perMessageGroupId"
    create_dlq                     = true
    max_receive_count              = 3
    visibility_timeout_seconds     = 60
    message_retention_seconds      = 86400
    delay_seconds                  = 5
    receive_wait_time_seconds      = 10
    kms_master_key_id              = "arn:aws:kms:us-east-1:123456789012:key/mrk-abc123"
    dlq_visibility_timeout_seconds = 60
    dlq_message_retention_seconds  = 172800
    s3_access_names                = ["bucket-a", "bucket-b"]
  }
}
