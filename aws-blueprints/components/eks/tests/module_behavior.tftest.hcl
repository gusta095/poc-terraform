# ==============================================================================
# TESTES: Comportamento do módulo EKS
#
# Verifica que recursos são criados/omitidos corretamente com base nas flags,
# que nomes seguem a convenção e que policies corretas são anexadas.
#
# Como rodar:
#   cd components/eks
#   terraform init -backend=false
#   terraform test -filter=tests/module_behavior.tftest.hcl
# ==============================================================================

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDAXXXXXXXXXXXXXXXXX"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn   = "arn:aws:iam::123456789012:user/test"
      issuer_id    = "AIDAXXXXXXXXXXXXXXXXX"
      issuer_name  = "test"
      session_name = ""
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition          = "aws"
      dns_suffix         = "amazonaws.com"
      reverse_dns_prefix = "com.amazonaws"
    }
  }
}

# Variáveis base válidas usadas em todos os runs.
variables {
  environment = "sandbox"
  account_id  = "123456789012"
  name        = "eks-lab"
  vpc_id      = "vpc-12345678"
  subnet_ids  = ["subnet-12345678", "subnet-87654321"]
}

# ==============================================================================
# EBS CSI Driver — role e policy attachment
# ==============================================================================

run "ebs_csi_desabilitado_por_padrao_nao_cria_role" {
  command = plan

  assert {
    condition     = length(aws_iam_role.ebs_csi) == 0
    error_message = "aws_iam_role.ebs_csi não deveria ser criada quando enable_ebs_csi_driver = false."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.ebs_csi) == 0
    error_message = "aws_iam_role_policy_attachment.ebs_csi não deveria ser criada quando enable_ebs_csi_driver = false."
  }
}

run "ebs_csi_habilitado_cria_role_com_nome_correto" {
  command = plan

  variables {
    enable_ebs_csi_driver = true
  }

  assert {
    condition     = length(aws_iam_role.ebs_csi) == 1
    error_message = "aws_iam_role.ebs_csi deveria ser criada quando enable_ebs_csi_driver = true."
  }

  assert {
    condition     = aws_iam_role.ebs_csi[0].name == "eks-lab-ebs-csi-driver"
    error_message = "Nome da role EBS CSI deve seguir o padrão {name}-ebs-csi-driver."
  }
}

run "ebs_csi_habilitado_anexa_policy_correta" {
  command = plan

  variables {
    enable_ebs_csi_driver = true
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.ebs_csi) == 1
    error_message = "Policy attachment do EBS CSI deveria ser criada."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ebs_csi[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    error_message = "Policy ARN do EBS CSI incorreta."
  }
}

# ==============================================================================
# Node Monitoring — role e policy attachment
# ==============================================================================

run "node_monitoring_desabilitado_por_padrao_nao_cria_role" {
  command = plan

  assert {
    condition     = length(aws_iam_role.node_monitoring) == 0
    error_message = "aws_iam_role.node_monitoring não deveria ser criada quando enable_node_monitoring = false."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.node_monitoring) == 0
    error_message = "aws_iam_role_policy_attachment.node_monitoring não deveria ser criada quando enable_node_monitoring = false."
  }
}

run "node_monitoring_habilitado_cria_role_com_nome_correto" {
  command = plan

  variables {
    enable_node_monitoring = true
  }

  assert {
    condition     = length(aws_iam_role.node_monitoring) == 1
    error_message = "aws_iam_role.node_monitoring deveria ser criada quando enable_node_monitoring = true."
  }

  assert {
    condition     = aws_iam_role.node_monitoring[0].name == "eks-lab-node-monitoring"
    error_message = "Nome da role de node monitoring deve seguir o padrão {name}-node-monitoring."
  }
}

run "node_monitoring_habilitado_anexa_policy_correta" {
  command = plan

  variables {
    enable_node_monitoring = true
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.node_monitoring) == 1
    error_message = "Policy attachment do node monitoring deveria ser criada."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.node_monitoring[0].policy_arn == "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    error_message = "Policy ARN do node monitoring incorreta."
  }
}

run "ambos_addons_opcionais_criam_duas_roles" {
  command = plan

  variables {
    enable_ebs_csi_driver  = true
    enable_node_monitoring = true
  }

  assert {
    condition     = length(aws_iam_role.ebs_csi) == 1 && length(aws_iam_role.node_monitoring) == 1
    error_message = "Ambas as roles deveriam ser criadas quando os dois addons estão habilitados."
  }
}

# ==============================================================================
# Convenção de nomes — nome do cluster reflete var.name
# ==============================================================================

