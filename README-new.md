# DevOps Assessment - Kubernetes API with Redis C### 4. Bootstrap (`/terraform-bootstrap`)
- **S3 Backend**: For Terraform state storage with native locking (no DynamoDB needed)
- **OIDC Provider**: For GitHub Actions authentication
- **IAM Roles**: For CI/CD operations

### 5. CI/CD (`/.github/workflows`)This project demonstrates a complete DevOps solution with a Python Flask API, Redis cache, Kubernetes deployment using Helm, and infrastructure managed with Terraform.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub        │    │   AWS ECR       │    │   EKS Cluster   │
│   Repository    │────│   Container     │────│   - API Pods    │
│   - CI/CD       │    │   Registry      │    │   - Redis       │
│   - Code        │    │                 │    │   - Ingress     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                                             │
         │              ┌─────────────────┐           │
         └──────────────│   Terraform     │───────────┘
                        │   Infrastructure│
                        │   - VPC         │
                        │   - EKS         │
                        │   - ECR         │
                        │   - IAM         │
                        └─────────────────┘
```

## Components

### 1. Python API (`/api`)
- **Framework**: Flask 3.0 with Redis caching
- **Endpoints**:
  - `GET /health` - Health check
  - `POST /store` - Store key-value pairs in Redis
  - `GET /keys` - Get all Redis keys
- **Security**: Reads Redis password from AWS Secrets Manager
- **Docker**: Multi-stage build with security hardening

### 2. Helm Chart (`/helm/api-redis-stack`)
- **API Deployment**: With HPA, health checks, and resource limits
- **Redis**: Using official Bitnami chart with authentication enabled
- **Secrets Management**: AWS Secrets Manager integration via CSI driver
- **IRSA**: IAM Roles for Service Accounts for secure AWS access
- **Kubernetes Resources**: Services, Ingress, NetworkPolicies, PDB

### 3. Infrastructure (`/terraform`)
- **EKS Cluster**: With managed node groups and AWS Secrets Store CSI driver
- **VPC**: Multi-AZ with public/private subnets
- **ECR**: Container registry for API images
- **Secrets Manager**: Secure Redis password storage
- **IAM**: Roles for GitHub Actions OIDC and IRSA for pod access

### 4. Bootstrap (`/terraform-bootstrap`)
- **S3 Backend**: For Terraform state storage with native locking
- **OIDC Provider**: For GitHub Actions authentication
- **IAM Roles**: For CI/CD operations

### 5. CI/CD Pipeline (`/.github/workflows`)
- **Bootstrap**: Infrastructure bootstrapping
- **Terraform**: Main infrastructure deployment
- **CI/CD**: Build, test, and deploy application

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- kubectl and Helm installed
- GitHub repository with secrets configured

### 1. Bootstrap Infrastructure

First, run the bootstrap to create the S3 backend and OIDC provider:

```bash
# Set up GitHub secrets:
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - AWS_ACCOUNT_ID

