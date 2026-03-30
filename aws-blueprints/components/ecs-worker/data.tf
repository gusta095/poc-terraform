# Obtém informações do cluster ECS pelo nome — usado apenas quando cluster_arn não é fornecido
data "aws_ecs_cluster" "ecs_cluster" {
  count        = var.cluster_arn == "" ? 1 : 0
  cluster_name = var.cluster_name
}

# Obtém as informações da VPC especificada.
# Depende da tag `tag:Name` aplicada pela blueprint de VPC deste projeto —
# a convenção é garantida pelo módulo components/vpc e não precisa ser configurada manualmente.
data "aws_vpc" "vpc_infos" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_primary_name]
  }
}

# Obtém todas as subnets públicas dentro da VPC especificada.
# Depende da tag `subnet-type: public` aplicada pela blueprint de VPC deste projeto —
# a convenção é garantida pelo módulo components/vpc e não precisa ser configurada manualmente.
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_infos.id]
  }

  # Filtra apenas as subnets marcadas como "public"
  filter {
    name   = "tag:subnet-type"
    values = ["public"]
  }
}

# Criação do JSON para a política IAM do ECS Task Execution Role
data "aws_iam_policy_document" "ecs_task_execution_policy" {
  statement {
    sid    = "AllowECRPull"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  dynamic "statement" {
    for_each = length(local.ssm_secret_arns) > 0 ? [1] : []
    content {
      sid    = "AllowSSMParameterRead"
      effect = "Allow"
      actions = [
        "ssm:GetParameters",
        "ssm:GetParameter"
      ]
      resources = local.ssm_secret_arns
    }
  }
  dynamic "statement" {
    for_each = length(local.secretsmanager_secret_arns) > 0 ? [1] : []
    content {
      sid    = "AllowSecretsManagerRead"
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue"
      ]
      resources = local.secretsmanager_secret_arns
    }
  }
}

# Criação do JSON para a política IAM do ECS Task Role
data "aws_iam_policy_document" "ecs_task_policy" {
  dynamic "statement" {
    for_each = local.iam_statements
    content {
      sid       = try(statement.value.sid, null)
      effect    = try(statement.value.effect, "Allow")
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

# Task execution e task role são iguais, então reutilizei o documento para ambos
data "aws_iam_policy_document" "this" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
