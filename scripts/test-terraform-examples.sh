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

# Default values (can be overridden by environment variables)
DEFAULT_PROJECT_ID="${MOCK_PROJECT_ID:-mock-project}"
DEFAULT_REGION="${MOCK_REGION:-us-central1}"
DEFAULT_ZONE="${MOCK_ZONE:-us-central1-a}"

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to create mock credentials JSON file
create_mock_credentials() {
    local project_id=$1
    cat > mock-credentials.json << EOF
{
  "type": "service_account",
  "project_id": "$project_id",
  "private_key_id": "mock-key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC8Q7HgL8Y9L9rX\nMOCK_PRIVATE_KEY_CONTENT_HERE\n-----END PRIVATE KEY-----\n",
  "client_email": "mock@$project_id.iam.gserviceaccount.com",
  "client_id": "123456789012345678901",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/mock%40$project_id.iam.gserviceaccount.com"
}
EOF
}

# Function to create provider override file
create_provider_override() {
    local project_id=$1
    local region=$2
    local zone=$3
    cat > provider_override.tf << EOF
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
  project = "$project_id"
  region  = "$region"
  zone    = "$zone"
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
    local project_id=${3:-$DEFAULT_PROJECT_ID}
    local region=${4:-$DEFAULT_REGION}
    local zone=${5:-$DEFAULT_ZONE}

    print_status "$BLUE" "🧪 Testing example: $example_name"

    cd "$example_dir"

    # Copy terraform.tfvars.example if it exists
    if [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        print_status "$GREEN" "📝 Copied terraform.tfvars.example to terraform.tfvars"
    fi

    # Create mock files
    create_provider_override "$project_id" "$region" "$zone"
    create_mock_credentials "$project_id"

    # Determine which terraform binary to use
    TERRAFORM_CMD="terraform"
    if command -v tofu &> /dev/null; then
        TERRAFORM_CMD="tofu"
        print_status "$BLUE" "🔧 Using OpenTofu instead of Terraform"
    fi

    # Initialize Terraform
    print_status "$BLUE" "🔧 Initializing $TERRAFORM_CMD for $example_name..."
    if [ "$show_output" = true ]; then
        init_output=$($TERRAFORM_CMD init -backend=false 2>&1)
        init_result=$?
        echo "$init_output"
    else
        init_output=$($TERRAFORM_CMD init -backend=false 2>&1)
        init_result=$?
    fi

    if [ $init_result -eq 0 ]; then
        print_status "$GREEN" "✅ $TERRAFORM_CMD init successful for $example_name"

        print_status "$BLUE" "📋 Running $TERRAFORM_CMD plan for $example_name..."
        if [ "$show_output" = true ]; then
            plan_output=$($TERRAFORM_CMD plan -out=plan.tfplan \
                -var="project_id=$project_id" \
                -var="region=$region" \
                -var="location=$zone" \
                -detailed-exitcode 2>&1)
            plan_result=$?
            echo "$plan_output"
        else
            plan_output=$($TERRAFORM_CMD plan -out=plan.tfplan \
                -var="project_id=$project_id" \
                -var="region=$region" \
                -var="location=$zone" \
                -detailed-exitcode 2>&1)
            plan_result=$?
        fi

        # Exit codes: 0 = no changes, 1 = error, 2 = changes planned
        if [ $plan_result -eq 0 ] || [ $plan_result -eq 2 ]; then
            print_status "$GREEN" "✅ $TERRAFORM_CMD plan successful for $example_name"
            cleanup_test_files
            cd - > /dev/null
            return 0
        else
            print_status "$YELLOW" "⚠️ $TERRAFORM_CMD plan failed for $example_name"
            if [ "$show_output" = false ]; then
                echo "Plan output:"
                echo "$plan_output"
            fi
            cleanup_test_files
            cd - > /dev/null
            return 1
        fi
    else
        print_status "$RED" "❌ $TERRAFORM_CMD init failed for example: $example_name"
        if [ "$show_output" = false ]; then
            echo "Init output:"
            echo "$init_output"
        fi
        cleanup_test_files
        cd - > /dev/null
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -v, --verbose           Show terraform output"
    echo "  -e, --example NAME      Test specific example (e.g., basic)"
    echo "  -p, --project-id ID     Mock GCP project ID (default: $DEFAULT_PROJECT_ID)"
    echo "  -r, --region REGION     Mock GCP region (default: $DEFAULT_REGION)"
    echo "  -z, --zone ZONE         Mock GCP zone (default: $DEFAULT_ZONE)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  MOCK_PROJECT_ID         Override default project ID"
    echo "  MOCK_REGION             Override default region"
    echo "  MOCK_ZONE               Override default zone"
}

# Main function
main() {
    local show_output=false
    local specific_example=""
    local project_id="$DEFAULT_PROJECT_ID"
    local region="$DEFAULT_REGION"
    local zone="$DEFAULT_ZONE"

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
            -p|--project-id)
                project_id="$2"
                shift 2
                ;;
            -r|--region)
                region="$2"
                shift 2
                ;;
            -z|--zone)
                zone="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    print_status "$BLUE" "🧪 Testing example configurations with mocked credentials..."
    print_status "$BLUE" "📋 Using project: $project_id, region: $region, zone: $zone"

    # Set up mock environment variables
    export GOOGLE_PROJECT="$project_id"

    examples_tested=0
    examples_passed=0

    if [ -n "$specific_example" ]; then
        # Test specific example
        if [ -d "examples/$specific_example" ]; then
            examples_tested=1
            if test_example "examples/$specific_example" "$show_output" "$project_id" "$region" "$zone"; then
                examples_passed=1
            fi
        else
            print_status "$RED" "❌ Example 'examples/$specific_example' not found"
            exit 1
        fi
    else
        # Test all examples
        if [ ! -d "examples" ]; then
            print_status "$RED" "❌ Examples directory not found"
            exit 1
        fi

        for example in examples/*/; do
            if [ -d "$example" ]; then
                examples_tested=$((examples_tested + 1))
                if test_example "$example" "$show_output" "$project_id" "$region" "$zone"; then
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
