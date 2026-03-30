.PHONY: help
default: help

help:
	@echo ""
	@echo "\033[1mAWS Config Live\033[0m"
	@echo ""
	@echo "\033[1mQualidade\033[0m"
	@printf "  %-30s %s\n" "make lint"        "Roda todos os pre-commit hooks"
	@printf "  %-30s %s\n" "make fmt"         "Formata todos os arquivos HCL"
	@printf "  %-30s %s\n" "make fmt-check"   "Verifica formatação HCL (sem aplicar)"
	@echo ""
	@echo "\033[1mManutencao\033[0m"
	@printf "  %-30s %s\n" "make clean-cache" "Remove .terraform e .terragrunt-cache"
	@printf "  %-30s %s\n" "make help"        "Exibe esta mensagem"
	@echo ""

.PHONY: lint
lint:
	pre-commit run --all-files --verbose --show-diff-on-failure --color always

.PHONY: fmt
fmt:
	terragrunt hcl format

.PHONY: fmt-check
fmt-check:
	terragrunt hcl format --recursive --check

.PHONY: clean-cache
clean-cache:
	find . -type d \( -name '.terragrunt-cache' -o -name '.terraform' \) -print -prune -exec rm -rf '{}' \;
	@echo
	find . -type f -name '.terraform.lock.hcl' -print -prune -exec rm -f '{}' \;
