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

output "redis_secret_arn" {
  description = "ARN of the Redis password secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.redis_password.arn
}

output "redis_secret_name" {
  description = "Name of the Redis password secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.redis_password.name
}

output "api_irsa_role_arn" {
  description = "ARN of the IAM role for API service account"
  value       = var.enable_irsa ? module.irsa_api[0].iam_role_arn : null
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = try("aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_id}", "EKS cluster not yet created")
}
