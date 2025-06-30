#!/bin/bash

# Script to import existing AWS resources into Terraform state
# Run this from the terraform/ directory

set -e

echo "🔄 Importing existing AWS resources into Terraform state..."

cd terraform

# Import ECR repository
echo "📦 Importing ECR repository..."
terraform import aws_ecr_repository.api devops-assessment-dev-api || echo "ECR repository already in state or doesn't exist"

# Import Secrets Manager secret
echo "🔐 Importing Secrets Manager secret..."
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id devops-assessment-dev-redis-password --query 'ARN' --output text 2>/dev/null || echo "")
if [ ! -z "$SECRET_ARN" ]; then
    terraform import aws_secretsmanager_secret.redis_password devops-assessment-dev-redis-password || echo "Secret already in state"
    terraform import aws_secretsmanager_secret_version.redis_password "$SECRET_ARN|AWSCURRENT" || echo "Secret version already in state"
else
    echo "Secret not found, will be created on next apply"
fi

# Import IAM role for node group
echo "👤 Importing IAM role for node group..."
terraform import 'module.eks.module.eks_managed_node_group["main"].aws_iam_role.this[0]' devops-assessment-dev-node-group-role || echo "Role already in state or doesn't exist"

# Import CloudWatch log group
echo "📊 Importing CloudWatch log group..."
terraform import 'module.eks.aws_cloudwatch_log_group.this[0]' /aws/eks/devops-assessment-dev/cluster || echo "Log group already in state or doesn't exist"

echo "✅ Import process completed!"
echo ""
echo "🚨 Next steps to resolve remaining issues:"
echo "1. Release unused EIPs to avoid EIP limit errors"
echo "2. Run terraform plan to see remaining issues"
echo "3. Run terraform apply to create missing resources"

echo ""
echo "💡 To check and release unused EIPs:"
echo "aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].[AllocationId,PublicIp]' --output table"
echo "aws ec2 release-address --allocation-id <allocation-id>"

echo ""
echo "💡 To reduce AZs and avoid EIP limits, consider updating terraform/variables.tf:"
echo "default = 2  # Instead of 3 AZs"
