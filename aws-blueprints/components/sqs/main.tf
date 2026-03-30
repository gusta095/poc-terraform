# ------------------------------------------------------------------------------
# TAGS
# ------------------------------------------------------------------------------

module "tags" {
  source = "git::https://github.com/gusta-lab/terraform-aws-module-tags.git?ref=v2.1.0"

  environment = var.environment
  tags        = var.tags
}

# ------------------------------------------------------------------------------
# SQS
# ------------------------------------------------------------------------------

module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "5.2.1"

  name = var.name

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  sqs_managed_sse_enabled    = var.sqs_managed_sse_enabled
  kms_master_key_id          = var.kms_master_key_id

  content_based_deduplication = var.content_based_deduplication
  fifo_throughput_limit       = var.fifo_throughput_limit

  create_queue_policy     = var.create_queue_policy
  queue_policy_statements = local.queue_policy_statements

  create_dlq = var.create_dlq

  redrive_policy = var.create_dlq ? { maxReceiveCount = var.max_receive_count } : {}

  dlq_visibility_timeout_seconds = var.dlq_visibility_timeout_seconds
  dlq_message_retention_seconds  = var.dlq_message_retention_seconds
  dlq_delay_seconds              = var.dlq_delay_seconds
  dlq_receive_wait_time_seconds  = var.dlq_receive_wait_time_seconds
  dlq_sqs_managed_sse_enabled    = var.dlq_sqs_managed_sse_enabled
  dlq_kms_master_key_id          = var.dlq_kms_master_key_id

  fifo_queue = var.fifo_queue

  tags = module.tags.tags
}
