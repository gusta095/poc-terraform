# ==============================================================================
# TESTES: Geração e composição de IAM policy statements (policy_statements.tf)
#
# Regras de negócio testadas:
#   - Cada serviço gera exatamente 1 statement quando configurado
#   - Statements são concatenados corretamente via iam_statements
#   - Nomes de buckets S3 são convertidos para ARN (arn:aws:s3:::bucket e bucket/*)
#   - ARNs SSM e Secrets Manager são segregados corretamente para a execution role
#   - extra_iam_statements é appendado ao final da lista
#
# Como rodar:
#   cd components/containers/ecs/service-worker
#   terraform test -filter=tests/iam_policy_merge.tftest.hcl
# ==============================================================================

# ------------------------------------------------------------------------------
# Cenário 1: Apenas SQS → 1 statement AllowSQSAccess
# ------------------------------------------------------------------------------
run "sqs_access_gera_statement_correto" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    sqs_access_arns = ["arn:aws:sqs:us-east-1:123456789012:fila-entrada"]
  }

  assert {
    condition     = output.sqs_statements_count == 1
    error_message = "sqs_access_arns preenchido deve gerar 1 statement. Count: ${output.sqs_statements_count}"
  }

  assert {
    condition     = contains(output.iam_statement_sids, "AllowSQSAccess")
    error_message = "Statement 'AllowSQSAccess' deve estar presente"
  }

  assert {
    condition     = output.iam_statements_count == 1
    error_message = "Apenas SQS deve resultar em 1 statement total. Count: ${output.iam_statements_count}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 2: Apenas SNS → 1 statement AllowSNSPublish
# ------------------------------------------------------------------------------
run "sns_access_gera_statement_correto" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    sns_access = ["arn:aws:sns:us-east-1:123456789012:topico-eventos"]
  }

  assert {
    condition     = output.sns_statements_count == 1
    error_message = "sns_access preenchido deve gerar 1 statement. Count: ${output.sns_statements_count}"
  }

  assert {
    condition     = contains(output.iam_statement_sids, "AllowSNSPublish")
    error_message = "Statement 'AllowSNSPublish' deve estar presente"
  }

  assert {
    condition     = output.iam_statements_count == 1
    error_message = "Apenas SNS deve resultar em 1 statement total. Count: ${output.iam_statements_count}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 3: Apenas DynamoDB → 1 statement AllowDynamoDBReadWrite
# ------------------------------------------------------------------------------
run "dynamodb_access_gera_statement_correto" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    dynamodb_access = ["arn:aws:dynamodb:us-east-1:123456789012:table/pedidos"]
  }

  assert {
    condition     = output.dynamodb_statements_count == 1
    error_message = "dynamodb_access preenchido deve gerar 1 statement. Count: ${output.dynamodb_statements_count}"
  }

  assert {
    condition     = contains(output.iam_statement_sids, "AllowDynamoDBReadWrite")
    error_message = "Statement 'AllowDynamoDBReadWrite' deve estar presente"
  }

  assert {
    condition     = output.iam_statements_count == 1
    error_message = "Apenas DynamoDB deve resultar em 1 statement total. Count: ${output.iam_statements_count}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 4: Apenas Lambda → 1 statement AllowLambdaInvoke
# ------------------------------------------------------------------------------
run "lambda_access_gera_statement_correto" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    lambda_access = ["arn:aws:lambda:us-east-1:123456789012:function:minha-funcao"]
  }

  assert {
    condition     = output.lambda_statements_count == 1
    error_message = "lambda_access preenchido deve gerar 1 statement. Count: ${output.lambda_statements_count}"
  }

  assert {
    condition     = contains(output.iam_statement_sids, "AllowLambdaInvoke")
    error_message = "Statement 'AllowLambdaInvoke' deve estar presente"
  }

  assert {
    condition     = output.iam_statements_count == 1
    error_message = "Apenas Lambda deve resultar em 1 statement total. Count: ${output.iam_statements_count}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 5: Apenas S3 → 1 statement AllowS3Access
# ------------------------------------------------------------------------------
run "s3_access_gera_statement_correto" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    s3_access_names = ["meu-bucket"]
  }

  assert {
    condition     = output.s3_statements_count == 1
    error_message = "s3_access_names preenchido deve gerar 1 statement. Count: ${output.s3_statements_count}"
  }

  assert {
    condition     = contains(output.iam_statement_sids, "AllowS3Access")
    error_message = "Statement 'AllowS3Access' deve estar presente"
  }

  assert {
    condition     = output.iam_statements_count == 1
    error_message = "Apenas S3 deve resultar em 1 statement total. Count: ${output.iam_statements_count}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 6: Nomes de buckets S3 são convertidos para ARN
#
# A AWS exige ARNs nas policies IAM. O componente deve converter
# "meu-bucket" em "arn:aws:s3:::meu-bucket" e "arn:aws:s3:::meu-bucket/*"
# ------------------------------------------------------------------------------
run "s3_bucket_names_convertidos_para_arn" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    s3_access_names = ["bucket-producao", "bucket-backup"]
  }

  assert {
    condition     = contains(output.s3_resources, "arn:aws:s3:::bucket-producao")
    error_message = "ARN raiz do bucket 'bucket-producao' deve estar presente"
  }

  assert {
    condition     = contains(output.s3_resources, "arn:aws:s3:::bucket-producao/*")
    error_message = "ARN com wildcard do bucket 'bucket-producao' deve estar presente"
  }

  assert {
    condition     = contains(output.s3_resources, "arn:aws:s3:::bucket-backup")
    error_message = "ARN raiz do bucket 'bucket-backup' deve estar presente"
  }

  assert {
    condition     = length(output.s3_resources) == 4
    error_message = "2 buckets devem gerar 4 resources (raiz + wildcard cada). Count: ${length(output.s3_resources)}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 7: Todos os serviços juntos → 5 statements independentes
# ------------------------------------------------------------------------------
run "todos_servicos_geram_cinco_statements" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    sqs_access_arns = ["arn:aws:sqs:us-east-1:123456789012:fila"]
    sns_access      = ["arn:aws:sns:us-east-1:123456789012:topico"]
    dynamodb_access = ["arn:aws:dynamodb:us-east-1:123456789012:table/tabela"]
    lambda_access   = ["arn:aws:lambda:us-east-1:123456789012:function:funcao"]
    s3_access_names = ["bucket"]
  }

  assert {
    condition     = output.iam_statements_count == 5
    error_message = "Todos os serviços devem gerar 5 statements. Count: ${output.iam_statements_count}"
  }

  assert {
    condition = (
      contains(output.iam_statement_sids, "AllowSQSAccess") &&
      contains(output.iam_statement_sids, "AllowSNSPublish") &&
      contains(output.iam_statement_sids, "AllowDynamoDBReadWrite") &&
      contains(output.iam_statement_sids, "AllowLambdaInvoke") &&
      contains(output.iam_statement_sids, "AllowS3Access")
    )
    error_message = "Todos os 5 SIDs devem estar presentes"
  }
}

