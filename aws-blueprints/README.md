<div align="center">

# Terraform AWS Blueprints

<p>Biblioteca de componentes Terraform para infraestrutura AWS.<br/>Padrões opinionados com defaults sensatos, gestão de tags e suporte a notificações.</p>

</div>

---

## Componentes

| Categoria | Componente | Path |
|-----------|-----------|------|
| **Application Integration** | SNS | `components/application-integration/sns` |
| | SQS | `components/application-integration/sqs` |
| **Compute** | EC2 Instance | `components/compute/instance` |
| | Lambda | `components/compute/lambda` |
| **Containers** | ECS Cluster | `components/containers/ecs/cluster` |
| | ECS Service | `components/containers/ecs/service` |
| | ECS Service Worker | `components/containers/ecs/service-worker` |
| | EKS | `components/containers/eks` |
| **Networking** | ALB | `components/networking/load-balancer/alb` |
| | NLB | `components/networking/load-balancer/nlb` |
| | Route53 Zone | `components/networking/route53/zone` |
| | Route53 Record | `components/networking/route53/record` |
| | VPC | `components/networking/vpc` |
| **Security** | ACM Certificate | `components/security/acm/certificate` |
| | IAM S3 Replication Role | `components/security/iam/s3-replication-role` |
| | KMS | `components/security/kms` |
| | Secret Manager | `components/security/secret-manager` |
| **Storage** | S3 Bucket | `components/storage/s3/bucket` |
| | S3 Global Resources | `components/storage/s3/global-resources` |
| **Integrations** | SQS com SNS | `components/integrations/sqs-with-sns` |
| **Organizations** | Account Alias | `components/organizations/account-alias` |

---

## Como usar

Os componentes são referenciados via **Terragrunt** no repositório `aws-config-live`:

```hcl
terraform {
  source = "git::https://github.com/gusta-lab/terraform-aws-blueprints.git//components/application-integration/sqs?ref=v26.03.10"
}

inputs = {
  environment = "prod"
  tags        = {}
}
```

---

## Decisões arquiteturais

### Blueprints individuais vs compostos

Cada recurso AWS tem seu próprio blueprint independente (`sqs`, `sns`, `vpc`, etc.). Para cenários onde recursos são **sempre usados juntos por natureza**, existe o padrão de blueprint composto — um blueprint que chama outros blueprints como módulos Terraform.

**Exemplo planejado:** `event-driven` — chama `sqs` + `sns` internamente, gerencia a integração (subscription, queue policy) sem expor essa complexidade para o consumidor.

**Por quê:** Evita dependência circular entre units no live repo. O acoplamento entre recursos de integração pertence ao código Terraform, não à camada de orquestração Terragrunt.

### Blueprints como módulos

Blueprints compostos referenciam blueprints individuais via `module` com source git pinado em versão:

```hcl
module "sqs" {
  source = "git::https://github.com/gusta-lab/terraform-aws-blueprints.git//components/application-integration/sqs?ref=v26.03.13"
}
```

**Por quê:** Reaproveita toda a lógica de validação, segurança e defaults já construída nos blueprints individuais, sem duplicação de código.

### Validações com `terraform_data` preconditions

Validações de negócio (ex: "ao menos uma policy é obrigatória") são feitas via `terraform_data` com `lifecycle.precondition`, não via `variable validation`. Isso permite validações que cruzam múltiplas variáveis e locals.

### data sources em vez de `dependency` blocks

Quando um blueprint precisa de informações de outro recurso existente (ex: VPC para ECS), usa `data "aws_vpc"` por nome/tag em vez de `dependency` block do Terragrunt. Isso desacopla o blueprint do live repo e permite uso standalone.

---

## Pré-requisitos

| Ferramenta | Versão |
|------------|--------|
| Terraform | `1.14.5` |
| Terragrunt | `>= 0.50` |
| terraform-docs | `0.21.0` |
| tflint | `0.55.1` |

> Versões gerenciadas via [asdf](https://asdf-vm.com/) — veja `.tool-versions`.

---

## Desenvolvimento

```bash
make lint       # Roda todos os pre-commit hooks
make docs       # Regenera todos os READMEs
make test-all   # Roda todos os testes unitários
make help       # Lista todos os targets disponíveis
```

O CI executa `lint` e `terraform test` automaticamente em todo PR para `main`.
