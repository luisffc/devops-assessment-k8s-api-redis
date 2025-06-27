output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role for main infrastructure"
  value       = aws_iam_role.github_actions_main.arn
}

output "backend_config" {
  description = "Backend configuration for main Terraform"
  value = {
    bucket  = aws_s3_bucket.terraform_state.bucket
    key     = "main/terraform.tfstate"
    region  = var.region
    encrypt = true
  }
}
