locals {
  # Acesso root sempre presente — garante acesso de emergência ao cluster via console AWS.
  # O account_id é injetado pelo Terragrunt; entradas adicionais são mergeadas via var.access_entries.
  default_access_entries = {
    root = {
      principal_arn     = "arn:aws:iam::${var.account_id}:root"
      kubernetes_groups = []
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

  all_access_entries = merge(local.default_access_entries, var.access_entries)

  addons = merge(
    {
      vpc-cni = {
        most_recent    = true
        before_compute = true
      }
      coredns = {
        most_recent = true
      }
      kube-proxy = {
        most_recent = true
      }
      eks-pod-identity-agent = {
        most_recent = true
      }
    },
    var.enable_ebs_csi_driver ? {
      aws-ebs-csi-driver = {
        most_recent = true
        pod_identity_association = [{
          role_arn        = aws_iam_role.ebs_csi[0].arn
          service_account = "ebs-csi-controller-sa"
        }]
      }
    } : {},
    var.enable_node_monitoring ? {
      amazon-cloudwatch-observability = {
        most_recent = true
        pod_identity_association = [{
          role_arn        = aws_iam_role.node_monitoring[0].arn
          service_account = "cloudwatch-agent"
        }]
      }
    } : {}
  )
}
