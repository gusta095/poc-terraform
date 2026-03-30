# ------------------------------------------------------------------------------
# FIXTURE: Lógica de locals.tf + policy-statements.tf do componente SQS
#
# Este módulo replica os locals e a geração de policy statements para que
# os testes unitários possam verificar a lógica sem precisar de provider AWS
# (sem custo, sem credenciais reais).
#
# ATENÇÃO: Quando locals.tf ou policy-statements.tf forem atualizados, este
# arquivo deve ser atualizado também para manter os testes em sincronia.
# ------------------------------------------------------------------------------

variable "name" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "account_id" {
  type    = string
  default = "123456789012"
}

variable "fifo_queue" {
  type    = bool
  default = false
}

variable "sns_access_arns" {
  type    = list(string)
  default = []
}

variable "s3_access_names" {
  type    = list(string)
  default = []
}

variable "extra_iam_statements" {
  type = list(object({
    sid           = optional(string)
    effect        = optional(string, "Allow")
    actions       = optional(list(string))
    not_actions   = optional(list(string))
    resources     = optional(list(string))
    not_resources = optional(list(string))
    condition = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })))
  }))
  default = []
}

# ------------------------------------------------------------------------------
# Réplica exata de locals.tf
# ------------------------------------------------------------------------------

locals {
  queue_name     = var.fifo_queue ? "${var.name}.fifo" : var.name
  dlq_queue_name = var.fifo_queue ? "${var.name}-dlq.fifo" : var.name
}

# ------------------------------------------------------------------------------
# Réplica exata de policy-statements.tf
# ------------------------------------------------------------------------------

locals {
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

  iam_statements = concat(local.sns_statements, local.s3_statements, var.extra_iam_statements)

  queue_policy_statements = {
    for idx, stmt in local.iam_statements : coalesce(stmt.sid, tostring(idx)) => stmt
  }
}

# ------------------------------------------------------------------------------
# Outputs usados pelas asserções dos testes
# ------------------------------------------------------------------------------

output "queue_name" {
  value = local.queue_name
}

output "dlq_queue_name" {
  value = local.dlq_queue_name
}

output "iam_statements_count" {
  value = length(local.iam_statements)
}

output "queue_policy_keys" {
  value = keys(local.queue_policy_statements)
}

output "has_sns_statement" {
  value = length(local.sns_statements) > 0
}

output "has_s3_statement" {
  value = length(local.s3_statements) > 0
}

output "sns_statement_resource_arn" {
  value = length(local.sns_statements) > 0 ? local.sns_statements[0].resources[0] : ""
}

output "s3_statement_condition_arns" {
  value = length(local.s3_statements) > 0 ? local.s3_statements[0].condition[0].values : []
}

# Permite verificar se o ARN na policy usa o nome correto da fila
# (com sufixo .fifo quando FIFO) — usado em fifo_naming.tftest.hcl
output "default_policy_resource_arn" {
  value = "arn:aws:sqs:${var.aws_region}:${var.account_id}:${local.queue_name}"
}
