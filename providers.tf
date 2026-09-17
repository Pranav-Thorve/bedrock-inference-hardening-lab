provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = var.project
      LabState  = "broken"
      ManagedBy = "terraform"
    }
  }
}
