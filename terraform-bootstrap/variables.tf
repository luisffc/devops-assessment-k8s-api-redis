variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "devops-assessment"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "your-github-org"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "devops-assessment-k8s-api-redis"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Project     = "devops-assessment"
    Environment = "dev"
    Purpose     = "bootstrap"
  }
}

variable "bucket_suffix" {
  description = "Optional suffix for the S3 bucket name. If empty, a random suffix will be generated."
  type        = string
  default     = ""
}
