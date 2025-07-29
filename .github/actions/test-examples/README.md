# Test Terraform Examples Action

A custom GitHub Action that tests Terraform example configurations with mocked GCP credentials.

## Features

- Tests all example configurations in a specified directory
- Mocks GCP credentials and provider configuration for CI testing
- Validates Terraform syntax and basic plan generation
- Provides detailed output and summary reporting
- Cleans up temporary files after testing

## Usage

```yaml
- name: Test Examples
  uses: ./.github/actions/test-examples
  with:
    examples-path: 'examples'
    terraform-version: '~1.5'
    mock-project-id: 'mock-project'
    mock-region: 'us-central1'
    mock-zone: 'us-central1-a'
```

## Inputs

| Input               | Description                     | Required | Default         |
| ------------------- | ------------------------------- | -------- | --------------- |
| `examples-path`     | Path to the examples directory  | No       | `examples`      |
| `terraform-version` | Terraform version to use        | No       | `latest`        |
| `mock-project-id`   | Mock GCP project ID for testing | No       | `mock-project`  |
| `mock-region`       | Mock GCP region for testing     | No       | `us-central1`   |
| `mock-zone`         | Mock GCP zone for testing       | No       | `us-central1-a` |

## Outputs

| Output            | Description                               |
| ----------------- | ----------------------------------------- |
| `examples-tested` | Number of examples tested                 |
| `examples-passed` | Number of examples that passed validation |

## How It Works

1. **Discovery**: Scans the specified examples directory for subdirectories containing Terraform configurations
2. **Setup**: For each example:
   - Copies `terraform.tfvars.example` to `terraform.tfvars` if it exists
   - Creates a mock provider configuration with fake GCP credentials
   - Creates mock credentials file
3. **Testing**:
   - Runs `terraform init -backend=false` to initialize without backend
   - Runs `terraform plan` with mock variables to validate configuration
4. **Cleanup**: Removes all temporary files and Terraform state
5. **Reporting**: Provides summary of results in GitHub Actions summary

## Mock Configuration

The action creates a mock GCP provider configuration that:
- Uses fake service account credentials
- Sets up a mock project, region, and zone
- Disables backend initialization for testing
- Allows Terraform to validate syntax and resource definitions without actual GCP API calls

## Example Directory Structure

```
examples/
├── basic/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── advanced/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars.example
```

## Expected Behavior

- **Success**: Configuration is syntactically valid and can generate a plan
- **Warning**: Plan generation fails but configuration syntax is valid
- **Failure**: Terraform init or severe syntax errors prevent testing

The action is designed to be permissive, focusing on syntax validation rather than requiring successful plan generation, since we're using mock credentials.
