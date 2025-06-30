# ENI Management and Tracking

This document explains the Enhanced Network Interface (ENI) tracking and management system added to prevent issues during Terraform destroy operations.

## The Problem

AWS services like EKS, Load Balancers, and VPC Endpoints create ENIs (Elastic Network Interfaces) that are often not directly tracked by Terraform. During `terraform destroy`, these ENIs can prevent VPC deletion, causing the operation to fail with errors like:

```
Error: DependencyViolation: The vpc 'vpc-xxxxx' has dependencies and cannot be deleted
```

## ENI Sources in This Infrastructure

The following components create ENIs that may not be tracked in Terraform state:

### 1. EKS Cluster Components
- **EKS Control Plane**: Creates ENIs in private subnets for API server endpoints
- **EKS Node Groups**: EC2 instances have primary ENIs plus additional ones for pods
- **EKS Add-ons**: Components like CoreDNS, kube-proxy create network interfaces

### 2. Kubernetes Load Balancers
- **NGINX Ingress Controller**: Creates AWS Network Load Balancer with ENIs
- **AWS Load Balancer Controller**: Manages ALB/NLB with associated ENIs
- **Service type LoadBalancer**: Any Kubernetes service of type LoadBalancer creates AWS LB with ENIs

### 3. VPC Endpoints
- **ECR API Endpoint**: Interface endpoint for ECR API calls
- **ECR DKR Endpoint**: Interface endpoint for Docker registry access
- **EC2 Endpoint**: Interface endpoint for EC2 API calls
- **S3 Gateway Endpoint**: Gateway endpoint (no ENI, but listed for completeness)

### 4. Other Sources
- **NAT Gateways**: Have ENIs but are tracked by the VPC module
- **Lambda functions in VPC**: Would create ENIs (not used in this project)
- **RDS instances in VPC**: Would create ENIs (not used in this project)

## Solutions Implemented

### 1. Data Sources for ENI Tracking (`data.tf`)

```hcl
# Track all ENIs in the VPC
data "aws_network_interfaces" "all_vpc_enis" {
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }
}

# Track specific ENI types
data "aws_network_interfaces" "eks_enis" { ... }
data "aws_network_interfaces" "kubernetes_lb_enis" { ... }
data "aws_network_interfaces" "nat_gateway_enis" { ... }
```

### 2. Explicit VPC Endpoints (`main.tf`)

Instead of relying on implicit ENI creation, we explicitly create VPC endpoints:

```hcl
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
}
```

### 3. ENI Import Helper (`eni_lifecycle.tf`)

Generates a script to help import orphaned ENIs:

```bash
./eni_import_commands.sh
```

This script:
- Lists all ENIs in the VPC
- Provides import commands for different ENI types
- Shows manual cleanup commands if needed

### 4. Outputs for Monitoring (`outputs.tf`)

Track ENI IDs in Terraform outputs:

```hcl
output "all_vpc_enis" {
  description = "All ENIs in the VPC"
  value       = data.aws_network_interfaces.all_vpc_enis.ids
}
```

## How to Handle ENI Issues

### Before Destroy

1. **Check ENI Status**:
   ```bash
   # Run the generated helper script
   ./terraform/eni_import_commands.sh
   
   # Or manually check
   aws ec2 describe-network-interfaces \
     --filters "Name=vpc-id,Values=<VPC_ID>" \
     --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Description:Description,Status:Status}' \
     --output table
   ```

2. **Delete Kubernetes Resources First**:
   ```bash
   # Delete ingress controllers and load balancers
   kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer
   helm uninstall ingress-nginx -n ingress-nginx
   helm uninstall aws-load-balancer-controller -n kube-system
   ```

### During Destroy Issues

If `terraform destroy` fails due to ENI dependencies:

1. **Identify Orphaned ENIs**:
   ```bash
   aws ec2 describe-network-interfaces \
     --filters "Name=vpc-id,Values=<VPC_ID>" "Name=status,Values=available" \
     --query 'NetworkInterfaces[].NetworkInterfaceId' \
     --output text
   ```

2. **Manual ENI Cleanup**:
   ```bash
   # Delete available ENIs
   aws ec2 describe-network-interfaces \
     --filters "Name=vpc-id,Values=<VPC_ID>" "Name=status,Values=available" \
     --query 'NetworkInterfaces[].NetworkInterfaceId' \
     --output text | \
   xargs -I {} aws ec2 delete-network-interface --network-interface-id {}
   ```

3. **Force Cleanup** (Use with caution):
   ```bash
   terraform apply -var="force_destroy_enis=true"
   terraform destroy -var="force_destroy_enis=true"
   ```

### After Issues Are Resolved

1. **Import Missing ENIs** (if keeping infrastructure):
   ```bash
   # Use the generated import commands
   terraform import 'aws_network_interface.eks_eni_example' eni-xxxxxxxxx
   ```

2. **Update Terraform State**:
   ```bash
   terraform refresh
   terraform plan  # Should show no changes if everything is tracked
   ```

## Prevention Best Practices

1. **Always use Terraform-managed resources** when possible
2. **Track ENIs via data sources** for monitoring
3. **Delete Kubernetes resources** before Terraform destroy
4. **Use explicit VPC endpoints** instead of implicit ones
5. **Monitor ENI outputs** in Terraform state
6. **Test destroy in staging** before production

## Files Added

- `terraform/data.tf` - Data sources for ENI tracking
- `terraform/eni_lifecycle.tf` - Lifecycle management resources
- `terraform/eni_import_template.tpl` - Template for import helper script
- `terraform/ENI_MANAGEMENT.md` - This documentation

## Troubleshooting

### Common Error Messages

1. **"DependencyViolation: The vpc has dependencies"**
   - Solution: Identify and delete orphaned ENIs

2. **"InvalidNetworkInterfaceID.NotFound"**
   - Solution: ENI was already deleted, update Terraform state

3. **"Network interface is currently in use"**
   - Solution: Stop associated services (EKS nodes, Load Balancers) first

### Emergency Cleanup Script

```bash
#!/bin/bash
VPC_ID="vpc-xxxxxxxxx"

echo "=== Emergency ENI Cleanup ==="

# 1. List all ENIs
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID"

# 2. Delete Load Balancers first
aws elbv2 describe-load-balancers --query 'LoadBalancers[?VpcId==`'$VPC_ID'`].LoadBalancerArn' --output text | \
  xargs -I {} aws elbv2 delete-load-balancer --load-balancer-arn {}

# 3. Wait and delete available ENIs
sleep 60
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" \
  --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | \
  xargs -I {} aws ec2 delete-network-interface --network-interface-id {}

echo "=== Cleanup Complete ==="
```

Use this script only as a last resort when normal Terraform destroy fails.
