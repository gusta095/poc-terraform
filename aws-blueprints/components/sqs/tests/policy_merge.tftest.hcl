# ==============================================================================
# TESTES: Geração e composição de policy statements (policy-statements.tf)
#
# Regras de negócio testadas:
#   - sns_statements  → gerado apenas quando sns_access_arns é preenchido
#   - s3_statements   → gerado apenas quando s3_access_names é preenchido
#   - iam_statements  → concat(sns, s3, extra_iam_statements)
#   - queue_policy_statements → map keyed por sid
#   - Nomes de buckets S3 são convertidos para ARN (arn:aws:s3:::bucket)
#   - Filas FIFO: ARN na policy usa o nome com sufixo .fifo
#
# Como rodar:
#   cd components/application-integration/sqs
#   terraform test -filter=tests/policy_merge.tftest.hcl
# ==============================================================================

# ------------------------------------------------------------------------------
# Cenário 1: Apenas sns_access_arns → somente AllowSNSPublish é gerado
# ------------------------------------------------------------------------------
run "sns_access_arns_gera_statement_correto" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name            = "minha-fila"
    sns_access_arns = ["arn:aws:sns:us-east-1:123456789012:topico-a"]
  }

  assert {
    condition     = output.has_sns_statement == true
    error_message = "sns_access_arns preenchido deve gerar o statement AllowSNSPublish"
  }

  assert {
    condition     = output.has_s3_statement == false
    error_message = "Sem s3_access_names não deve gerar statement S3"
  }

  assert {
    condition     = output.iam_statements_count == 1
    error_message = "Apenas SNS deve resultar em 1 statement. Count: ${output.iam_statements_count}"
  }

  assert {
    condition     = contains(output.queue_policy_keys, "AllowSNSPublish")
    error_message = "O map de policy deve conter a chave 'AllowSNSPublish'"
  }
}

# ------------------------------------------------------------------------------
# Cenário 2: Apenas s3_access_names → somente AllowS3Access é gerado
# ------------------------------------------------------------------------------
run "s3_access_names_gera_statement_correto" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name            = "minha-fila"
    s3_access_names = ["meu-bucket"]
  }

  assert {
    condition     = output.has_s3_statement == true
    error_message = "s3_access_names preenchido deve gerar o statement AllowS3Access"
  }

  assert {
    condition     = output.has_sns_statement == false
    error_message = "Sem sns_access_arns não deve gerar statement SNS"
  }

  assert {
    condition     = output.iam_statements_count == 1
    error_message = "Apenas S3 deve resultar em 1 statement. Count: ${output.iam_statements_count}"
  }

  assert {
    condition     = contains(output.queue_policy_keys, "AllowS3Access")
    error_message = "O map de policy deve conter a chave 'AllowS3Access'"
  }
}

# ------------------------------------------------------------------------------
# Cenário 3: SNS + S3 → dois statements independentes são gerados
# ------------------------------------------------------------------------------
run "sns_e_s3_geram_dois_statements" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name            = "minha-fila"
    sns_access_arns = ["arn:aws:sns:us-east-1:123456789012:topico-a"]
    s3_access_names = ["meu-bucket"]
  }

  assert {
    condition     = output.iam_statements_count == 2
    error_message = "SNS + S3 devem gerar 2 statements. Count: ${output.iam_statements_count}"
  }

  assert {
    condition     = contains(output.queue_policy_keys, "AllowSNSPublish") && contains(output.queue_policy_keys, "AllowS3Access")
    error_message = "Ambas as chaves 'AllowSNSPublish' e 'AllowS3Access' devem estar presentes"
  }
}

# ------------------------------------------------------------------------------
# Cenário 4: Apenas extra_iam_statements → statement customizado adicionado
# ------------------------------------------------------------------------------
run "extra_iam_statements_adicionado_ao_concat" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name = "minha-fila"
    extra_iam_statements = [
      {
        sid       = "AllowLambdaConsume"
        effect    = "Allow"
        actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage"]
        resources = ["arn:aws:sqs:us-east-1:123456789012:minha-fila"]
      }
    ]
  }

  assert {
    condition     = output.iam_statements_count == 1
    error_message = "1 extra_iam_statement deve resultar em 1 statement. Count: ${output.iam_statements_count}"
  }

  assert {
    condition     = contains(output.queue_policy_keys, "AllowLambdaConsume")
    error_message = "A chave 'AllowLambdaConsume' deve estar presente no map de policy"
  }
}

# ------------------------------------------------------------------------------
# Cenário 5: SNS + extra → dois statements no total
# ------------------------------------------------------------------------------
run "sns_mais_extra_resulta_em_dois_statements" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name            = "minha-fila"
    sns_access_arns = ["arn:aws:sns:us-east-1:123456789012:topico-a"]
    extra_iam_statements = [
      {
        sid       = "AllowLambdaConsume"
        effect    = "Allow"
        actions   = ["sqs:ReceiveMessage"]
        resources = ["arn:aws:sqs:us-east-1:123456789012:minha-fila"]
      }
    ]
  }

  assert {
    condition     = output.iam_statements_count == 2
    error_message = "SNS + extra deve resultar em 2 statements. Count: ${output.iam_statements_count}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 6: Sem nenhum acesso configurado → lista de statements vazia
# ------------------------------------------------------------------------------
run "sem_acessos_lista_de_statements_vazia" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name = "minha-fila"
  }

  assert {
    condition     = output.iam_statements_count == 0
    error_message = "Sem sns, s3 ou extra, não deve haver statements. Count: ${output.iam_statements_count}"
  }

  assert {
    condition     = length(output.queue_policy_keys) == 0
    error_message = "O map de policy deve estar vazio quando não há acessos configurados"
  }
}

