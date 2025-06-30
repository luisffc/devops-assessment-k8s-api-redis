#!/bin/bash

# ENI Import Helper Script
# This script helps import orphaned ENIs into Terraform state

VPC_ID="${vpc_id}"

echo "=== ENI Import Helper ==="
echo "VPC ID: $VPC_ID"
echo ""

echo "Step 1: List all ENIs in the VPC"
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Description:Description,Status:Status,Type:InterfaceType}' \
  --output table

echo ""
echo "Step 2: Import commands for common ENI types"
echo ""

# Get EKS ENIs
echo "# EKS Cluster ENIs:"
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=Amazon EKS*" \
  --query 'NetworkInterfaces[].NetworkInterfaceId' \
  --output text | xargs -I {} echo "terraform import 'aws_network_interface.eks_{}' {}"

echo ""
echo "# Load Balancer ENIs:"
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=ELB*" \
  --query 'NetworkInterfaces[].NetworkInterfaceId' \
  --output text | xargs -I {} echo "terraform import 'aws_network_interface.lb_{}' {}"

echo ""
echo "# VPC Endpoint ENIs:"
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=VPC Endpoint*" \
  --query 'NetworkInterfaces[].NetworkInterfaceId' \
  --output text | xargs -I {} echo "terraform import 'aws_network_interface.vpce_{}' {}"

echo ""
echo "Step 3: Manual cleanup commands (if needed)"
echo ""
echo "# To delete available ENIs manually:"
echo "aws ec2 describe-network-interfaces --filters \"Name=vpc-id,Values=$VPC_ID\" \"Name=status,Values=available\" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | xargs -I {} aws ec2 delete-network-interface --network-interface-id {}"

echo ""
echo "=== End of Script ==="
