# Development Guide

This guide explains how to use the local development tools for the Vor Terraform GKE module.

## Quick Start

```bash
# Install all required tools
make install-tools

# Run all checks
make all

# Individual checks
make validate      # Validate Terraform configuration
make lint         # Run TFLint checks
make security     # Run Trivy and Checkov security scans
make docs         # Generate documentation with terraform-docs
make test-examples # Test examples with mocked credentials

# Clean up
make clean
```

## Available Commands

Run `make help` to see all available commands:

```bash
make help
```

### Common Workflows

**Daily Development:**
```bash
make validate      # Validate configuration
make lint         # Run linting checks
make test-examples # Test examples (optional)
```

**Before Committing:**
```bash
make all          # Run all checks (validation, linting, security, docs, examples)
```

**Security Scanning:**
```bash
make security  # Run Trivy and Checkov security scans
```

**Documentation Generation:**
```bash
make docs         # Generate documentation with terraform-docs
```

**Example Testing:**
```bash
make test-examples  # Test examples with mocked GCP credentials
```

## Tool Requirements

The Makefile will install these tools automatically:

- **OpenTofu** - Infrastructure as Code (Terraform-compatible)
- **TFLint** - Terraform linting with Google Cloud provider rules
- **Trivy** - Modern security and misconfiguration scanning (replaces tfsec)
- **Checkov** - Additional security and compliance scanning

## Reports

Security scan results are saved to `reports/` directory:
- `reports/trivy-results.json` - Trivy scan results
- `reports/checkov-results.json` - Checkov scan results

## Integration with CI

The GitHub Actions workflow runs the same checks as the Makefile. Use the Makefile for local development and the workflow will validate your changes in CI.

### Example Testing

Example configurations in `examples/` are automatically tested using a custom GitHub Action:

- **Location**: `.github/actions/test-examples/`
- **Purpose**: Validates example Terraform configurations with mocked GCP credentials
- **Runs**: Automatically in CI pipeline
- **Features**:
  - Tests syntax validation
  - Mocks GCP provider credentials
  - Validates Terraform plan generation
  - Provides detailed test reports

The custom action ensures that example configurations remain valid without requiring real GCP credentials in CI.

## OpenTofu vs Terraform

This project uses OpenTofu (the open-source fork of Terraform) instead of Terraform. OpenTofu is fully compatible with Terraform configurations and provides the same functionality.

If you prefer to use Terraform instead, you can create an alias:
```bash
alias tofu=terraform
```
