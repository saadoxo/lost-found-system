provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Secondary provider for DR region (us-west-2)
provider "aws" {
  alias  = "dr"
  region = "us-west-2"

  default_tags {
    tags = merge(local.common_tags, { Region = "dr" })
  }
}
