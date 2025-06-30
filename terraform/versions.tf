terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Backend configuration - update after bootstrap
  backend "s3" {
    # These values should be updated after running terraform-bootstrap
    # bucket  = "devops-assessment-dev-terraform-state-xxxxxxxx"
    # key     = "main/terraform.tfstate"
    # region  = "us-east-1"
    # encrypt = true
    bucket  = "devops-assessment-dev-terraform-state-30d11g29"
    encrypt = true
    key     = "main/terraform.tfstate"
    region  = "us-east-1"
  }
}
