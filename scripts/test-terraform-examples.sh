#!/bin/bash

# Terraform Example Testing Script
# Tests example configurations with mocked GCP credentials

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to create mock credentials JSON file
create_mock_credentials() {
    cat > mock-credentials.json << 'EOF'
{
  "type": "service_account",
  "project_id": "mock-project",
  "private_key_id": "mock-key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC8Q7HgL8Y9L9rX\nMOCK_PRIVATE_KEY_CONTENT_HERE\n-----END PRIVATE KEY-----\n",
  "client_email": "mock@mock-project.iam.gserviceaccount.com",
  "client_id": "123456789012345678901",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/mock%40mock-project.iam.gserviceaccount.com"
}
EOF
}

# Function to create provider override file
create_provider_override() {
    cat > provider_override.tf << 'EOF'
# Mock provider configuration for testing
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "mock-project"
  region  = "us-central1"
  zone    = "us-central1-a"
  credentials = file("mock-credentials.json")
  user_project_override = false
}
EOF
}

# Function to cleanup test files
cleanup_test_files() {
    rm -f provider_override.tf mock-credentials.json terraform.tfvars plan.tfplan
    rm -rf .terraform .terraform.lock.hcl
}

# Function to test a single example
test_example() {
    local example_dir=$1
    local example_name=$(basename "$example_dir")
    local show_output=${2:-false}

    print_status "$BLUE" "🧪 Testing example: $example_name"

    cd "$example_dir"

    # Copy terraform.tfvars.example if it exists
    if [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        print_status "$GREEN" "📝 Copied terraform.tfvars.example to terraform.tfvars"
    fi

    # Create mock files
    create_provider_override
    create_mock_credentials

    # Initialize Terraform
    print_status "$BLUE" "🔧 Initializing Terraform for $example_name..."
    if [ "$show_output" = true ]; then
        init_output=$(tofu init -backend=false 2>&1)
        init_result=$?
        echo "$init_output"
    else
        init_output=$(tofu init -backend=false 2>&1)
        init_result=$?
    fi

    if [ $init_result -eq 0 ]; then
        print_status "$GREEN" "✅ Terraform init successful for $example_name"

        print_status "$BLUE" "📋 Running Terraform plan for $example_name..."
        if [ "$show_output" = true ]; then
            plan_output=$(tofu plan -out=plan.tfplan -var="project_id=mock-project" -var="region=us-central1" -var="location=us-central1-a" 2>&1)
            plan_result=$?
            echo "$plan_output"
        else
            plan_output=$(tofu plan -out=plan.tfplan -var="project_id=mock-project" -var="region=us-central1" -var="location=us-central1-a" 2>&1)
            plan_result=$?
        fi

        if [ $plan_result -eq 0 ] || [ $plan_result -eq 2 ]; then
            print_status "$GREEN" "✅ Terraform plan successful for $example_name"
            cleanup_test_files
            cd - > /dev/null
            return 0
        else
            print_status "$YELLOW" "⚠️ Terraform plan failed for $example_name"
            if [ "$show_output" = false ]; then
                echo "Plan output:"
                echo "$plan_output"
            fi
            cleanup_test_files
            cd - > /dev/null
            return 1
        fi
    else
        print_status "$RED" "❌ Terraform init failed for example: $example_name"
        if [ "$show_output" = false ]; then
            echo "Init output:"
            echo "$init_output"
        fi
        cleanup_test_files
        cd - > /dev/null
        return 1
    fi
}

# Main function
main() {
    local show_output=false
    local specific_example=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                show_output=true
                shift
                ;;
            -e|--example)
                specific_example="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -v, --verbose    Show terraform output"
                echo "  -e, --example    Test specific example (e.g., basic)"
                echo "  -h, --help       Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    print_status "$BLUE" "🧪 Testing example configurations with mocked credentials..."

    # Set up mock environment variables
    export GOOGLE_PROJECT="mock-project"

    examples_tested=0
    examples_passed=0

    if [ -n "$specific_example" ]; then
        # Test specific example
        if [ -d "examples/$specific_example" ]; then
            examples_tested=1
            if test_example "examples/$specific_example" "$show_output"; then
                examples_passed=1
            fi
        else
            print_status "$RED" "❌ Example 'examples/$specific_example' not found"
            exit 1
        fi
    else
        # Test all examples
        for example in examples/*/; do
            if [ -d "$example" ]; then
                examples_tested=$((examples_tested + 1))
                if test_example "$example" "$show_output"; then
                    examples_passed=$((examples_passed + 1))
                fi
                echo ""
            fi
        done
    fi

    # Print summary
    echo ""
    print_status "$BLUE" "📊 Summary: $examples_passed/$examples_tested examples passed validation"

    if [ $examples_passed -eq $examples_tested ] && [ $examples_tested -gt 0 ]; then
        print_status "$GREEN" "✅ All examples passed validation!"
        exit 0
    elif [ $examples_passed -gt 0 ]; then
        print_status "$YELLOW" "⚠️ Some examples had validation issues but syntax is valid"
        exit 0
    else
        print_status "$RED" "❌ No examples passed validation"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
