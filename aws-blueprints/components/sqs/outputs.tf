# ------------------------------------------------------------------------------
# SQS
# ------------------------------------------------------------------------------

output "queue_arn" {
  description = "O ARN da fila SQS"
  value       = module.sqs.queue_arn
}

output "queue_url" {
  description = "A URL da fila SQS criada"
  value       = module.sqs.queue_url
}

output "queue_name" {
  description = "O nome da fila SQS"
  value       = module.sqs.queue_name
}

# ------------------------------------------------------------------------------
# SQS DLQ
# ------------------------------------------------------------------------------

output "dlq_arn" {
  description = "O ARN da fila DLQ. Null quando create_dlq = false."
  value       = var.create_dlq ? module.sqs.dead_letter_queue_arn : null
}

output "dlq_url" {
  description = "A URL da fila DLQ. Null quando create_dlq = false."
  value       = var.create_dlq ? module.sqs.dead_letter_queue_url : null
}

output "dlq_name" {
  description = "O nome da fila DLQ. Null quando create_dlq = false."
  value       = var.create_dlq ? module.sqs.dead_letter_queue_name : null
}
