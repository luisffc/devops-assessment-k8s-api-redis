################################################################################
# Data Sources for Existing Infrastructure
################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

################################################################################
# ENI Data Sources for Tracking and Lifecycle Management
################################################################################

# Track all ENIs in the VPC to prevent orphaned resources
data "aws_network_interfaces" "all_vpc_enis" {
  depends_on = [
    module.eks,
    helm_release.nginx_ingress,
    helm_release.aws_load_balancer_controller
  ]

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }
}

# Track ENIs by specific services for better management
data "aws_network_interfaces" "eks_enis" {
  depends_on = [module.eks]

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  filter {
    name   = "description"
    values = [
      "Amazon EKS ${local.name}*",
      "EKS ${local.name}*"
    ]
  }
}

data "aws_network_interfaces" "nat_gateway_enis" {
  depends_on = [module.vpc]

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  filter {
    name   = "description"
    values = ["Interface for NAT Gateway*"]
  }
}

# Track Load Balancer ENIs (created by Kubernetes services)
data "aws_network_interfaces" "kubernetes_lb_enis" {
  depends_on = [
    helm_release.nginx_ingress,
    helm_release.aws_load_balancer_controller
  ]

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  filter {
    name   = "description"
    values = [
      "ELB*",
      "*LoadBalancer*"
    ]
  }
}

################################################################################
# EKS Cluster Information
################################################################################

data "aws_eks_cluster" "cluster" {
  depends_on = [module.eks]
  name       = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  depends_on = [module.eks]
  name       = module.eks.cluster_name
}
