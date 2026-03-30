# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

module "tags" {
  source = "git::https://github.com/gusta-lab/terraform-aws-module-tags.git?ref=v2.1.0"

  environment = var.environment
  tags        = var.tags
}

#------------------------------------------------------------------------------
# IAM tasks execution role and policy
#------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.worker_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.this.json

  tags = module.tags.tags
}

resource "aws_iam_policy" "ecs_task_execution_policy" {
  name   = "${var.worker_name}-execution-policy"
  policy = data.aws_iam_policy_document.ecs_task_execution_policy.json

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
}

#------------------------------------------------------------------------------
# IAM tasks role and policy
#------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_role" {
  count = length(local.iam_statements) > 0 ? 1 : 0

  name               = "${var.worker_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.this.json

  tags = module.tags.tags
}

resource "aws_iam_policy" "ecs_task_policy" {
  count = length(local.iam_statements) > 0 ? 1 : 0

  name   = "${var.worker_name}-task-policy"
  policy = data.aws_iam_policy_document.ecs_task_policy.json

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attach" {
  count = length(local.iam_statements) > 0 ? 1 : 0

  role       = aws_iam_role.ecs_task_role[count.index].name
  policy_arn = aws_iam_policy.ecs_task_policy[0].arn
}

#------------------------------------------------------------------------------
# Security Group
#------------------------------------------------------------------------------

module "ecs_worker_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.1"

  name        = "${var.worker_name}-sg"
  description = "Security group for ${var.worker_name} ECS worker"
  vpc_id      = data.aws_vpc.vpc_infos.id

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
      description = "Allow all IPv4 traffic"
    }
  ]

  tags = module.tags.tags
}

#------------------------------------------------------------------------------
# ECS Service Worker
#------------------------------------------------------------------------------

module "ecs_service_worker" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.3.1"

  name = var.worker_name

  cluster_arn    = local.cluster_arn
  create_service = var.create_service

  cpu    = var.cpu
  memory = var.memory

  container_definitions = local.container_definitions
  propagate_tags        = var.propagate_tags

  autoscaling_min_capacity = var.autoscaling_min
  autoscaling_max_capacity = var.autoscaling_max
  autoscaling_policies     = local.autoscaling_policies

  create_security_group = false
  security_group_ids    = [module.ecs_worker_sg.security_group_id]

  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = aws_iam_role.ecs_task_execution_role.arn

  create_tasks_iam_role = false
  tasks_iam_role_arn    = try(aws_iam_role.ecs_task_role[0].arn, null)

  deployment_circuit_breaker = var.deployment_circuit_breaker

  subnet_ids       = data.aws_subnets.public_subnets.ids
  assign_public_ip = var.assign_public_ip

  tags = module.tags.tags
}
