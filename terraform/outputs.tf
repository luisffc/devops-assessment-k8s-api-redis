output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_primary_security_group_id
}

output "node_groups" {
  description = "EKS node groups"
  value       = module.eks.eks_managed_node_groups
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = module.eks.oidc_provider_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.api.repository_url
}

output "vpc_id" {
  description = "ID of the VPC where the EKS cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions (from bootstrap)"
  value       = replace(data.aws_iam_openid_connect_provider.github_actions.arn, ":oidc-provider/token.actions.githubusercontent.com", ":role/${var.project_name}-${var.environment}-github-actions-role")
}

output "api_irsa_role_arn" {
  description = "ARN of the IAM role for API service account"
  value       = var.enable_irsa ? module.irsa_api[0].iam_role_arn : null
}

# ENI tracking outputs
output "all_vpc_enis" {
  description = "All ENIs in the VPC"
  value       = data.aws_network_interfaces.all_vpc_enis.ids
}

output "eks_enis" {
  description = "ENIs created by EKS cluster"
  value       = data.aws_network_interfaces.eks_enis.ids
}

output "nat_gateway_enis" {
  description = "ENIs created by NAT Gateways"
  value       = data.aws_network_interfaces.nat_gateway_enis.ids
}

output "kubernetes_lb_enis" {
  description = "ENIs created by Kubernetes Load Balancers"
  value       = data.aws_network_interfaces.kubernetes_lb_enis.ids
}

output "vpc_endpoint_enis" {
  description = "ENI IDs for VPC endpoints"
  value = {
    ecr_api = aws_vpc_endpoint.ecr_api.network_interface_ids
    ecr_dkr = aws_vpc_endpoint.ecr_dkr.network_interface_ids
    ec2     = aws_vpc_endpoint.ec2.network_interface_ids
  }
}
