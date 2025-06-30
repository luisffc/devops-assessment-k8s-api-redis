locals {
  name   = "${var.project_name}-${var.environment}"
  region = var.region

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2) # Reduced from 3 to 2 to avoid EIP limits

  tags = var.tags
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

################################################################################
# EKS
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    main = {
      name = "main"

      instance_types = var.node_group_instance_types

      min_size     = var.node_group_scaling_config.min_size
      max_size     = var.node_group_scaling_config.max_size
      desired_size = var.node_group_scaling_config.desired_size

      ami_type      = "AL2_x86_64"
      capacity_type = "ON_DEMAND"

      # Enable IMDSv2
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }

      create_iam_role          = true
      iam_role_name            = "${local.name}-node-group-role"
      iam_role_use_name_prefix = false
      iam_role_description     = "EKS managed node group IAM role"
      iam_role_tags = {
        Purpose = "Protector of the kubelet"
      }
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Security group
      create_security_group          = true
      security_group_name            = "${local.name}-node-group-sg"
      security_group_use_name_prefix = false
      security_group_description     = "EKS managed node group security group"
      security_group_rules = {
        phoneOut = {
          description = "Hello CloudFlare"
          protocol    = "udp"
          from_port   = 53
          to_port     = 53
          type        = "egress"
          cidr_blocks = ["1.1.1.1/32"]
        }
        phoneHome = {
          description                   = "Hello cluster"
          protocol                      = "udp"
          from_port                     = 53
          to_port                       = 53
          type                          = "egress"
          source_cluster_security_group = true
        }
      }
      security_group_tags = {
        Purpose = "Protector of the kubelet"
      }

      # Launch template
      create_launch_template          = true
      launch_template_name            = "${local.name}-node-group-lt"
      launch_template_use_name_prefix = false
      launch_template_description     = "EKS managed node group launch template"

      ebs_optimized     = true
      enable_monitoring = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      tags = {
        ExtraTag = "EKS managed node group"
      }
    }
  }

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # aws-auth configmap - new syntax for v20+
  enable_cluster_creator_admin_permissions = true

  # Access entries for additional users/roles
  access_entries = merge(
    # Convert map_roles to access entries format
    {
      for idx, role in var.map_roles : "role-${idx}" => {
        principal_arn = role.rolearn
        type          = "STANDARD"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    },
    # Convert map_users to access entries format
    {
      for idx, user in var.map_users : "user-${idx}" => {
        principal_arn = user.userarn
        type          = "STANDARD"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    },
    # GitHub Actions role for CI/CD access
    {
      github_actions = {
        principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name}-github-actions-role"
        type          = "STANDARD"
        policy_associations = {
          admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    }
  )

  tags = local.tags
}

################################################################################
# Data Sources
################################################################################

# Get the OIDC provider created by bootstrap
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

################################################################################
# ECR
################################################################################

resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 latest images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["main", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

################################################################################
# AWS Secrets Manager
################################################################################

# Generate a random password for Redis
resource "random_password" "redis_password" {
  length  = 32
  special = true
}

# Store Redis password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "redis_password" {
  name                    = "${local.name}-redis-secret"
  description             = "Redis password for ${local.name}"
  recovery_window_in_days = 7

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "redis_password" {
  secret_id = aws_secretsmanager_secret.redis_password.id
  secret_string = jsonencode({
    password = random_password.redis_password.result
  })
}

################################################################################
# Additional IAM Role for EKS Deployments
################################################################################

# Service Account for API deployment
resource "kubernetes_namespace" "api" {
  depends_on = [module.eks]

  metadata {
    name = "api-namespace"

    labels = {
      name = "api-namespace"
    }
  }
}

module "irsa_api" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  count = var.enable_irsa ? 1 : 0

  role_name = "${local.name}-api-irsa"

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["api-namespace:api-service-account"]
    }
  }

  # Allow API pods to read secrets from AWS Secrets Manager
  role_policy_arns = {
    SecretsManagerReadOnly = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  }

  tags = local.tags
}

# Custom policy for reading specific Redis secret
resource "aws_iam_policy" "api_secrets_policy" {
  count = var.enable_irsa ? 1 : 0

  name        = "${local.name}-api-secrets-policy"
  description = "Policy for API to read Redis password from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.redis_password.arn
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "api_secrets_policy" {
  count = var.enable_irsa ? 1 : 0

  role       = module.irsa_api[0].iam_role_name
  policy_arn = aws_iam_policy.api_secrets_policy[0].arn
}

################################################################################
# Kubernetes Add-ons
################################################################################

# AWS Load Balancer Controller
module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${local.name}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

resource "helm_release" "aws_load_balancer_controller" {
  depends_on = [module.eks]

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  set {
    name  = "clusterName"
    value = local.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
}

# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  depends_on = [helm_release.aws_load_balancer_controller]

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = "4.8.3"

  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.podSecurityContext.runAsUser"
    value = "101"
  }

  set {
    name  = "controller.podSecurityContext.runAsGroup"
    value = "82"
  }

  set {
    name  = "controller.podSecurityContext.fsGroup"
    value = "82"
  }
}

# Metrics Server
resource "helm_release" "metrics_server" {
  depends_on = [module.eks]

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls}"
  }
}

# AWS Secrets Store CSI Driver
module "secrets_store_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${local.name}-secrets-store-csi-driver"

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:secrets-store-csi-driver"]
    }
  }

  # Policy for the CSI driver to access Secrets Manager
  role_policy_arns = {
    SecretsManagerReadOnly = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  }

  tags = local.tags
}

resource "helm_release" "secrets_store_csi_driver" {
  depends_on = [module.eks]

  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.3.4"

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }
}

resource "helm_release" "aws_secrets_manager_csi" {
  depends_on = [helm_release.secrets_store_csi_driver]

  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.4"
}

################################################################################
# Additional VPC Endpoints (these create ENIs)
################################################################################

# VPC Endpoints for EKS - these create ENIs that need to be tracked
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.region}.s3"

  tags = merge(local.tags, {
    Name = "${local.name}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${local.name}-ecr-api-endpoint"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${local.name}-ecr-dkr-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint.id]

  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${local.name}-ec2-endpoint"
  })
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoint" {
  name_prefix = "${local.name}-vpc-endpoint-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for VPC endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-vpc-endpoint-sg"
  })
}