# Run bootstrap workflow manually in GitHub Actions
# This creates: S3 bucket, DynamoDB table, OIDC provider, IAM roles
```

### 2. Configure Main Terraform Backend

After bootstrap completes, update `terraform/versions.tf` with the S3 backend configuration from the bootstrap output.

### 3. Deploy Main Infrastructure

```bash
# Configure terraform/terraform.tfvars with your values
# Run the Terraform workflow in GitHub Actions
# This creates: VPC, EKS cluster, ECR repository
```

### 4. Deploy Application

Push to main branch to trigger the CI/CD pipeline:
- Builds and pushes Docker image to ECR
- Deploys application using Helm to EKS

## API Endpoints

### Health Check
```bash
curl https://your-api-domain/health
```

### Get Users (with Redis caching)
```bash
curl https://your-api-domain/api/users
```

## Configuration

### Required GitHub Secrets
- `AWS_ACCESS_KEY_ID` - For bootstrap workflow
- `AWS_SECRET_ACCESS_KEY` - For bootstrap workflow
- `AWS_ACCOUNT_ID` - Your AWS account ID

### Terraform Variables

**Bootstrap** (`terraform-bootstrap/terraform.tfvars`):
```hcl
region       = "us-east-1"
project_name = "devops-assessment"
environment  = "dev"
github_org   = "your-github-org"
github_repo  = "devops-assessment-k8s-api-redis"
```

**Main** (`terraform/terraform.tfvars`):
```hcl
region       = "us-east-1"
project_name = "devops-assessment"
environment  = "dev"
github_org   = "your-github-org"
github_repo  = "devops-assessment-k8s-api-redis"
```

## Security Features

- **Container Security**: Non-root user, security contexts, resource limits
- **Network Security**: Network policies, private subnets, security groups
- **Secrets Management**: AWS Secrets Manager for Redis authentication
- **Identity**: OIDC for GitHub Actions, IRSA for service accounts
- **Least Privilege IAM**: Specific permissions instead of wildcards, resource-based conditions
- **Encryption**: EBS encryption, S3 encryption, secrets encryption at rest
- **Scanning**: Trivy vulnerability scanning in CI/CD

## API Testing

Once deployed, you can test the API endpoints:

### Store a key-value pair
```bash
curl -X POST https://api.example.com/store \
  -H "Content-Type: application/json" \
  -d '{"key": "mykey", "value": "myvalue"}'
```

### Get all keys
```bash
curl https://api.example.com/keys
```

### Health check
```bash
curl https://api.example.com/health
```

## Deployment

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.6
- kubectl
- Helm >= 3.13

### Step 1: Bootstrap Infrastructure (Local/Bastion)

The bootstrap creates foundational infrastructure and should be run locally or from a bastion host:

```bash
cd terraform-bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

This creates:
- S3 bucket for Terraform state (with native locking)
- GitHub OIDC provider for CI/CD authentication
- IAM role for GitHub Actions with least-privilege permissions

### Step 2: Configure Main Terraform Backend

After bootstrap completes, update the backend configuration in `terraform/versions.tf`:

```bash
# Get the backend config from bootstrap output
cd terraform-bootstrap
terraform output backend_config
```

Copy the output values to `terraform/versions.tf` backend block.

### Step 3: Main Infrastructure & Application

The main infrastructure and application deployment happens via GitHub Actions:

1. Push changes to trigger CI/CD
2. Infrastructure deploys via Terraform workflow
3. Application builds and deploys automatically

## Deployment Order

1. **Bootstrap** (Manual): Creates foundational infrastructure
2. **Terraform** (Manual): Creates main infrastructure
3. **Application** (Automatic): Deploys on code changes

## Monitoring

- Health checks on all components
- Kubernetes resource monitoring
- Application and Redis metrics
- Container vulnerability scanning

## Cleanup

To destroy all resources:

1. Run CI/CD workflow with destroy option for application
2. Run Terraform workflow with destroy option for main infrastructure
3. Run Bootstrap workflow with destroy option for foundational infrastructure

---

This project demonstrates enterprise-grade DevOps practices including infrastructure as code, container security, automated CI/CD, and cloud-native architecture patterns.

## Recent Improvements

### v2.0 - Enhanced Security & Modern AWS Features
- **AWS Secrets Manager Integration**: Redis password stored securely in AWS Secrets Manager and injected into pods via CSI driver
- **S3 Native Locking**: Removed DynamoDB dependency - using AWS S3's native state locking feature (introduced late 2023)
- **IRSA Integration**: IAM Roles for Service Accounts for secure pod-level AWS permissions
- **Least Privilege IAM**: Replaced wildcard permissions with specific, scoped permissions
- **Local Bootstrap**: Removed GitHub Actions bootstrap workflow - run bootstrap locally/from bastion
- **API Compliance**: Updated endpoints to match assessment requirements exactly

### v1.0 - Initial Implementation
- Basic Flask API with Redis caching
- EKS cluster with Helm deployment
- GitHub Actions CI/CD pipeline
- Terraform infrastructure automation

## Configuration
