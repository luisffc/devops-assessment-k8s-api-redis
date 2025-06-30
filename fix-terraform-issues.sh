#!/bin/bash

# Comprehensive script to fix all Terraform issues
# Run this from the project root directory

set -e

echo "🔧 DevOps Assessment - Terraform Fix Script"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "terraform/main.tf" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

echo ""
echo "1. 🔍 Checking EIP usage and releasing unused ones..."
bash check-eips.sh

echo ""
echo "2. 📦 Importing existing resources into Terraform state..."
bash import-existing-resources.sh

echo ""
echo "3. 🔄 Running Terraform plan to check for remaining issues..."
cd terraform
terraform plan -detailed-exitcode || {
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 2 ]; then
        echo "✅ Terraform plan shows changes needed"
    else
        echo "❌ Terraform plan failed with exit code $EXIT_CODE"
        exit $EXIT_CODE
    fi
}

echo ""
echo "4. 🎯 Summary of fixes applied:"
echo "   ✅ Updated IAM policy with missing permissions (KMS, EC2, etc.)"
echo "   ✅ Reduced AZs from 3 to 2 to avoid EIP limits"
echo "   ✅ Imported existing resources to avoid conflicts"
echo ""
echo "🚀 Next steps:"
echo "   1. Review the Terraform plan output above"
echo "   2. Run 'terraform apply' to create/update resources"
echo "   3. If you still hit EIP limits, consider:"
echo "      - Requesting EIP limit increase from AWS Support"
echo "      - Using a single AZ for development (not recommended for production)"
echo ""
echo "📝 Note: The GitHub Actions workflow should now work with the updated IAM permissions"