run "nome_do_cluster_reflete_variavel_name" {
  command = plan

  variables {
    name = "meu-cluster-prod"
  }

  assert {
    condition     = module.eks.cluster_name == "meu-cluster-prod"
    error_message = "cluster_name deve ser igual a var.name."
  }
}

run "nome_da_role_ebs_csi_reflete_name_do_cluster" {
  command = plan

  variables {
    name                  = "meu-cluster-prod"
    enable_ebs_csi_driver = true
  }

  assert {
    condition     = aws_iam_role.ebs_csi[0].name == "meu-cluster-prod-ebs-csi-driver"
    error_message = "Nome da role EBS CSI deve usar o nome do cluster como prefixo."
  }
}

run "nome_da_role_node_monitoring_reflete_name_do_cluster" {
  command = plan

  variables {
    name                   = "meu-cluster-prod"
    enable_node_monitoring = true
  }

  assert {
    condition     = aws_iam_role.node_monitoring[0].name == "meu-cluster-prod-node-monitoring"
    error_message = "Nome da role node monitoring deve usar o nome do cluster como prefixo."
  }
}

# ==============================================================================
# Cenários completos
# ==============================================================================

run "cenario_lab_endpoint_publico" {
  command = plan

  variables {
    name                         = "eks-lab"
    eks_version                  = "1.35"
    endpoint_public_access       = true
    endpoint_public_access_cidrs = ["0.0.0.0/0"]
    creator_admin                = true
    enabled_log_types            = ["audit", "api", "authenticator"]
  }

  assert {
    condition     = module.eks.cluster_name == "eks-lab"
    error_message = "cluster_name incorreto no cenário lab."
  }
}

run "cenario_producao_privado_com_kms_e_logs" {
  command = plan

  variables {
    name                = "eks-prod"
    eks_version         = "1.35"
    create_kms_key      = true
    enabled_log_types   = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    log_retention_days  = 180
    authentication_mode = "API"
    access_entries = {
      platform-team = {
        principal_arn = "arn:aws:iam::123456789012:role/platform-team"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    }
  }

  assert {
    condition     = module.eks.cluster_name == "eks-prod"
    error_message = "cluster_name incorreto no cenário produção."
  }
}

run "cenario_bootstrap_com_node_group_on_demand" {
  command = plan

  variables {
    name        = "eks-prod"
    eks_version = "1.35"
    managed_node_groups = {
      bootstrap = {
        instance_types     = ["t3.medium"]
        capacity_type      = "ON_DEMAND"
        min_size           = 1
        max_size           = 2
        desired_size       = 1
        kubernetes_version = "1.35"
        labels = {
          role = "bootstrap"
        }
      }
    }
  }

  assert {
    condition     = module.eks.cluster_name == "eks-prod"
    error_message = "cluster_name incorreto no cenário bootstrap."
  }
}

run "cenario_multiplos_node_groups_on_demand_e_spot" {
  command = plan

  variables {
    name        = "eks-prod"
    eks_version = "1.35"
    managed_node_groups = {
      system = {
        instance_types     = ["t3.medium"]
        capacity_type      = "ON_DEMAND"
        kubernetes_version = "1.35"
        labels             = { role = "system" }
      }
      workers = {
        instance_types     = ["t3.large", "t3.xlarge"]
        capacity_type      = "SPOT"
        min_size           = 0
        max_size           = 10
        desired_size       = 2
        kubernetes_version = "1.35"
        labels             = { role = "worker" }
      }
    }
  }

  assert {
    condition     = module.eks.cluster_name == "eks-prod"
    error_message = "cluster_name incorreto no cenário multi node group."
  }
}

run "cenario_stack_completa_todos_addons" {
  command = plan

  variables {
    name                   = "eks-full"
    eks_version            = "1.35"
    create_kms_key         = true
    enable_ebs_csi_driver  = true
    enable_node_monitoring = true
    enabled_log_types      = ["api", "audit", "authenticator"]
    log_retention_days     = 90
    managed_node_groups = {
      bootstrap = {
        instance_types     = ["t3.medium"]
        capacity_type      = "ON_DEMAND"
        kubernetes_version = "1.35"
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.ebs_csi) == 1
    error_message = "Role EBS CSI deveria ser criada."
  }

  assert {
    condition     = length(aws_iam_role.node_monitoring) == 1
    error_message = "Role node monitoring deveria ser criada."
  }

  assert {
    condition     = module.eks.cluster_name == "eks-full"
    error_message = "cluster_name incorreto na stack completa."
  }
}
