locals {

  # O índice 5 faz parte dos argumentos da função element()
  # Guard para evitar crash quando sqs_access_arns está vazio e sqs_messages_scaling não é usado
  default_scaling_queue = length(var.sqs_access_arns) > 0 ? element(split(":", var.sqs_access_arns[0]), 5) : ""

  scaling_queue_name = var.sqs_specific_name != "" ? var.sqs_specific_name : local.default_scaling_queue

  available_autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value       = 60
        scale_out_cooldown = 30
        scale_in_cooldown  = 60
      }
    }
    memory = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
        target_value       = 70
        scale_out_cooldown = 30
        scale_in_cooldown  = 60
      }
    }
    sqs_messages_scaling = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        customized_metric_specification = {
          metrics = [
            {
              id = "m1"
              metric_stat = {
                metric = {
                  namespace   = "AWS/SQS"
                  metric_name = "ApproximateNumberOfMessagesVisible"
                  dimensions = [
                    {
                      name  = "QueueName"
                      value = local.scaling_queue_name
                    }
                  ]
                }
                stat = "Sum"
              }
              return_data = false
            },
            {
              id = "m2"
              metric_stat = {
                metric = {
                  namespace   = "AWS/SQS"
                  metric_name = "ApproximateNumberOfMessagesNotVisible"
                  dimensions = [
                    {
                      name  = "QueueName"
                      value = local.scaling_queue_name
                    }
                  ]
                }
                stat = "Sum"
              }
              return_data = false
            },
            {
              id = "m3"
              metric_stat = {
                metric = {
                  namespace   = "ECS/ContainerInsights"
                  metric_name = "DesiredTaskCount"
                  dimensions = [
                    {
                      name  = "ClusterName"
                      value = var.cluster_name
                    },
                    {
                      name  = "ServiceName"
                      value = var.worker_name
                    }
                  ]
                }
                stat = "Average"
              }
              return_data = false
            },
            {
              id          = "e1"
              expression  = "(m1 + m2) / m3"
              label       = "BacklogPerTask"
              return_data = true
            }
          ]
        }
        target_value       = 50
        scale_out_cooldown = 15
        scale_in_cooldown  = 60
      }
    }
  }

  autoscaling_policies = {
    for strategy in var.autoscale_strategy :
    strategy => local.available_autoscaling_policies[strategy]
  }
}

#------------------------------------------------------------------------------
# Validações de precondição
#------------------------------------------------------------------------------

resource "terraform_data" "validate_sqs_scaling" {
  lifecycle {
    precondition {
      condition = !contains(var.autoscale_strategy, "sqs_messages_scaling") || (
        length(var.sqs_access_arns) > 0 || var.sqs_specific_name != ""
      )
      error_message = "sqs_messages_scaling requer sqs_access_arns ou sqs_specific_name."
    }
  }
}

resource "terraform_data" "validate_autoscaling_range" {
  lifecycle {
    precondition {
      condition     = var.autoscaling_min <= var.autoscaling_max
      error_message = "autoscaling_min (${var.autoscaling_min}) não pode ser maior que autoscaling_max (${var.autoscaling_max})."
    }
  }
}
