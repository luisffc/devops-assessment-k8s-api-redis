region       = "us-east-1"
project_name = "devops-assessment"
environment  = "dev"

# EKS Configuration
cluster_version                 = "1.31"
cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

# Node Group Configuration
node_group_instance_types = ["t3.medium"]
node_group_scaling_config = {
  desired_size = 1
  max_size     = 2
  min_size     = 1
}

# GitHub Configuration
github_org  = "luisffc"
github_repo = "devops-assessment-k8s-api-redis"

# IAM Configuration
enable_irsa = true

# Additional IAM roles to map to Kubernetes RBAC
# map_roles = [
#   {
#     rolearn  = "arn:aws:iam::123456789012:role/DevOpsRole"
#     username = "devops-role"
#     groups   = ["system:masters"]
#   }
# ]

# Additional IAM users to map to Kubernetes RBAC
map_users = [
  {
    userarn  = "arn:aws:iam::593793047834:user/luis"
    username = "luis"
    groups   = ["system:masters"]
  }
]

# Tags
tags = {
  Terraform   = "true"
  Project     = "devops-assessment"
  Environment = "dev"
  Owner       = "devops-team"
  Purpose     = "assessment"
}
