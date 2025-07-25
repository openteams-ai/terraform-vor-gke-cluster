# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

# Makefile for Vor Terraform GKE Module
# Provides local development tools for linting, validation, and security scanning

.PHONY: help install-tools validate lint security clean all

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
		curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | sh; \
	else \
		echo "✅ OpenTofu already installed: $$(tofu version | head -n1)"; \
	fi
	@# Install TFLint
	@if ! command -v tflint >/dev/null 2>&1; then \
		echo "📦 Installing TFLint..."; \
		curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; \
	else \
		echo "✅ TFLint already installed: $$(tflint --version)"; \
	fi
	@# Install Checkov
	@if ! command -v checkov >/dev/null 2>&1; then \
		echo "📦 Installing Checkov..."; \
		pip3 install --user checkov; \
	else \
		echo "✅ Checkov already installed: $$(checkov --version)"; \
	fi
	@echo "✅ All tools installed successfully!"

# Validation
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

# Linting
setup-tflint: ## Setup TFLint configuration
	@echo "⚙️ Setting up TFLint configuration..."
	@printf 'plugin "terraform" {\n  enabled = true\n  preset  = "recommended"\n}\n\nplugin "google" {\n  enabled = true\n  version = "0.25.0"\n  source  = "github.com/terraform-linters/tflint-ruleset-google"\n}\n\nrule "terraform_required_providers" {\n  enabled = true\n}\n\nrule "terraform_required_version" {\n  enabled = true\n}\n\nrule "terraform_naming_convention" {\n  enabled = true\n}\n\nrule "terraform_documented_variables" {\n  enabled = true\n}\n\nrule "terraform_documented_outputs" {\n  enabled = true\n}\n' > .tflint.hcl
	@echo "✅ TFLint configuration created"

lint: setup-tflint ## Run TFLint checks
	@echo "🔍 Running TFLint checks..."
	@tflint --init
	@tflint --format=compact
	@echo "✅ TFLint checks completed"

# Security scanning
security: ## Run Checkov security scan
	@echo "🔍 Running Checkov security scan..."
	@mkdir -p reports
	@checkov -d . \
		--framework terraform \
		--output json \
		--output-file reports/checkov-results.json \
		--soft-fail >/dev/null 2>&1 || true
	@echo ""
	@echo "📊 Checkov Results Summary:"
	@if [ -f "reports/checkov-results.json" ]; then \
		FAILED=$$(jq '.summary.failed' reports/checkov-results.json 2>/dev/null || echo "0"); \
		PASSED=$$(jq '.summary.passed' reports/checkov-results.json 2>/dev/null || echo "0"); \
		echo "   Failed checks: $$FAILED"; \
		echo "   Passed checks: $$PASSED"; \
		if [ "$$FAILED" != "0" ]; then \
			echo "   📁 Detailed results: reports/checkov-results.json"; \
		fi; \
	fi
	@echo "✅ Checkov security scan completed"

# Cleanup
clean: ## Clean up generated files and reports
	@echo "� Cleaning up..."
	@rm -rf .terraform*
	@rm -rf reports/
	@rm -f .tflint.hcl
	@find . -name "plan.tfplan" -delete
	@find . -name "terraform.tfvars" -path "*/examples/*" -delete
	@echo "✅ Cleanup completed"

# Complete workflow
all: validate lint security ## Run all checks (validation, linting, security)
	@echo ""
	@echo "✅ All checks completed successfully!"
	@echo ""
	@echo "Summary:"
	@echo "  ✅ Validation passed"
	@echo "  ✅ Linting passed"
	@echo "  ✅ Security scan completed"
	@echo ""
	@if [ -d "reports" ]; then \
		echo "📁 Security scan results available in reports/ directory"; \
	fi
