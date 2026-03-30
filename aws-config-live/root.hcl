# ------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# ------------------------------------------------------------------------------

# Versão mínima
terraform_version_constraint  = ">= 1.14.5"
terragrunt_version_constraint = ">= 0.99.2"

locals {
  # Configuração dos componentes
  repo_root     = get_repo_root()
  relative_path = path_relative_to_include()

  # Carregar automaticamente variáveis ​​em nível de conta e região
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals

  # Extraindo as variáveis para facilitar o acesso
  account_name = local.account_vars.account_name
  account_id   = local.account_vars.account_id
  aws_region   = local.region_vars.aws_region

  # Tags para auditoria
  component_repo = "aws-config-live"
  component_path = substr(local.relative_path, 0, 256)
  remote_state_tags = {
    createdby = "terraform"
  }
}

# Gerador de provider AWS
generate "aws_provider" {
  path      = "aws-provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = templatefile(
    "${local.repo_root}/_templates/aws-provider.tpl",
    {
      current_region = local.aws_region
      account_id     = local.account_id
      default_tags = {
        component-repo = local.component_repo
        component-path = local.component_path
      }
    }
  )
}

# Configuração do remote_state
remote_state {
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  backend = "s3"
  config = {
    bucket         = "terraform-tfstate-${local.account_id}-${local.account_name}"
    key            = "${local.relative_path}/terraform.tfstate"
    region         = local.aws_region
    s3_bucket_tags = local.remote_state_tags
    encrypt        = true
    use_lockfile   = true
  }
}

# Configuração de retry automático
errors {
  retry "default" {
    max_attempts       = 3
    sleep_interval_sec = 5
    retryable_errors = [
      "(?s).*Error installing provider.*tcp.*connection reset by peer.*",
      "(?s).*read:.*software caused connection abort.*",
      "(?s).*ssh_exchange_identification.*Connection closed by remote host.*",
      "(?s).*Error: .* S3 [Bb]ucket .* OperationAborted: A conflicting .*",
      "(?s).*Error .* Route53 VPC Association Authorization: ConcurrentModification: A conflicting modification.*occurred. Please retry.*",
      "(?s).*error waiting for Route in Route Table .* to become available: timeout while waiting for state.*",
      "(?s).*Error: .* error tagging resource .* InvalidReplicationGroupState: Cluster not in available state to perform tagging operations.*",
      "(?s).*RequestLimitExceeded.*",
      "(?s).*ThrottlingException.*",
      "(?s).*DependencyViolation: The resource is in use.*"
    ]
  }
}

# Exportação de variáveis nível de conta e região
inputs = merge(
  local.account_vars,
  local.region_vars,
)
