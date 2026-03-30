# ------------------------------------------------------------------------------
# FIXTURE: Lógica de policy_statements.tf e autoscaling_policies.tf
#
# Este módulo replica os locals e a geração de statements para que
# os testes unitários possam verificar a lógica sem precisar de provider AWS
# (sem custo, sem credenciais reais).
#
# ATENÇÃO: Quando policy_statements.tf ou autoscaling_policies.tf forem
# atualizados, este arquivo deve ser atualizado também para manter os
# testes em sincronia.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Variáveis — espelham as variáveis relevantes do componente
# ------------------------------------------------------------------------------

variable "sqs_access_arns" {
  type    = list(string)
  default = []
}

variable "sns_access" {
  type    = list(string)
  default = []
}

variable "dynamodb_access" {
  type    = list(string)
  default = []
}

variable "lambda_access" {
  type    = list(string)
  default = []
}

variable "s3_access_names" {
  type    = list(string)
  default = []
}

variable "secrets" {
  type    = map(string)
  default = {}
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

variable "sqs_specific_name" {
  type    = string
  default = ""
}

variable "autoscale_strategy" {
  type    = list(string)
  default = ["cpu", "memory"]
}

# ------------------------------------------------------------------------------
# Réplica exata de policy_statements.tf
# ------------------------------------------------------------------------------

locals {
  sqs_statements = length(var.sqs_access_arns) > 0 ? [
    {
      sid = "AllowSQSAccess"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility",
        "sqs:SendMessage"
      ]
      resources = var.sqs_access_arns
    }
  ] : []

  sns_statements = length(var.sns_access) > 0 ? [
    {
      sid       = "AllowSNSPublish"
      actions   = ["sns:Publish"]
      resources = var.sns_access
    }
  ] : []

  dynamodb_statements = length(var.dynamodb_access) > 0 ? [
    {
      sid = "AllowDynamoDBReadWrite"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      resources = var.dynamodb_access
    }
  ] : []

  lambda_statements = length(var.lambda_access) > 0 ? [
    {
      sid       = "AllowLambdaInvoke"
      actions   = ["lambda:InvokeFunction"]
      resources = var.lambda_access
    }
  ] : []

  s3_statements = length(var.s3_access_names) > 0 ? [
    {
      sid = "AllowS3Access"
      actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ]
      resources = flatten([
        for name in var.s3_access_names : [
          "arn:aws:s3:::${name}",
          "arn:aws:s3:::${name}/*"
        ]
      ])
    }
  ] : []

  ssm_secret_arns = [
    for arn in values(var.secrets) : arn
    if startswith(arn, "arn:aws:ssm:")
  ]

  secretsmanager_secret_arns = [
    for arn in values(var.secrets) : arn
    if startswith(arn, "arn:aws:secretsmanager:")
  ]

  iam_statements = concat(
    local.sqs_statements,
    local.sns_statements,
    local.dynamodb_statements,
    local.lambda_statements,
    local.s3_statements,
    var.extra_iam_statements
  )
}

# ------------------------------------------------------------------------------
# Réplica exata de autoscaling_policies.tf (lógica de seleção)
# ------------------------------------------------------------------------------

locals {
  default_scaling_queue = length(var.sqs_access_arns) > 0 ? element(split(":", var.sqs_access_arns[0]), 5) : ""
  scaling_queue_name    = var.sqs_specific_name != "" ? var.sqs_specific_name : local.default_scaling_queue

  available_strategies = toset(["cpu", "memory", "sqs_messages_scaling"])

  autoscaling_policies_keys = [
    for strategy in var.autoscale_strategy : strategy
    if contains(local.available_strategies, strategy)
  ]
}

# ------------------------------------------------------------------------------
# Outputs usados pelas asserções dos testes
# ------------------------------------------------------------------------------

output "iam_statements_count" {
  value = length(local.iam_statements)
}

output "iam_statement_sids" {
  value = [for s in local.iam_statements : s.sid]
}

output "sqs_statements_count" {
  value = length(local.sqs_statements)
}

output "sns_statements_count" {
  value = length(local.sns_statements)
}

output "dynamodb_statements_count" {
  value = length(local.dynamodb_statements)
}

output "lambda_statements_count" {
  value = length(local.lambda_statements)
}

output "s3_statements_count" {
  value = length(local.s3_statements)
}

output "ssm_secret_arns" {
  value = local.ssm_secret_arns
}

output "secretsmanager_secret_arns" {
  value = local.secretsmanager_secret_arns
}

output "s3_resources" {
  value = length(local.s3_statements) > 0 ? local.s3_statements[0].resources : []
}

output "scaling_queue_name" {
  value = local.scaling_queue_name
}

output "autoscaling_policies_keys" {
  value = local.autoscaling_policies_keys
}
