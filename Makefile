# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

# Makefile for Vor Terraform GKE Module
# Provides local development tools for linting, validation, and security scanning

.PHONY: help install-tools validate docs

# Default target
help: ## Show this help message
	@echo "Vor Terraform GKE Module - Development Tools"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Tool installation
install-tools: ## Install required development tools
	@echo "🔧 Installing development tools..."
	@# Install OpenTofu
	@if ! command -v tofu >/dev/null 2>&1; then \
		echo "📦 Installing OpenTofu..."; \
		curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | sh -s -- --install-method standalone; \
	else \
		echo "✅ OpenTofu already installed: $$(tofu version | head -n1)"; \
	fi
	@# Install terraform-docs
	@if ! command -v terraform-docs >/dev/null 2>&1; then \
		echo "📦 Installing terraform-docs..."; \
		if [ "$$(uname)" = "Darwin" ]; then \
			brew install terraform-docs; \
		else \
			curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.17.0/terraform-docs-v0.17.0-$$(uname | tr '[:upper:]' '[:lower:]')-amd64.tar.gz; \
			tar -xzf terraform-docs.tar.gz; \
			chmod +x terraform-docs; \
			sudo mv terraform-docs /usr/local/bin/; \
			rm terraform-docs.tar.gz; \
		fi; \
	else \
		echo "✅ terraform-docs already installed: $$(terraform-docs --version)"; \
	fi

# Documentation generation
docs: ## Generate documentation using terraform-docs
	@echo "📚 Generating documentation with terraform-docs..."
	@# Generate main README
	@echo "📝 Generating main README.md..."
	@terraform-docs --config .terraform-docs/main.yml --output-file README.md . || { echo "❌ Failed to generate main README.md"; exit 1; }
	@# Generate component documentation
	@echo "📝 Generating component documentation..."
	@for component in cluster network nodes policies; do \
		echo "  📄 Generating $$component documentation..."; \
		terraform-docs --config .terraform-docs/$$component.yml --output-file docs/components/$$component.md .; \
	done
	@echo "✅ Documentation generation completed"
	@echo ""
	@echo "Generated files:"
	@echo "  📄 README.md (main module documentation)"
	@echo "  📄 docs/components/cluster.md"
	@echo "  📄 docs/components/network.md"
	@echo "  📄 docs/components/nodes.md"
	@echo "  📄 docs/components/policies.md"

validate: ## Validate Terraform configuration
	@echo "🔍 Validating Terraform configuration..."
	@# Validate root module
	@echo "📂 Validating root module..."
	@tofu init -backend=false
	@tofu validate
	@# Validate examples
	@for example in examples/*/; do \
		if [ -d "$$example" ]; then \
			echo "📂 Validating example: $$example"; \
			(cd "$$example" && tofu init -backend=false && tofu validate); \
		fi; \
	done
	@echo "✅ All Terraform configurations are valid"
