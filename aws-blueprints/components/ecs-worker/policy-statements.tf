locals {
  sqs_statements = length(var.sqs_access_arns) > 0 ? [
    {
      sid    = "AllowSQSAccess"
      effect = "Allow"
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
      sid    = "AllowSNSPublish"
      effect = "Allow"
      actions = [
        "sns:Publish"
      ]
      resources = var.sns_access
    }
  ] : []

  dynamodb_statements = length(var.dynamodb_access) > 0 ? [
    {
      sid    = "AllowDynamoDBReadWrite"
      effect = "Allow"
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
      sid    = "AllowLambdaInvoke"
      effect = "Allow"
      actions = [
        "lambda:InvokeFunction"
      ]
      resources = var.lambda_access
    }
  ] : []

  s3_statements = length(var.s3_access_names) > 0 ? [
    {
      sid    = "AllowS3Access"
      effect = "Allow"
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