# ------------------------------------------------------------------------------
# Cenário 8: extra_iam_statements é appendado ao final
# ------------------------------------------------------------------------------
run "extra_iam_statements_adicionado_ao_concat" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    sqs_access_arns = ["arn:aws:sqs:us-east-1:123456789012:fila"]
    extra_iam_statements = [
      {
        sid       = "AllowCustomAccess"
        effect    = "Allow"
        actions   = ["s3:ListAllMyBuckets"]
        resources = ["*"]
      }
    ]
  }

  assert {
    condition     = output.iam_statements_count == 2
    error_message = "SQS + extra deve resultar em 2 statements. Count: ${output.iam_statements_count}"
  }

  assert {
    condition     = contains(output.iam_statement_sids, "AllowCustomAccess")
    error_message = "Statement customizado 'AllowCustomAccess' deve estar presente"
  }
}

# ------------------------------------------------------------------------------
# Cenário 9: Sem nenhum serviço configurado → lista vazia
# ------------------------------------------------------------------------------
run "sem_servicos_lista_de_statements_vazia" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  assert {
    condition     = output.iam_statements_count == 0
    error_message = "Sem serviços configurados, não deve haver statements. Count: ${output.iam_statements_count}"
  }
}

# ------------------------------------------------------------------------------
# Cenário 10: ARN SSM vai para ssm_secret_arns (execution role — SSM)
# ------------------------------------------------------------------------------
run "arn_ssm_vai_para_ssm_secret_arns" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    secrets = {
      DB_PASS = "arn:aws:ssm:us-east-1:123456789012:parameter/prod/db"
    }
  }

  assert {
    condition     = length(output.ssm_secret_arns) == 1
    error_message = "ARN SSM deve ir para ssm_secret_arns. Count: ${length(output.ssm_secret_arns)}"
  }

  assert {
    condition     = length(output.secretsmanager_secret_arns) == 0
    error_message = "ARN SSM não deve ir para secretsmanager_secret_arns"
  }

  assert {
    condition     = contains(output.ssm_secret_arns, "arn:aws:ssm:us-east-1:123456789012:parameter/prod/db")
    error_message = "O ARN SSM correto deve estar em ssm_secret_arns"
  }
}

# ------------------------------------------------------------------------------
# Cenário 11: ARN Secrets Manager vai para secretsmanager_secret_arns
# ------------------------------------------------------------------------------
run "arn_secrets_manager_vai_para_lista_correta" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    secrets = {
      API_KEY = "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/api-key"
    }
  }

  assert {
    condition     = length(output.secretsmanager_secret_arns) == 1
    error_message = "ARN Secrets Manager deve ir para secretsmanager_secret_arns. Count: ${length(output.secretsmanager_secret_arns)}"
  }

  assert {
    condition     = length(output.ssm_secret_arns) == 0
    error_message = "ARN Secrets Manager não deve ir para ssm_secret_arns"
  }
}

# ------------------------------------------------------------------------------
# Cenário 12: Secrets mistos → cada ARN vai para a lista correta
# ------------------------------------------------------------------------------
run "secrets_mistos_segregados_corretamente" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    secrets = {
      DB_PASS = "arn:aws:ssm:us-east-1:123456789012:parameter/prod/db"
      API_KEY = "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/api-key"
    }
  }

  assert {
    condition     = length(output.ssm_secret_arns) == 1
    error_message = "Deve haver exatamente 1 ARN SSM. Count: ${length(output.ssm_secret_arns)}"
  }

  assert {
    condition     = length(output.secretsmanager_secret_arns) == 1
    error_message = "Deve haver exatamente 1 ARN Secrets Manager. Count: ${length(output.secretsmanager_secret_arns)}"
  }
}