# ------------------------------------------------------------------------------
# Cenário 7: Nomes de buckets S3 são convertidos para ARN completo
#
# Por que isso importa? A AWS exige ARNs na condição ArnLike, não nomes de
# buckets. A conversão "arn:aws:s3:::bucket" deve ocorrer automaticamente.
# ------------------------------------------------------------------------------
run "s3_bucket_names_convertidos_para_arn" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name            = "minha-fila"
    s3_access_names = ["bucket-producao", "bucket-backup"]
  }

  assert {
    condition     = contains(output.s3_statement_condition_arns, "arn:aws:s3:::bucket-producao")
    error_message = "O bucket 'bucket-producao' deve ser convertido para 'arn:aws:s3:::bucket-producao'"
  }

  assert {
    condition     = contains(output.s3_statement_condition_arns, "arn:aws:s3:::bucket-backup")
    error_message = "O bucket 'bucket-backup' deve ser convertido para 'arn:aws:s3:::bucket-backup'"
  }

  assert {
    condition     = length(output.s3_statement_condition_arns) == 2
    error_message = "Devem existir exatamente 2 ARNs na condição S3. Count: ${length(output.s3_statement_condition_arns)}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 8: ARN na policy SNS aponta para a fila correta
# ------------------------------------------------------------------------------
run "sns_statement_resource_aponta_para_a_fila_correta" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name            = "pedidos"
    aws_region      = "sa-east-1"
    account_id      = "111122223333"
    sns_access_arns = ["arn:aws:sns:sa-east-1:111122223333:topico-pedidos"]
  }

  assert {
    condition     = output.sns_statement_resource_arn == "arn:aws:sqs:sa-east-1:111122223333:pedidos"
    error_message = "O resource ARN no statement SNS deve apontar para a fila correta. Obtido: '${output.sns_statement_resource_arn}'"
  }
}

# ------------------------------------------------------------------------------
# Cenário 9: Fila FIFO → ARN na policy usa nome com sufixo .fifo
#
# Por que isso importa? Uma fila FIFO com ARN sem sufixo na policy é inválida
# na AWS — a policy não seria aplicada ao recurso correto.
# ------------------------------------------------------------------------------
run "fila_fifo_arn_na_policy_usa_sufixo_fifo" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name            = "pedidos"
    aws_region      = "us-east-1"
    account_id      = "111122223333"
    fifo_queue      = true
    sns_access_arns = ["arn:aws:sns:us-east-1:111122223333:topico-pedidos.fifo"]
  }

  assert {
    condition     = output.sns_statement_resource_arn == "arn:aws:sqs:us-east-1:111122223333:pedidos.fifo"
    error_message = "ARN na policy de fila FIFO deve usar sufixo '.fifo'. Obtido: '${output.sns_statement_resource_arn}'"
  }
}

# ------------------------------------------------------------------------------
# Cenário 10: S3 + extra → dois statements independentes
# ------------------------------------------------------------------------------
run "s3_mais_extra_resulta_em_dois_statements" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name            = "minha-fila"
    s3_access_names = ["meu-bucket"]
    extra_iam_statements = [
      {
        sid       = "AllowLambdaConsume"
        effect    = "Allow"
        actions   = ["sqs:ReceiveMessage"]
        resources = ["arn:aws:sqs:us-east-1:123456789012:minha-fila"]
      }
    ]
  }

  assert {
    condition     = output.iam_statements_count == 2
    error_message = "S3 + extra deve resultar em 2 statements. Count: ${output.iam_statements_count}"
  }

  assert {
    condition     = contains(output.queue_policy_keys, "AllowS3Access") && contains(output.queue_policy_keys, "AllowLambdaConsume")
    error_message = "Ambas as chaves 'AllowS3Access' e 'AllowLambdaConsume' devem estar presentes"
  }
}

# ------------------------------------------------------------------------------
# Cenário 11: SNS + S3 + extra → três statements, todas as origens cobertas
# ------------------------------------------------------------------------------
run "sns_s3_e_extra_geram_tres_statements" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name            = "minha-fila"
    sns_access_arns = ["arn:aws:sns:us-east-1:123456789012:topico-a"]
    s3_access_names = ["meu-bucket"]
    extra_iam_statements = [
      {
        sid       = "AllowLambdaConsume"
        effect    = "Allow"
        actions   = ["sqs:ReceiveMessage"]
        resources = ["arn:aws:sqs:us-east-1:123456789012:minha-fila"]
      }
    ]
  }

  assert {
    condition     = output.iam_statements_count == 3
    error_message = "SNS + S3 + extra deve resultar em 3 statements. Count: ${output.iam_statements_count}"
  }

  assert {
    condition = (
      contains(output.queue_policy_keys, "AllowSNSPublish") &&
      contains(output.queue_policy_keys, "AllowS3Access") &&
      contains(output.queue_policy_keys, "AllowLambdaConsume")
    )
    error_message = "As três chaves devem estar presentes no map de policy"
  }
}

# ------------------------------------------------------------------------------
# Cenário 13: Múltiplos SNS topics → todos listados na condição ArnLike
# ------------------------------------------------------------------------------
run "multiplos_sns_topics_listados_na_condicao" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name = "minha-fila"
    sns_access_arns = [
      "arn:aws:sns:us-east-1:123456789012:topico-a",
      "arn:aws:sns:us-east-1:123456789012:topico-b",
      "arn:aws:sns:us-east-1:123456789012:topico-c"
    ]
  }

  assert {
    condition     = output.iam_statements_count == 1
    error_message = "Múltiplos SNS topics devem resultar em 1 statement (não um por tópico). Count: ${output.iam_statements_count}"
  }
}
