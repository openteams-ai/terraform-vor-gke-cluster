# Copyright (c) 2025 Vor Project Contributors
# SPDX-License-Identifier: Apache-2.0

# Makefile for Vor Terraform GKE Module
# Provides loca	@echo "🧹 Cleaning up..." development tools for linting, validation, and security scanning

.PHONY: help install-tools validate lint security-trivy security-checkov security clean all test-examples

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
	@# Install Trivy (replaces TFSec)
	@if ! command -v trivy >/dev/null 2>&1; then \
		echo "📦 Installing Trivy..."; \
		if [ "$$(uname)" = "Darwin" ]; then \
			brew install aquasecurity/trivy/trivy; \
		else \
			curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ~/.local/bin; \
		fi; \
	else \
		echo "✅ Trivy already installed: $$(trivy --version | head -n1)"; \
	fi
	@# Install Checkov
	@if ! command -v checkov >/dev/null 2>&1; then \
		echo "📦 Installing Checkov..."; \
		pip3 install --user checkov; \
	else \
		echo "✅ Checkov already installed: $$(checkov --version)"; \
	fi
	@echo "✅ All tools installed successfully!"

# Test example configurations with mocked GCP credentials
test-examples: ## Test all example configurations with mocked GCP credentials
	@chmod +x ./scripts/test-terraform-examples.sh
	@if [ -n "$(EXAMPLE)" ]; then \
		echo "🧪 Testing specific example: $(EXAMPLE)"; \
		MOCK_PROJECT_ID=$(MOCK_PROJECT_ID) MOCK_REGION=$(MOCK_REGION) MOCK_ZONE=$(MOCK_ZONE) \
		./scripts/test-terraform-examples.sh -v -e "$(EXAMPLE)"; \
	else \
		echo "🧪 Testing all examples"; \
		MOCK_PROJECT_ID=$(MOCK_PROJECT_ID) MOCK_REGION=$(MOCK_REGION) MOCK_ZONE=$(MOCK_ZONE) \
		./scripts/test-terraform-examples.sh -v; \
	fi

test-example: ## Test a specific example with verbose output (requires EXAMPLE variable)
	@if [ -z "$(EXAMPLE)" ]; then \
		echo "❌ EXAMPLE variable is required. Use: make test-example EXAMPLE=your-example-name"; \
		exit 1; \
	fi
	@echo "🧪 Testing example: $(EXAMPLE)"
	@chmod +x ./scripts/test-terraform-examples.sh
	@MOCK_PROJECT_ID=$(MOCK_PROJECT_ID) MOCK_REGION=$(MOCK_REGION) MOCK_ZONE=$(MOCK_ZONE) \
	./scripts/test-terraform-examples.sh -v -e "$(EXAMPLE)"

list-examples: ## List all available examples
	@echo "📁 Available examples:"
	@if [ -d "examples" ]; then \
		for example in examples/*/; do \
			if [ -d "$example" ]; then \
				example_name=$(basename "$example"); \
				echo "  📂 $example_name"; \
			fi \
		done \
	else \
		echo "❌ Examples directory not found"; \
	fi

clean-test-artifacts: ## Clean up any leftover test artifacts from examples
	@echo "🧹 Cleaning test artifacts..."
	@find examples -name "provider_override.tf" -delete 2>/dev/null || true
	@find examples -name "mock-credentials.json" -delete 2>/dev/null || true
	@find examples -name "terraform.tfvars" -delete 2>/dev/null || true
	@find examples -name "plan.tfplan" -delete 2>/dev/null || true
	@find examples -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find examples -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "✅ Test artifacts cleaned"

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
security-trivy: ## Run Trivy security scan
	@echo "🔍 Running Trivy security scan..."
	@mkdir -p reports
	@trivy config . \
		--format json \
		--output reports/trivy-results.json \
		--exit-code 0
	@echo ""
	@echo "📊 Trivy Results Summary:"
	@if [ -f "reports/trivy-results.json" ]; then \
		ISSUES=$$(jq '.Results[]? | select(.Misconfigurations) | .Misconfigurations | length' reports/trivy-results.json 2>/dev/null | awk '{sum+=$$1} END {print sum+0}'); \
		echo "   Issues found: $$ISSUES"; \
		if [ "$$ISSUES" != "0" ]; then \
			echo "   📁 Detailed results: reports/trivy-results.json"; \
		fi; \
	fi
	@echo "✅ Trivy security scan completed"

security-checkov: ## Run Checkov security scan
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

security: security-trivy security-checkov ## Run all security scans
	@echo ""
	@echo "🛡️ Security Scan Summary"
	@echo "========================"
	@if [ -f "reports/trivy-results.json" ]; then \
		TRIVY_ISSUES=$$(jq '.Results[]? | select(.Misconfigurations) | .Misconfigurations | length' reports/trivy-results.json 2>/dev/null | awk '{sum+=$$1} END {print sum+0}'); \
		echo "Trivy: $$TRIVY_ISSUES issues found"; \
	fi
	@if [ -f "reports/checkov-results.json" ]; then \
		CHECKOV_FAILED=$$(jq '.summary.failed' reports/checkov-results.json 2>/dev/null || echo "0"); \
		CHECKOV_PASSED=$$(jq '.summary.passed' reports/checkov-results.json 2>/dev/null || echo "0"); \
		echo "Checkov: $$CHECKOV_FAILED failed, $$CHECKOV_PASSED passed"; \
	fi
	@echo ""
	@echo "📁 Detailed results available in reports/ directory"

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
all: validate lint security test-examples ## Run all checks (validation, linting, security, examples)
	@echo ""
	@echo "✅ All checks completed successfully!"
	@echo ""
	@echo "Summary:"
	@echo "  ✅ Validation passed"
	@echo "  ✅ Linting passed"
	@echo "  ✅ Security scan completed"
	@echo "  ✅ Example testing completed"
	@echo ""
	@if [ -d "reports" ]; then \
		echo "📁 Security scan results available in reports/ directory"; \
	fi

# Example testing is also available locally via 'make test-examples'
# This uses the same mock credentials approach as the GitHub Action
# located at .github/actions/test-examples/
