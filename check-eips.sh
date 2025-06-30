#!/bin/bash

# Script to check and release unused EIPs to resolve EIP limit issues
# Run this before applying Terraform

set -e

echo "🔍 Checking for unused EIPs that can be released..."

# Get all EIPs not associated with any resource
UNUSED_EIPS=$(aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].AllocationId' --output text)

if [ -z "$UNUSED_EIPS" ]; then
    echo "ℹ️  No unused EIPs found."
    echo "📊 Current EIP usage:"
    aws ec2 describe-addresses --query 'Addresses[*].[AllocationId,PublicIp,AssociationId]' --output table
else
    echo "🗑️  Found unused EIPs:"
    aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].[AllocationId,PublicIp]' --output table

    echo ""
    read -p "Do you want to release these unused EIPs? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for eip in $UNUSED_EIPS; do
            echo "🗑️  Releasing EIP: $eip"
            aws ec2 release-address --allocation-id "$eip"
        done
        echo "✅ Released unused EIPs"
    else
        echo "ℹ️  Skipped releasing EIPs"
    fi
fi

echo ""
echo "📊 Final EIP status:"
aws ec2 describe-addresses --query 'Addresses[*].[AllocationId,PublicIp,AssociationId]' --output table

echo ""
echo "ℹ️  EIP Limit Information:"
echo "   • Default EIP limit per region: 5"
echo "   • You can request a limit increase via AWS Support"
echo "   • Terraform with 2 AZs will use 2 EIPs (reduced from 3)"
