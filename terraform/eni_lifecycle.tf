################################################################################
# Lifecycle Management for ENI Resources
################################################################################

# This file contains resources and configuration to help manage ENI lifecycle
# and prevent issues during terraform destroy operations

################################################################################
# ENI Import Helper
################################################################################

# Create a local file with import commands for any orphaned ENIs
resource "local_file" "eni_import_helper" {
  depends_on = [data.aws_network_interfaces.all_vpc_enis]

  filename = "${path.module}/eni_import_commands.sh"
  content = templatefile("${path.module}/eni_import_template.tpl", {
    vpc_id = module.vpc.vpc_id
  })

  file_permission = "0755"
}

################################################################################
# Variables for ENI Management
################################################################################

variable "force_destroy_enis" {
  description = "Whether to force destroy ENIs during terraform destroy (use with caution)"
  type        = bool
  default     = false
}
