# Variáveis
VERSION_FILE=VERSION
CHANGELOG_FILE=CHANGELOG.md
DEFAULT_BRANCH := main

# Obtém a versão atual
CURRENT_VERSION=$(shell cat $(VERSION_FILE))

# Gerando nova versão
NEW_VERSION_SCRIPT := ./_bin/get-new-project-version.sh
NEW_VERSION = $(shell $(NEW_VERSION_SCRIPT) $(CURRENT_VERSION))

.PHONY: help
default: help

help:
	@echo ""
	@echo "🚀 \033[1mTerraform AWS Blueprints\033[0m  —  v$(CURRENT_VERSION)"
	@echo ""
	@echo "\033[1mVersionamento\033[0m"
	@printf "  %-30s %s\n" "make bump-version"        "Calcula e aplica a nova versão (cria tag)"
	@printf "  %-30s %s\n" "make commit-version"      "Publica (push) a nova versão após confirmação"
	@printf "  %-30s %s\n" "make version"             "Exibe a versão atual"
	@echo ""
	@echo "\033[1mTestes\033[0m"
	@printf "  %-30s %s\n" "make test-all"            "Roda todos os testes unitários"
	@printf "  %-30s %s\n" "make test-sqs"            "Testes unitários — SQS"
	@printf "  %-30s %s\n" "make test-sns"            "Testes unitários — SNS"
	@printf "  %-30s %s\n" "make test-sqs-with-sns"   "Testes unitários — integração SQS+SNS"
	@printf "  %-30s %s\n" "make test-service-worker" "Testes unitários — ECS service-worker"
	@printf "  %-30s %s\n" "make test-ecs-cluster"    "Testes unitários — ECS cluster"
	@printf "  %-30s %s\n" "make test-iam-role"       "Testes unitários — IAM role"
	@printf "  %-30s %s\n" "make test-iam-provider"   "Testes unitários — IAM OIDC provider"
	@printf "  %-30s %s\n" "make test-route53-zone"   "Testes unitários — Route53 Zone"
	@printf "  %-30s %s\n" "make test-acm"            "Testes unitários — ACM"
	@printf "  %-30s %s\n" "make test-eks"            "Testes unitários — EKS"
	@echo ""
	@echo "\033[1mQualidade\033[0m"
	@printf "  %-30s %s\n" "make lint"                "Roda todos os pre-commit hooks"
	@printf "  %-30s %s\n" "make docs"                "Atualiza todos os READMEs via terraform-docs"
	@echo ""
	@echo "\033[1mManutencao\033[0m"
	@printf "  %-30s %s\n" "make clean-cache"         "Remove .terraform e .terragrunt-cache"
	@printf "  %-30s %s\n" "make help"                "Exibe esta mensagem"
	@echo ""

# Atualiza a versão e gera uma nova tag
.PHONY: bump-version
bump-version:
	@echo "Atualizando a versão..."
	@echo

# Verifica se o repositório está limpo antes de rodar o bump2version
	@if ! git diff --quiet || ! git diff --cached --quiet; then \
		echo "O repositório contém mudanças não commitadas."; \
		echo "Faça um commit ou use 'git stash' antes de rodar este comando."; \
		exit 1; \
	fi

# Continua apenas se não houver mudanças pendentes
	git checkout $(DEFAULT_BRANCH)
	@echo
	bump2version --new-version $(NEW_VERSION) patch || { \
		echo "Erro ao atualizar a versão. Verifique se o comando está correto."; \
		exit 1; \
	}
	@echo "Versão atual: $(CURRENT_VERSION)"
	@echo
	@echo "Versão atualizada para: '$(NEW_VERSION)'! Verifique a nova tag:"
	@echo
	git show v$(NEW_VERSION)
	@echo
	@echo "Se estiver tudo certo, execute 'make commit-version' para publicar a nova versão."

# Commita a versão e pergunta antes de confirmar
.PHONY: commit-version
commit-version:
	@read -p "Tem certeza que deseja commit? (yes/no): " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		git push --follow-tags origin $(DEFAULT_BRANCH); \
	else \
		echo "Commit cancelado."; \
	fi

# Exibe a versão atual do projeto
.PHONY: version
version:
	@echo "Versão atual: $(CURRENT_VERSION)"

.PHONY: test-all
test-all: test-sqs test-sns test-sqs-with-sns test-service-worker test-ecs-cluster test-iam-role test-iam-provider test-route53-zone test-acm test-eks

.PHONY: test-sqs
test-sqs:
	cd components/sqs && terraform init -backend=false && terraform test

.PHONY: test-sns
test-sns:
	cd components/sns && terraform init -backend=false && terraform test

.PHONY: test-sqs-with-sns
test-sqs-with-sns:
	cd components/sqs-with-sns && terraform init -backend=false && terraform test

.PHONY: test-service-worker
test-service-worker:
	cd components/ecs-worker && terraform init -backend=false && terraform test

.PHONY: test-ecs-cluster
test-ecs-cluster:
	cd components/ecs-cluster && terraform init -backend=false && terraform test

.PHONY: test-iam-role
test-iam-role:
	cd components/iam-role && terraform init -backend=false && terraform test

.PHONY: test-iam-provider
test-iam-provider:
	cd components/iam-provider && terraform init -backend=false && terraform test

.PHONY: test-route53-zone
test-route53-zone:
	cd components/route53-zone && terraform init -backend=false && terraform test

.PHONY: test-acm
test-acm:
	cd components/acm && terraform init -backend=false && terraform test

.PHONY: test-eks
test-eks:
	cd components/eks && terraform init -backend=false && terraform test

.PHONY: lint
lint:
	pre-commit run --all-files --verbose --show-diff-on-failure --color always

.PHONY: docs
docs:
	find . -name '.terraform.lock.hcl' -print -delete
	pre-commit run terraform_docs --all-files

# Remova pastas temporárias relacionadas ao Terraform
.PHONY: clean-cache
clean-cache:
	find . -type d \( -name '.terragrunt-cache' -o -name '.terraform' \) -print -prune -exec rm -rf '{}' \;
