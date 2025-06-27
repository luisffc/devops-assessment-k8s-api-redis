# DevOps Assessment - Kubernetes API with Redis Cache

This project demonstrates an initial bootstrap of DevOps solution with a Python Flask API, Redis cache, Kubernetes deployment using Helm, and infrastructure managed with Terraform.

## Components

**Python API** (`/api`): Flask 3.0 with Redis caching, health checks, and security hardening

**Helm Chart** (`/helm/api-redis-stack`): Kubernetes deployment with LoadBalancer service, non-root containers, and Bitnami Redis

**Infrastructure** (`/terraform`): EKS cluster with AL2023 nodes, VPC with Flow Logs, ECR registry, AWS Load Balancer Controller with IRSA

**Bootstrap** (`/terraform-bootstrap`): S3 state storage, GitHub OIDC provider, and IAM roles

**CI/CD** (`/.github/workflows`): Automated build, security scanning, and deployment

## Quick Start

**Prerequisites**: AWS CLI, Terraform, kubectl, Helm

### 1. Bootstrap
```bash
cd terraform-bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

This creates:
- S3 bucket for Terraform state with versioning and encryption
- GitHub OIDC provider for CI/CD authentication  
- IAM role for GitHub Actions with least-privilege permissions

### 2. Configure Main Terraform Backend and Github Secrets and Variables

1. After bootstrap completes, get the backend configuration:

```bash
# Get the backend config from bootstrap output
cd terraform-bootstrap
terraform output backend_config
```

2. Set up the following variables and secrets on Github repository:
  - Secrets
    - `GITHUB_TOKEN`
    - `AWS_ACCOUNT_ID`
    - `TF_STATE_BUCKET`
  - Variables
    - `TF_STATE_KEY`
    - `TF_STATE_REGION`

3. (Optional) If you want to run Terraform locally/bastion-based, copy the backend configuration file and edit it with your values:

```bash
cp terraform/backend.conf.example terraform/backend.conf
```

### 3. Deploy Main Infrastructure

First of all, remove the current `terraform.auto.tfvars` as this is specific to `https://github.com/luisffc/devops-assessment-k8s-api-redis` repository:

```bash
rm terraform/terraform.auto.tfvars
```

Then, configure your Terraform variables:

```bash
cd terraform
cp terraform.tfvars.example terraform.auto.tfvars
# Edit terraform.auto.tfvars with your values
terraform init
terraform fmt
terraform validate
```

Commit this change on a branch of `main`, push and open a PR to trigger the CI/CD pipeline.

Once the workflow completes, review the PR and merge it to the `main` branch. This will apply the Terraform changes and deploy the infrastructure.

### 4. Deploy Application

Perform a simple change to a file on `./api` or `./helm`, commit it on a branch, push and open a PR to trigger the CI/CD pipeline.

Once the workflow completes, review the PR and merge it to the `main` branch. This will build the Docker image, push it to ECR, and deploy the application to EKS.

Wait ~5 minutes for NLB provisioning after deployment

### 5. Access the Application

Go to the GitHub Actions > CI/CD Pipeline > click on the latest workflow run > scroll down to the `Annotation` and find the links to the deployed application.

## API Endpoints

- **Health Check**: `GET /health` - Returns app status and Redis connectivity
- **Store Data**: `POST /store` - Store key-value pairs in Redis
- **Get Keys**: `GET /keys` - Retrieve all Redis keys

## Security Features

- **Container Security**: Non-root user, dropped capabilities, vulnerability scanning
- **Network Security**: Private subnets, restrictive security groups, VPC Flow Logs  
- **Encryption**: EBS, S3, and ECR encryption enabled
- **Access Control**: OIDC for GitHub Actions, IRSA for AWS Load Balancer Controller
- **Infrastructure**: IMDSv2 enforcement, least privilege IAM policies

## Key Features

- **Multi-AZ Deployment**: Resources across availability zones for high availability
- **Auto Scaling**: HPA configuration
- **Zero Downtime**: Rolling updates via Kubernetes deployments
- **Health Checks**: Kubernetes liveness/readiness probes and API health endpoint
- **Basic Monitoring**: Metrics Server for cluster metrics, VPC Flow Logs for network monitoring
- **Disaster Recovery**: Infrastructure as Code with S3 state storage

## Potential Improvements

- **Application Metrics**: Prometheus and Grafana for detailed application monitoring
- **Centralized Logging**: ELK stack or AWS CloudWatch for log aggregation
- **Alerting**: AlertManager or CloudWatch Alarms for proactive monitoring
- **Network Policies**: Kubernetes network policies for enhanced security
- **Pod Disruption Budgets**: Ensure availability during cluster maintenance
- **Redis Authentication**: Enable Redis authentication for production use
- **Redis Persistence**: Enable Redis persistence for production use cases

## Cleanup

1. On AWS Console, navigate to the repository on ECR and remove all the images

2. On GitHub Actions, run the Terraform workflow to destroy the infrastructure

3. On your local machine or bastion host, run the following commands to clean up the base resources:

```bash
cd terraform-bootstrap && terraform destroy
```
