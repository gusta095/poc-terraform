locals {
  # Cada serviço possui seu próprio statement isolado, gerado apenas quando
  # a variável correspondente é preenchida. Para adicionar um novo serviço,
  # crie um novo local seguindo o mesmo padrão e adicione no concat abaixo.
  sns_statements = length(var.sns_access_arns) > 0 ? [
    {
      sid     = "AllowSNSPublish"
      effect  = "Allow"
      actions = ["sqs:SendMessage"]
      principals = [
        {
          type        = "Service"
          identifiers = ["sns.amazonaws.com"]
        }
      ]
      resources = [
        "arn:aws:sqs:${var.aws_region}:${var.account_id}:${local.queue_name}"
      ]
      condition = [
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = var.sns_access_arns
        }
      ]
    }
  ] : []

  s3_statements = length(var.s3_access_names) > 0 ? [
    {
      sid     = "AllowS3Access"
      effect  = "Allow"
      actions = ["sqs:SendMessage"]
      principals = [
        {
          type        = "Service"
          identifiers = ["s3.amazonaws.com"]
        }
      ]
      resources = [
        "arn:aws:sqs:${var.aws_region}:${var.account_id}:${local.queue_name}"
      ]
      condition = [
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = [for bucket in var.s3_access_names : "arn:aws:s3:::${bucket}"]
        }
      ]
    }
  ] : []

  iam_statements = concat(
    local.sns_statements,
    local.s3_statements,
    var.extra_iam_statements
  )

  # O módulo espera um map(object) mas a solução modular gera list(object).
  # O for expression converte a lista usando o sid de cada statement como chave.
  # index() é usado como fallback quando sid é null para evitar chave nula no map.
  queue_policy_statements = {
    for idx, stmt in local.iam_statements : coalesce(stmt.sid, tostring(idx)) => stmt
  }
}

# Validação que garante que ao menos uma policy foi definida antes do apply.
# Impede que a fila suba sem nenhuma permissão configurada.
resource "terraform_data" "validate_fifo_options" {
  lifecycle {
    precondition {
      condition     = !var.content_based_deduplication || var.fifo_queue
      error_message = "content_based_deduplication só pode ser habilitado em filas FIFO (fifo_queue = true)."
    }
    precondition {
      condition     = var.fifo_throughput_limit == null || var.fifo_queue
      error_message = "fifo_throughput_limit só pode ser configurado em filas FIFO (fifo_queue = true)."
    }
  }
}

resource "terraform_data" "validate_iam_statements" {
  lifecycle {
    precondition {
      condition     = !var.create_queue_policy || length(local.iam_statements) > 0
      error_message = "Ao menos uma policy é obrigatória: sns_access_arns, s3_access_names ou extra_iam_statements. Para desabilitar a policy completamente use create_queue_policy: false."
    }
  }
}
