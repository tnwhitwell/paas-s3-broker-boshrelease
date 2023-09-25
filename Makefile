.DEFAULT_GOAL := help

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: lint_shellcheck
lint_shellcheck:
	find . -name '*.sh' \
		-not -path './.git/*' \
		-not -path '*/vendor/*' \
	| xargs shellcheck

.PHONY: lint
lint: lint_shellcheck ## Run linting tests
